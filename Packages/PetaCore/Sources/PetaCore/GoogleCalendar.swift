import Foundation

// The parts of the Google sign-in and the Google Calendar API that do not need the network or Apple-only frameworks.
// Sources: https://developers.google.com/identity/protocols/oauth2/native-app
//          https://developers.google.com/calendar/api/v3/reference

// MARK: - Sign-in (OAuth 2.0 with PKCE, no client secret)

public struct GoogleOAuthConfig: Sendable, Equatable {
    public static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    public static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    public static let revokeEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!
    /// Read and write events, and read the list of calendars (names and colors).
    public static let scopes = [
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
    ]

    /// The iOS client ID from Google Cloud, like `1234-abcd.apps.googleusercontent.com`.
    public let clientID: String

    /// nil when the ID is empty or not shaped like a Google iOS client ID.
    public init?(clientID raw: String) {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = ".apps.googleusercontent.com"
        guard id.hasSuffix(suffix), id.count > suffix.count,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." || $0 == "_" }) else { return nil }
        clientID = id
    }

    /// The client ID turned around: `com.googleusercontent.apps.1234-abcd`. Google uses it as the URL scheme.
    public var redirectScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    public var redirectURI: String { "\(redirectScheme):/oauth2redirect" }

    public func authorizationURL(state: String, codeChallenge: String, loginHint: String? = nil) -> URL {
        var parts = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            // Always show the account chooser, so a second account can be added.
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        if let loginHint, !loginHint.isEmpty { items.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        parts.queryItems = items
        return parts.url!
    }

    /// The form body that trades the one-time code for tokens.
    public func codeExchangeBody(code: String, verifier: String) -> Data {
        GoogleForm.encode([
            ("code", code), ("client_id", clientID), ("redirect_uri", redirectURI),
            ("grant_type", "authorization_code"), ("code_verifier", verifier),
        ])
    }

    /// The form body that gets a new access token from the refresh token.
    public func refreshBody(refreshToken: String) -> Data {
        GoogleForm.encode([
            ("client_id", clientID), ("refresh_token", refreshToken), ("grant_type", "refresh_token"),
        ])
    }

    public static func revokeBody(token: String) -> Data {
        GoogleForm.encode([("token", token)])
    }
}

public enum GoogleForm {
    /// `application/x-www-form-urlencoded`, escaping everything but the unreserved characters.
    public static func encode(_ pairs: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let text = pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(text.utf8)
    }
}

public enum PKCE {
    /// Base64 without padding, with `-` and `_` (RFC 7636 appendix A).
    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// A verifier made from 32 random bytes is 43 characters, the shortest RFC 7636 allows.
    public static func isValidVerifier(_ verifier: String) -> Bool {
        (43...128).contains(verifier.count)
            && verifier.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "-._~".unicodeScalars.contains($0) }
    }
}

/// What came back to the redirect URL.
public enum GoogleCallback: Equatable, Sendable {
    case code(String)
    case denied
    case failed(String)

    /// nil when the URL is not our redirect, or the state does not match (a reply to some other request).
    public init?(url: URL, config: GoogleOAuthConfig, expectedState: String) {
        guard url.scheme?.lowercased() == config.redirectScheme.lowercased(),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == expectedState else { return nil }
        if let error = value("error") {
            self = error == "access_denied" ? .denied : .failed(error)
        } else if let code = value("code"), !code.isEmpty {
            self = .code(code)
        } else {
            self = .failed("no_code")
        }
    }
}

public struct GoogleTokens: Codable, Equatable, Sendable {
    public var accessToken: String
    public var expiresAt: Date
    public var refreshToken: String?
    public var scope: String?

    public init(accessToken: String, expiresAt: Date, refreshToken: String?, scope: String?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.scope = scope
    }

    /// Treat the token as expired a minute early so a request does not start with a token about to run out.
    public func isFresh(at now: Date) -> Bool { expiresAt.timeIntervalSince(now) > 60 }

    /// True when the person unticked one of the boxes on Google's screen.
    public var grantsAllScopes: Bool {
        guard let scope else { return true }
        let granted = Set(scope.split(separator: " ").map(String.init))
        return GoogleOAuthConfig.scopes.allSatisfy(granted.contains)
    }

    /// A refresh reply has no refresh token; the old one stays.
    public func merged(with newer: GoogleTokens) -> GoogleTokens {
        GoogleTokens(accessToken: newer.accessToken, expiresAt: newer.expiresAt,
                     refreshToken: newer.refreshToken ?? refreshToken, scope: newer.scope ?? scope)
    }
}

public enum GoogleTokenReply: Equatable, Sendable {
    case tokens(GoogleTokens)
    /// The refresh token was revoked or expired: the person has to sign in again.
    case signInAgain
    case failed(String)

