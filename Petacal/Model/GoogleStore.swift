import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import PetaCore
import Security
import SwiftUI

/// Google Calendar, connected directly (design spec section C).
/// Talks to Google only: no server of ours. The refresh token lives in the Keychain; events are cached on the device.
@Observable
final class GoogleStore {
    struct Account: Codable, Identifiable, Equatable {
        var email: String
        var calendars: [GoogleCalendarEntry] = []
        var lastLoaded: Date?
        /// Google said no to the saved sign-in (revoked, expired, or a permission was unticked).
        var needsSignIn = false
        /// Show each event in its own Google color (S-18).
        var useEventColors = true
        var id: String { email }
    }

    enum Failure: Error, Equatable {
        case notConfigured
        case cancelled
        case missingPermission
        case signInAgain
        case network
        case google(String)
    }

    /// nil until the Google client ID is set in the build (`GOOGLE_CLIENT_ID`). The screens then say it is not ready.
    let config: GoogleOAuthConfig?
    private(set) var accounts: [Account] = []
    private(set) var events: [String: [GoogleEvent]] = [:]
    private(set) var palette: [String: RGB] = [:]
    /// Accounts being read right now (the rows show a spinner).
    private(set) var loading: Set<String> = []
    /// Accounts whose last reading failed for a reason other than signing in (offline, Google down).
    private(set) var unreachable: Set<String> = []
    /// Called after anything shown in the calendar changed.
    @ObservationIgnored var onChange: (() -> Void)?

    private let calendar = Calendar.current
    private let session: URLSession
    @ObservationIgnored private var refreshing: [String: Task<GoogleTokens, Error>] = [:]
    private static let accountsKey = "google.accounts"
    private static let paletteKey = "google.palette"
    private static let api = "https://www.googleapis.com/calendar/v3"

