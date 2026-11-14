import Foundation
import Testing
@testable import PetaCore

// Every ID, address and event below is made up.
private let clientID = "123456-fictional.apps.googleusercontent.com"

private let tokyo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
    return calendar
}()

private func json(_ text: String) -> Data { Data(text.utf8) }

@Suite struct GoogleOAuthTests {
    @Test func acceptsOnlyGoogleIOSClientIDs() {
        #expect(GoogleOAuthConfig(clientID: " \(clientID)\n")?.clientID == clientID)
        #expect(GoogleOAuthConfig(clientID: "") == nil)
        #expect(GoogleOAuthConfig(clientID: ".apps.googleusercontent.com") == nil)
        #expect(GoogleOAuthConfig(clientID: "abc.example.com") == nil)
        #expect(GoogleOAuthConfig(clientID: "a b.apps.googleusercontent.com") == nil)
    }

    @Test func reversesTheClientIDForTheRedirect() throws {
        let config = try #require(GoogleOAuthConfig(clientID: clientID))
        #expect(config.redirectScheme == "com.googleusercontent.apps.123456-fictional")
        #expect(config.redirectURI == "com.googleusercontent.apps.123456-fictional:/oauth2redirect")
    }

    @Test func buildsTheAuthorizationURL() throws {
        let config = try #require(GoogleOAuthConfig(clientID: clientID))
        let url = config.authorizationURL(state: "s1", codeChallenge: "c1", loginHint: "mame.sorano@example.com")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(url.host == "accounts.google.com")
        #expect(value("client_id") == clientID)
        #expect(value("response_type") == "code")
        #expect(value("code_challenge") == "c1")
        #expect(value("code_challenge_method") == "S256")
        #expect(value("state") == "s1")
        #expect(value("login_hint") == "mame.sorano@example.com")
        #expect(value("scope")?.split(separator: " ").count == 2)
        #expect(value("client_secret") == nil)
    }

    @Test func formEncodingEscapesReservedCharacters() {
        let body = String(decoding: GoogleForm.encode([("a", "x y&z/="), ("b", "-._~")]), as: UTF8.self)
        #expect(body == "a=x%20y%26z%2F%3D&b=-._~")
    }

    @Test func pkceMatchesTheRFCExample() {
        // RFC 7636 appendix B: SHA-256 of "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk".
        let digest: [UInt8] = [19, 211, 30, 150, 26, 26, 216, 236, 47, 22, 177, 12, 76, 152, 46, 8,
                               118, 168, 120, 173, 109, 241, 68, 86, 110, 225, 137, 74, 203, 112, 249, 195]
        #expect(PKCE.base64URL(Data(digest)) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(PKCE.isValidVerifier("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"))
        #expect(!PKCE.isValidVerifier("short"))
        #expect(!PKCE.isValidVerifier(String(repeating: "a", count: 42) + "+"))
    }

    @Test func readsTheCallback() throws {
        let config = try #require(GoogleOAuthConfig(clientID: clientID))
        let base = "com.googleusercontent.apps.123456-fictional:/oauth2redirect"
        #expect(GoogleCallback(url: URL(string: "\(base)?state=s1&code=abc")!, config: config, expectedState: "s1") == .code("abc"))
        #expect(GoogleCallback(url: URL(string: "\(base)?state=s1&error=access_denied")!, config: config, expectedState: "s1") == .denied)
        #expect(GoogleCallback(url: URL(string: "\(base)?state=s1&error=server_error")!, config: config, expectedState: "s1") == .failed("server_error"))
        #expect(GoogleCallback(url: URL(string: "\(base)?state=other&code=abc")!, config: config, expectedState: "s1") == nil)
        #expect(GoogleCallback(url: URL(string: "https://example.com/?state=s1&code=abc")!, config: config, expectedState: "s1") == nil)
    }