    public init(data: Data, receivedAt now: Date) {
        struct Body: Decodable {
            let access_token: String?
            let expires_in: Double?
            let refresh_token: String?
            let scope: String?
            let error: String?
        }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else {
            self = .failed("unreadable")
            return
        }
        if let error = body.error {
            self = error == "invalid_grant" ? .signInAgain : .failed(error)
        } else if let token = body.access_token, !token.isEmpty {
            self = .tokens(GoogleTokens(accessToken: token, expiresAt: now.addingTimeInterval(body.expires_in ?? 3600),
                                        refreshToken: body.refresh_token, scope: body.scope))
        } else {
            self = .failed("no_token")
        }
    }
}

// MARK: - Calendar list and colors

public struct GoogleCalendarEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let color: RGB
    public let writable: Bool
    public let isPrimary: Bool

    public init(id: String, title: String, color: RGB, writable: Bool, isPrimary: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.writable = writable
        self.isPrimary = isPrimary
    }
}

public struct GoogleCalendarListPage: Equatable, Sendable {
    public let entries: [GoogleCalendarEntry]
    public let nextPageToken: String?

    public init(data: Data) throws {
        struct Item: Decodable {
            let id: String
            let summary: String?
            let summaryOverride: String?
            let backgroundColor: String?
            let accessRole: String?
            let primary: Bool?
            let deleted: Bool?
        }
        struct Body: Decodable {
            let items: [Item]?
            let nextPageToken: String?
        }
        let body = try JSONDecoder().decode(Body.self, from: data)
        entries = (body.items ?? []).filter { $0.deleted != true }.map { item in
            GoogleCalendarEntry(
                id: item.id,
                title: item.summaryOverride ?? item.summary ?? item.id,
                color: item.backgroundColor.flatMap(RGB.init(hex:)) ?? RGB(red: 0.26, green: 0.52, blue: 0.96),
                writable: item.accessRole == "owner" || item.accessRole == "writer",
                isPrimary: item.primary == true)
        }
        nextPageToken = body.nextPageToken
    }

    /// The primary calendar's ID is the account's email address.
    public static func accountEmail(of entries: [GoogleCalendarEntry]) -> String? {
        entries.first { $0.isPrimary }?.id
    }
}

public enum GoogleColors {
    /// The event palette from `GET /colors` (colorId → background).
    public static func eventPalette(from data: Data) throws -> [String: RGB] {
        struct Definition: Decodable { let background: String }
        struct Body: Decodable { let event: [String: Definition]? }
        let body = try JSONDecoder().decode(Body.self, from: data)
        return (body.event ?? [:]).compactMapValues { RGB(hex: $0.background) }
    }
}

extension RGB {
    /// `#rrggbb` (the `#` may be left out).
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255)
    }
}

// MARK: - Events

public struct GoogleEvent: Codable, Equatable, Sendable, Identifiable {
    /// Unique per occurrence (repeating events are expanded with `singleEvents=true`).
    public let id: String
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let colorID: String?
    /// Set for one occurrence of a repeating event.
    public let recurringEventID: String?

    public init(id: String, calendarID: String, title: String, start: Date, end: Date, isAllDay: Bool,
                location: String?, notes: String?, colorID: String?, recurringEventID: String?) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.colorID = colorID
        self.recurringEventID = recurringEventID
    }
}

public struct GoogleEventPage: Equatable, Sendable {
    public let events: [GoogleEvent]
    public let nextPageToken: String?

    /// `calendar` decides which day an all-day event (`"date": "2026-11-14"`) falls on.
    public init(data: Data, calendarID: String, calendar: Calendar) throws {
        let body = try JSONDecoder().decode(EventsBody.self, from: data)
        events = (body.items ?? []).compactMap { GoogleEvent(item: $0, calendarID: calendarID, calendar: calendar) }
        nextPageToken = body.nextPageToken
    }

    /// One event, as `events.insert` and `events.patch` return it.
    public static func single(data: Data, calendarID: String, calendar: Calendar) throws -> GoogleEvent? {
        let item = try JSONDecoder().decode(EventItem.self, from: data)
        return GoogleEvent(item: item, calendarID: calendarID, calendar: calendar)
    }

    struct EventTime: Decodable {
        let date: String?
        let dateTime: String?
    }

    struct EventItem: Decodable {
        let id: String
        let status: String?
        let summary: String?
        let location: String?
        let description: String?
        let colorId: String?
        let recurringEventId: String?
        let start: EventTime?
        let end: EventTime?
    }

    struct EventsBody: Decodable {
        let items: [EventItem]?
        let nextPageToken: String?
    }
}