    init(clientID: String? = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String) {
        config = clientID.flatMap(GoogleOAuthConfig.init(clientID:))
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
        if let data = UserDefaults.standard.data(forKey: Self.accountsKey),
           let saved = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = saved
        }
        if let data = UserDefaults.standard.data(forKey: Self.paletteKey),
           let saved = try? JSONDecoder().decode([String: RGB].self, from: data) {
            palette = saved
        }
        for account in accounts {
            events[account.email] = Self.loadCache(for: account.email)
        }
    }

    var isAvailable: Bool { config != nil }

    func account(_ email: String) -> Account? { accounts.first { $0.email == email } }

    // MARK: Signing in

    /// S-17 → Google's own sign-in screen → back here. Adds the account, or updates it after signing in again.
    func connect(using web: WebAuthenticationSession, loginHint: String? = nil) async throws {
        guard let config else { throw Failure.notConfigured }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw Failure.google("random") }
        let verifier = PKCE.base64URL(Data(bytes))
        let challenge = PKCE.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = UUID().uuidString
        let url = config.authorizationURL(state: state, codeChallenge: challenge, loginHint: loginHint)

        let callbackURL: URL
        do {
            callbackURL = try await web.authenticate(using: url, callback: .customScheme(config.redirectScheme),
                                                     additionalHeaderFields: [:])
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw Failure.cancelled
        }
        guard let callback = GoogleCallback(url: callbackURL, config: config, expectedState: state) else {
            throw Failure.google("callback")
        }
        let code: String
        switch callback {
        case .code(let value): code = value
        case .denied: throw Failure.cancelled
        case .failed(let reason): throw Failure.google(reason)
        }

        var request = URLRequest(url: GoogleOAuthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = config.codeExchangeBody(code: code, verifier: verifier)
        let tokens: GoogleTokens
        switch GoogleTokenReply(data: try await raw(request).data, receivedAt: Date()) {
        case .tokens(let value): tokens = value
        case .signInAgain: throw Failure.signInAgain
        case .failed(let reason): throw Failure.google(reason)
        }
        guard tokens.grantsAllScopes else { throw Failure.missingPermission }

        let calendars = try await calendarList(accessToken: tokens.accessToken)
        guard let email = GoogleCalendarListPage.accountEmail(of: calendars) else { throw Failure.google("no_primary") }
        GoogleKeychain.save(tokens, for: email)
        if let index = accounts.firstIndex(where: { $0.email == email }) {
            accounts[index].needsSignIn = false
            accounts[index].calendars = calendars
        } else {
            accounts.append(Account(email: email, calendars: calendars))
        }
        saveAccounts()
        await load(email, force: true)
    }

    /// S-18 「接続を解除」: revoke on Google's side, then forget everything kept here. Google's events stay.
    func disconnect(_ email: String) async {
        if let tokens = GoogleKeychain.load(for: email) {
            var request = URLRequest(url: GoogleOAuthConfig.revokeEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = GoogleOAuthConfig.revokeBody(token: tokens.refreshToken ?? tokens.accessToken)
            _ = try? await raw(request)     // Offline: the token still goes from this device below.
        }
        GoogleKeychain.delete(for: email)
        accounts.removeAll { $0.email == email }
        events[email] = nil
        loading.remove(email)
        unreachable.remove(email)
        try? FileManager.default.removeItem(at: Self.cacheURL(for: email))
        saveAccounts()
        onChange?()
    }

    func setUseEventColors(_ email: String, _ value: Bool) {
        guard let index = accounts.firstIndex(where: { $0.email == email }) else { return }
        accounts[index].useEventColors = value
        saveAccounts()
        onChange?()
    }

    // MARK: Reading

    /// Reads every connected account. Skips accounts read in the last minute unless `force`.
    func loadAll(force: Bool = false) async {
        for account in accounts where !account.needsSignIn {
            await load(account.email, force: force)
        }
    }

    /// The calendar list, the color palette and events from a year back to a year ahead.
    /// (A sync token cannot be combined with a time window, so the window is read again each time.)
    func load(_ email: String, force: Bool) async {
        guard let index = accounts.firstIndex(where: { $0.email == email }), !loading.contains(email) else { return }
        if !force, let last = accounts[index].lastLoaded, Date().timeIntervalSince(last) < 60 { return }
        loading.insert(email)
        defer { loading.remove(email) }
        do {
            let calendars = try await calendarList(email: email)
            if let colors = try? await send(URLRequest(url: URL(string: "\(Self.api)/colors")!), email: email),
               let read = try? GoogleColors.eventPalette(from: colors), !read.isEmpty {
                palette = read
                if let data = try? JSONEncoder().encode(read) { UserDefaults.standard.set(data, forKey: Self.paletteKey) }
            }
            let now = Date()
            let from = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let to = calendar.date(byAdding: .year, value: 1, to: now) ?? now
            var read: [GoogleEvent] = []
            for entry in calendars {
                read += try await eventList(email: email, calendarID: entry.id, from: from, to: to)
            }
            guard let current = accounts.firstIndex(where: { $0.email == email }) else { return }   // Disconnected meanwhile.
            accounts[current].calendars = calendars
            accounts[current].lastLoaded = Date()
            accounts[current].needsSignIn = false
            events[email] = read
            unreachable.remove(email)
            Self.saveCache(read, for: email)
            saveAccounts()
        } catch Failure.signInAgain {
            markSignIn(email)
        } catch {
            unreachable.insert(email)
        }
        onChange?()
    }

    private func calendarList(email: String) async throws -> [GoogleCalendarEntry] {
        var entries: [GoogleCalendarEntry] = []
        var pageToken: String?
        repeat {
            var parts = URLComponents(string: "\(Self.api)/users/me/calendarList")!
            parts.queryItems = [URLQueryItem(name: "maxResults", value: "250")]
                + (pageToken.map { [URLQueryItem(name: "pageToken", value: $0)] } ?? [])
            let page = try GoogleCalendarListPage(data: try await send(URLRequest(url: parts.url!), email: email))
            entries += page.entries
            pageToken = page.nextPageToken
        } while pageToken != nil
        return entries
    }

    /// Before the account is known (right after signing in).
    private func calendarList(accessToken: String) async throws -> [GoogleCalendarEntry] {
        var request = URLRequest(url: URL(string: "\(Self.api)/users/me/calendarList?maxResults=250")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, status) = try await raw(request)
        if let error = GoogleAPIError(status: status) { throw error == .signInAgain ? Failure.signInAgain : Failure.google("\(status)") }
        return try GoogleCalendarListPage(data: data).entries
    }

    private func eventList(email: String, calendarID: String, from: Date, to: Date) async throws -> [GoogleEvent] {
        var result: [GoogleEvent] = []
        var pageToken: String?
        repeat {
            var parts = URLComponents(string: "\(Self.api)/calendars/\(GooglePath.escape(calendarID))/events")!
            parts.percentEncodedPath = "/calendar/v3/calendars/\(GooglePath.escape(calendarID))/events"
            parts.queryItems = [
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "timeMin", value: GoogleTime.stamp(from)),
                URLQueryItem(name: "timeMax", value: GoogleTime.stamp(to)),
                URLQueryItem(name: "maxResults", value: "2500"),
            ] + (pageToken.map { [URLQueryItem(name: "pageToken", value: $0)] } ?? [])
            let page = try GoogleEventPage(data: try await send(URLRequest(url: parts.url!), email: email),
                                           calendarID: calendarID, calendar: calendar)
            result += page.events
            pageToken = page.nextPageToken
        } while pageToken != nil
        return result
    }

    // MARK: Writing

    /// Adds an event and returns its reference.
    func insert(_ draft: GoogleEventDraft, into target: GoogleRef) async throws -> GoogleRef {
        var request = URLRequest(url: eventsURL(target))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = draft.json(calendar: calendar)
        let data = try await send(request, email: target.email)
        guard let event = try GoogleEventPage.single(data: data, calendarID: target.calendarID, calendar: calendar) else {
            throw Failure.google("unreadable")
        }
        events[target.email, default: []].append(event)
        Self.saveCache(events[target.email] ?? [], for: target.email)
        onChange?()
        return GoogleRef(email: target.email, calendarID: target.calendarID, eventID: event.id)
    }

    /// Changes one event (one occurrence, for a repeating event).
    func update(_ ref: GoogleRef, with draft: GoogleEventDraft) async throws {
        guard let eventID = ref.eventID else { return }
        var request = URLRequest(url: eventsURL(ref, eventID: eventID))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = draft.json(calendar: calendar)
        let data = try await send(request, email: ref.email)
        guard let event = try GoogleEventPage.single(data: data, calendarID: ref.calendarID, calendar: calendar) else {
            throw Failure.google("unreadable")
        }
        var list = events[ref.email] ?? []
        list.removeAll { $0.id == eventID && $0.calendarID == ref.calendarID }
        list.append(event)
        events[ref.email] = list
        Self.saveCache(list, for: ref.email)
        onChange?()
    }

    func delete(_ ref: GoogleRef) async throws {
        guard let eventID = ref.eventID else { return }
        var request = URLRequest(url: eventsURL(ref, eventID: eventID))
        request.httpMethod = "DELETE"
        do {
            _ = try await send(request, email: ref.email)
        } catch Failure.google(let reason) where reason == "\(GoogleAPIError.notFound)" {
            // Already gone on Google's side: nothing more to do.
        }
        events[ref.email]?.removeAll { $0.id == eventID && $0.calendarID == ref.calendarID }
        Self.saveCache(events[ref.email] ?? [], for: ref.email)
        onChange?()
    }

    func event(_ ref: GoogleRef) -> GoogleEvent? {
        events[ref.email]?.first { $0.id == ref.eventID && $0.calendarID == ref.calendarID }
    }

    private func eventsURL(_ ref: GoogleRef, eventID: String? = nil) -> URL {
        var parts = URLComponents(string: "https://www.googleapis.com")!
        var path = "/calendar/v3/calendars/\(GooglePath.escape(ref.calendarID))/events"
        if let eventID { path += "/\(GooglePath.escape(eventID))" }
        parts.percentEncodedPath = path
        return parts.url!
    }

    // MARK: Requests

    /// Sends with a valid access token. A 401 gets one more try after refreshing the token.
    private func send(_ base: URLRequest, email: String) async throws -> Data {
        var tokens = try await validTokens(email: email, forceRefresh: false)
        for attempt in 0..<2 {
            var request = base
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            let (data, status) = try await raw(request)
            guard let error = GoogleAPIError(status: status) else { return data }
            if error == .signInAgain, attempt == 0 {
                tokens = try await validTokens(email: email, forceRefresh: true)
                continue
            }
            switch error {
            case .signInAgain, .forbidden where Self.isPermissionProblem(data):
                throw Failure.signInAgain
            default:
                throw Failure.google("\(error)")
            }
        }
        throw Failure.signInAgain
    }

    /// A 403 can also mean "too many requests"; only a missing permission needs signing in again.
    private static func isPermissionProblem(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        return text.contains("insufficientPermissions") || text.contains("ACCESS_TOKEN_SCOPE_INSUFFICIENT")
    }

    private func validTokens(email: String, forceRefresh: Bool) async throws -> GoogleTokens {
        guard let config, let saved = GoogleKeychain.load(for: email) else { throw Failure.signInAgain }
        if !forceRefresh, saved.isFresh(at: Date()) { return saved }
        if let running = refreshing[email] { return try await running.value }
        guard let refreshToken = saved.refreshToken else { throw Failure.signInAgain }
        let task = Task { () throws -> GoogleTokens in
            var request = URLRequest(url: GoogleOAuthConfig.tokenEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = config.refreshBody(refreshToken: refreshToken)
            switch GoogleTokenReply(data: try await self.raw(request).data, receivedAt: Date()) {
            case .tokens(let fresh):
                let merged = saved.merged(with: fresh)
                GoogleKeychain.save(merged, for: email)
                return merged
            case .signInAgain:
                throw Failure.signInAgain
            case .failed(let reason):
                throw Failure.google(reason)
            }
        }
        refreshing[email] = task
        defer { refreshing[email] = nil }
        return try await task.value
    }

    private func raw(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            throw Failure.network
        }
    }

    private func markSignIn(_ email: String) {
        guard let index = accounts.firstIndex(where: { $0.email == email }) else { return }
        accounts[index].needsSignIn = true
        saveAccounts()
    }

    // MARK: Saving on the device

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: Self.accountsKey) }
    }

    private static func cacheURL(for email: String) -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: "Google", directoryHint: .isDirectory)
        let name = PKCE.base64URL(Data(SHA256.hash(data: Data(email.lowercased().utf8)))) + ".json"
        return folder.appending(path: name)
    }

    private static func loadCache(for email: String) -> [GoogleEvent] {
        guard let data = try? Data(contentsOf: cacheURL(for: email)) else { return [] }
        return (try? JSONDecoder().decode([GoogleEvent].self, from: data)) ?? []
    }

    private static func saveCache(_ events: [GoogleEvent], for email: String) {
        let url = cacheURL(for: email)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

/// The sign-in for each Google account. Only on this device; never synced to iCloud.
enum GoogleKeychain {
    private static let service = "com.seventhwell.petacal.google"

    private static func query(_ email: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email.lowercased(),
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    static func save(_ tokens: GoogleTokens, for email: String) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let base = query(email)
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func load(for email: String) -> GoogleTokens? {
        var request = query(email)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    static func delete(for email: String) {
        SecItemDelete(query(email) as CFDictionary)
    }
}