    @Test func readsTokenReplies() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let ok = GoogleTokenReply(data: json(#"{"access_token":"at","expires_in":3599,"refresh_token":"rt","scope":"https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.calendarlist.readonly","token_type":"Bearer"}"#), receivedAt: now)
        guard case .tokens(let tokens) = ok else { Issue.record("no tokens"); return }
        #expect(tokens.accessToken == "at")
        #expect(tokens.refreshToken == "rt")
        #expect(tokens.expiresAt == now.addingTimeInterval(3599))
        #expect(tokens.grantsAllScopes)
        #expect(tokens.isFresh(at: now))
        #expect(!tokens.isFresh(at: now.addingTimeInterval(3550)))

        #expect(GoogleTokenReply(data: json(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#), receivedAt: now) == .signInAgain)
        #expect(GoogleTokenReply(data: json(#"{"error":"invalid_client"}"#), receivedAt: now) == .failed("invalid_client"))
        #expect(GoogleTokenReply(data: json("<html>"), receivedAt: now) == .failed("unreadable"))
    }

    @Test func keepsTheRefreshTokenAcrossRefreshes() {
        let old = GoogleTokens(accessToken: "a1", expiresAt: .distantPast, refreshToken: "rt", scope: "x")
        let new = GoogleTokens(accessToken: "a2", expiresAt: .distantFuture, refreshToken: nil, scope: nil)
        let merged = old.merged(with: new)
        #expect(merged.accessToken == "a2")
        #expect(merged.refreshToken == "rt")
        #expect(merged.scope == "x")
    }

    @Test func noticesAnUntickedScope() {
        let tokens = GoogleTokens(accessToken: "a", expiresAt: .distantFuture, refreshToken: nil,
                                  scope: "https://www.googleapis.com/auth/calendar.events")
        #expect(!tokens.grantsAllScopes)
    }
}

@Suite struct GoogleCalendarListTests {
    @Test func readsCalendarsAndTheAccountEmail() throws {
        let page = try GoogleCalendarListPage(data: json("""
        {"items":[
          {"id":"mame.sorano@example.com","summary":"mame.sorano@example.com","summaryOverride":"ライブとイベント","backgroundColor":"#9fe1e7","accessRole":"owner","primary":true},
          {"id":"family-fictional@group.calendar.google.com","summary":"家族の予定","backgroundColor":"#f691b2","accessRole":"writer"},
          {"id":"ja.japanese#holiday@group.v.calendar.google.com","summary":"日本の祝日","backgroundColor":"#16a765","accessRole":"reader"},
          {"id":"gone@example.com","summary":"消えた","deleted":true}
        ],"nextPageToken":"p2"}
        """))
        #expect(page.entries.map(\.title) == ["ライブとイベント", "家族の予定", "日本の祝日"])
        #expect(page.entries.map(\.writable) == [true, true, false])
        #expect(page.entries[0].color == RGB(hex: "#9fe1e7"))
        #expect(page.nextPageToken == "p2")
        #expect(GoogleCalendarListPage.accountEmail(of: page.entries) == "mame.sorano@example.com")
    }