extension GoogleEvent {
    init?(item: GoogleEventPage.EventItem, calendarID: String, calendar: Calendar) {
        guard item.status != "cancelled", let startTime = item.start, let endTime = item.end else { return nil }
        let allDay: Bool
        let start: Date
        let end: Date
        if let s = startTime.date, let e = endTime.date {
            guard let a = GoogleTime.day(s, calendar: calendar), let b = GoogleTime.day(e, calendar: calendar) else { return nil }
            allDay = true
            start = a
            end = max(a, b)     // Google's end date is the day after the last day, like EventKit's.
        } else if let s = startTime.dateTime, let e = endTime.dateTime {
            guard let a = GoogleTime.instant(s), let b = GoogleTime.instant(e) else { return nil }
            allDay = false
            start = a
            end = max(a, b)
        } else {
            return nil
        }
        let title = (item.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(id: item.id, calendarID: calendarID, title: title, start: start, end: end, isAllDay: allDay,
                  location: item.location.flatMap { $0.isEmpty ? nil : $0 },
                  notes: item.description.flatMap { $0.isEmpty ? nil : $0 },
                  colorID: item.colorId, recurringEventID: item.recurringEventId)
    }
}

public enum GoogleTime {
    /// `2026-11-14` → midnight of that day in `calendar`.
    public static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let c = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: c),
              calendar.component(.day, from: date) == parts[2] else { return nil }
        return date
    }

    /// `2026-11-14T19:00:00+09:00`, with or without fractions of a second.
    public static func instant(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    /// RFC 3339 in UTC, for `timeMin` and `timeMax`.
    public static func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// `2026-11-14` in `calendar`.
    public static func dayText(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// The JSON body for `events.insert` and `events.patch`.
public struct GoogleEventDraft: Equatable, Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?

    public init(title: String, start: Date, end: Date, isAllDay: Bool, location: String? = nil, notes: String? = nil) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
    }

    /// For a patch, empty strings clear the location and notes on Google's side.
    public func json(calendar: Calendar) -> Data {
        var body: [String: Any] = [
            "summary": title,
            "location": location ?? "",
            "description": notes ?? "",
        ]
        if isAllDay {
            let first = calendar.startOfDay(for: start)
            let lastStart = calendar.startOfDay(for: max(start, end))
            // An all-day event needs an end date after the start date: one day at least.
            let after = lastStart > first ? lastStart : (calendar.date(byAdding: .day, value: 1, to: first) ?? first)
            body["start"] = ["date": GoogleTime.dayText(first, calendar: calendar)]
            body["end"] = ["date": GoogleTime.dayText(after, calendar: calendar)]
        } else {
            body["start"] = ["dateTime": GoogleTime.stamp(start)]
            body["end"] = ["dateTime": GoogleTime.stamp(max(start, end))]
        }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }
}

// MARK: - Showing Google next to the device's calendars

public enum GoogleMerge {
    /// Device calendars whose account is one of the connected Google accounts. They are hidden so nothing shows twice.
    public static func duplicateDeviceCalendars(_ calendars: [(id: String, account: String)],
                                                googleEmails: [String]) -> Set<String> {
        let emails = Set(googleEmails.map { $0.lowercased() })
        return Set(calendars.filter { emails.contains($0.account.trimmingCharacters(in: .whitespaces).lowercased()) }.map(\.id))
    }

    /// The color an event shows: the event's own Google color when allowed and known, else its calendar's.
    public static func color(of event: GoogleEvent, calendarColor: RGB, palette: [String: RGB], useEventColors: Bool) -> RGB {
        guard useEventColors, let id = event.colorID, let color = palette[id] else { return calendarColor }
        return color
    }
}

/// Where a Google calendar or event lives, packed into the string IDs the rest of the app uses.
/// `google:<email>|<calendar ID>` for a calendar, `google:<email>|<calendar ID>|<event ID>` for an event.
public struct GoogleRef: Hashable, Sendable {
    public static let prefix = "google:"
    public let email: String
    public let calendarID: String
    public let eventID: String?

    public init(email: String, calendarID: String, eventID: String? = nil) {
        self.email = email
        self.calendarID = calendarID
        self.eventID = eventID
    }

    public init?(key: String) {
        guard key.hasPrefix(Self.prefix) else { return nil }
        let parts = key.dropFirst(Self.prefix.count).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard (2...3).contains(parts.count), !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        email = parts[0]
        calendarID = parts[1]
        eventID = parts.count == 3 && !parts[2].isEmpty ? parts[2] : nil
    }

    public var calendarKey: String { "\(Self.prefix)\(email)|\(calendarID)" }
    public var key: String { eventID.map { "\(calendarKey)|\($0)" } ?? calendarKey }
    public var calendar: GoogleRef { GoogleRef(email: email, calendarID: calendarID) }

    public static func isGoogle(_ key: String) -> Bool { key.hasPrefix(prefix) }
}

/// A calendar ID or event ID as one piece of a URL path (`#` and `@` appear in calendar IDs).
public enum GooglePath {
    public static func escape(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}

public enum GoogleAPIError: Equatable, Sendable {
    /// Signed out on Google's side: show 「ログインし直してください」.
    case signInAgain
    /// Missing permission (a box was unticked): also needs signing in again.
    case forbidden
    case notFound
    case rateLimited
    case server
    case other(Int)

    public init?(status: Int) {
        switch status {
        case 200..<300: return nil
        case 401: self = .signInAgain
        case 403: self = .forbidden
        case 404, 410: self = .notFound
        case 429: self = .rateLimited
        case 500..<600: self = .server
        default: self = .other(status)
        }
    }
}
