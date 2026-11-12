import Foundation
import ImageIO
import Security

/// What another app shared to ペタカレ (「ペタカレに送る」), waiting until the app opens.
/// The share extension writes it; the app reads it once and removes it. Nothing leaves the device.
struct SharedItem: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case event, record }

    var id = UUID()
    var kind: Kind
    var text: String
    var photoCount: Int
    var created = Date()
}

struct SharedPayload: Equatable, Sendable {
    var item: SharedItem
    var photos: [Data]
}

/// Kept in a keychain group the app and the share extension both use. Keychain groups that start with
/// the team id need no registration on Apple's site (unlike App Groups), so this works with automatic signing.
enum ShareInbox {
    static let service = "com.seventhwell.petacal.inbox"
    static let maxPhotos = 10

    /// "TEAMID.com.seventhwell.petacal.shared", from the Info.plist (nil in unsigned test builds).
    static var accessGroup: String? {
        guard let prefix = Bundle.main.object(forInfoDictionaryKey: "PetacalTeamPrefix") as? String,
              !prefix.isEmpty, !prefix.contains("$") else { return nil }
        return prefix + "com.seventhwell.petacal.shared"
    }

    private static func query(_ account: String? = nil) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        if let account { q[kSecAttrAccount as String] = account }
        return q
    }

    private static func put(_ account: String, _ data: Data) throws {
        var q = query(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemDelete(query(account) as CFDictionary)
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private static func read(_ account: String) -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    private static func accounts() -> [String] {
        var q = query()
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let rows = out as? [[String: Any]] else { return [] }
        return rows.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    static func save(kind: SharedItem.Kind, text: String, photos: [Data]) throws {
        let kept = Array(photos.prefix(maxPhotos))
        let item = SharedItem(kind: kind, text: text, photoCount: kept.count)
        let id = item.id.uuidString
        for (index, data) in kept.enumerated() {
            try put("\(id).\(index)", data)
        }
        // The item goes last: a half-written entry is never picked up.
        try put("\(id).json", JSONEncoder().encode(item))
    }

    /// The oldest waiting item, taken out of the inbox.
    static func next() -> SharedPayload? {
        let names = accounts()
        let items: [SharedItem] = names.filter { $0.hasSuffix(".json") }.compactMap { name in
            read(name).flatMap { try? JSONDecoder().decode(SharedItem.self, from: $0) }
        }
        guard let oldest = items.min(by: { $0.created < $1.created }) else { return nil }
        let id = oldest.id.uuidString
        let photos = (0..<oldest.photoCount).compactMap { read("\(id).\($0)") }
        for name in names where name.hasPrefix(id) {
            SecItemDelete(query(name) as CFDictionary)
        }
        return SharedPayload(item: oldest, photos: photos)
    }

    /// A JPEG at most `maxSide` pixels on its long side, upright.
    static func shrink(_ data: Data, maxSide: Int = 1600) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