    @Test func readsTheEventPalette() throws {
        let palette = try GoogleColors.eventPalette(from: json(##"{"kind":"calendar#colors","calendar":{"1":{"background":"#ac725e","foreground":"#1d1d1d"}},"event":{"1":{"background":"#a4bdfc","foreground":"#1d1d1d"},"11":{"background":"#dc2127","foreground":"#1d1d1d"}}}"##))
        #expect(palette.count == 2)
        #expect(palette["11"] == RGB(red: 220.0 / 255, green: 33.0 / 255, blue: 39.0 / 255))
    }

    @Test func hexColors() {
        #expect(RGB(hex: "#000000") == RGB(red: 0, green: 0, blue: 0))
        #expect(RGB(hex: "ffffff") == RGB(red: 1, green: 1, blue: 1))
        #expect(RGB(hex: "#fff") == nil)
        #expect(RGB(hex: "#zzzzzz") == nil)
    }
}

@Suite struct GoogleEventTests {
    @Test func readsTimedAllDayAndCancelledEvents() throws {
        let page = try GoogleEventPage(data: json("""
        {"items":[
          {"id":"e1","status":"confirmed","summary":"ほしぞら座 公演","location":"架空ホール","colorId":"11",
           "start":{"dateTime":"2026-11-14T19:00:00+09:00"},"end":{"dateTime":"2026-11-14T21:30:00+09:00"}},
          {"id":"e2","summary":"合宿","start":{"date":"2026-11-20"},"end":{"date":"2026-11-23"}},
          {"id":"e3","status":"cancelled"},
          {"id":"e4","summary":"  ","start":{"dateTime":"2026-11-15T10:00:00.000Z"},"end":{"dateTime":"2026-11-15T11:00:00.000Z"},
           "recurringEventId":"r1"}
        ],"nextPageToken":"n"}
        """), calendarID: "c", calendar: tokyo)
        #expect(page.events.map(\.id) == ["e1", "e2", "e4"])
        #expect(page.nextPageToken == "n")

        let timed = page.events[0]
        #expect(!timed.isAllDay)
        #expect(timed.start == GoogleTime.instant("2026-11-14T10:00:00Z"))
        #expect(timed.end.timeIntervalSince(timed.start) == 2.5 * 3600)
        #expect(timed.location == "架空ホール")
        #expect(timed.colorID == "11")
        #expect(timed.calendarID == "c")

        let allDay = page.events[1]
        #expect(allDay.isAllDay)
        #expect(allDay.start == GoogleTime.day("2026-11-20", calendar: tokyo))
        #expect(allDay.end == GoogleTime.day("2026-11-23", calendar: tokyo))   // 3 days; the end is exclusive

        #expect(page.events[2].title == "")
        #expect(page.events[2].recurringEventID == "r1")
    }

    @Test func rejectsImpossibleDays() {
        #expect(GoogleTime.day("2026-02-30", calendar: tokyo) == nil)
        #expect(GoogleTime.day("2026-11", calendar: tokyo) == nil)
        #expect(GoogleTime.instant("not a date") == nil)
    }

    @Test func writesTimedEvents() throws {
        let start = try #require(GoogleTime.instant("2026-11-14T19:00:00+09:00"))
        let draft = GoogleEventDraft(title: "打ち合わせ", start: start, end: start.addingTimeInterval(3600), isAllDay: false,
                                     location: "架空スタジオ")
        let body = try #require(try JSONSerialization.jsonObject(with: draft.json(calendar: tokyo)) as? [String: Any])
        #expect(body["summary"] as? String == "打ち合わせ")
        #expect(body["location"] as? String == "架空スタジオ")
        #expect(body["description"] as? String == "")
        #expect((body["start"] as? [String: String])?["dateTime"] == "2026-11-14T10:00:00Z")
        #expect((body["end"] as? [String: String])?["dateTime"] == "2026-11-14T11:00:00Z")
    }

    @Test func writesAllDayEventsWithAnExclusiveEnd() throws {
        let day = try #require(GoogleTime.day("2026-11-20", calendar: tokyo))
        // Same start and end (one day): the end must still be the next day.
        let one = GoogleEventDraft(title: "休み", start: day, end: day, isAllDay: true)
        let oneBody = try #require(try JSONSerialization.jsonObject(with: one.json(calendar: tokyo)) as? [String: Any])
        #expect((oneBody["start"] as? [String: String])?["date"] == "2026-11-20")
        #expect((oneBody["end"] as? [String: String])?["date"] == "2026-11-21")

        let three = GoogleEventDraft(title: "合宿", start: day, end: day.addingTimeInterval(3 * 86400), isAllDay: true)
        let threeBody = try #require(try JSONSerialization.jsonObject(with: three.json(calendar: tokyo)) as? [String: Any])
        #expect((threeBody["end"] as? [String: String])?["date"] == "2026-11-23")
    }

    @Test func readsASingleEventReply() throws {
        let event = try GoogleEventPage.single(data: json(#"{"id":"new1","summary":"追加した予定","start":{"date":"2026-12-01"},"end":{"date":"2026-12-02"}}"#),
                                               calendarID: "c", calendar: tokyo)
        #expect(event?.id == "new1")
        #expect(event?.isAllDay == true)
    }
}

@Suite struct GoogleMergeTests {
    @Test func hidesDeviceCalendarsOfConnectedAccounts() {
        let hidden = GoogleMerge.duplicateDeviceCalendars(
            [(id: "k1", account: "Mame.Sorano@example.com"), (id: "k2", account: "iCloud"), (id: "k3", account: "mame.sorano@example.com ")],
            googleEmails: ["mame.sorano@example.com"])
        #expect(hidden == ["k1", "k3"])
        #expect(GoogleMerge.duplicateDeviceCalendars([(id: "k1", account: "a@example.com")], googleEmails: []).isEmpty)
    }

    @Test func picksTheEventColor() {
        let event = GoogleEvent(id: "e", calendarID: "c", title: "t", start: .distantPast, end: .distantPast, isAllDay: false,
                                location: nil, notes: nil, colorID: "11", recurringEventID: nil)
        let red = RGB(hex: "#dc2127")!
        let blue = RGB(hex: "#4285f4")!
        #expect(GoogleMerge.color(of: event, calendarColor: blue, palette: ["11": red], useEventColors: true) == red)
        #expect(GoogleMerge.color(of: event, calendarColor: blue, palette: ["11": red], useEventColors: false) == blue)
        #expect(GoogleMerge.color(of: event, calendarColor: blue, palette: [:], useEventColors: true) == blue)
    }

    @Test func sortsHTTPStatuses() {
        #expect(GoogleAPIError(status: 200) == nil)
        #expect(GoogleAPIError(status: 204) == nil)
        #expect(GoogleAPIError(status: 401) == .signInAgain)
        #expect(GoogleAPIError(status: 410) == .notFound)
        #expect(GoogleAPIError(status: 503) == .server)
        #expect(GoogleAPIError(status: 418) == .other(418))
    }

    @Test func packsAndUnpacksReferences() throws {
        let event = GoogleRef(email: "mame.sorano@example.com", calendarID: "ja.japanese#holiday@group.v.calendar.google.com", eventID: "e1_20261114")
        #expect(GoogleRef(key: event.key) == event)
        #expect(GoogleRef(key: event.calendarKey) == event.calendar)
        #expect(event.calendar.eventID == nil)
        #expect(GoogleRef.isGoogle(event.key))
        #expect(GoogleRef(key: "google:|c") == nil)
        #expect(GoogleRef(key: "google:a@example.com") == nil)
        #expect(GoogleRef(key: "ABCD-1234") == nil)
        #expect(GooglePath.escape("ja.japanese#holiday@group.v.calendar.google.com") == "ja.japanese%23holiday%40group.v.calendar.google.com")
    }
}
