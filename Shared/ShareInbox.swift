import Foundation
import ImageIO

/// What another app shared to ペタカレ (「ペタカレに送る」), waiting in the shared folder until the app opens.
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

enum ShareInbox {
    static let groupID = "group.com.seventhwell.petacal"
    static let maxPhotos = 10

    /// nil when the app group is missing (Mac, tests without signing).
    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    static func save(kind: SharedItem.Kind, text: String, photos: [Data]) throws {
        guard let folder else { throw CocoaError(.fileNoSuchFile) }
        let kept = Array(photos.prefix(maxPhotos))
        let item = SharedItem(kind: kind, text: text, photoCount: kept.count)
        let dir = folder.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (index, data) in kept.enumerated() {
            try data.write(to: dir.appendingPathComponent("\(index).jpg"), options: .atomic)
        }
        // The item file goes last: a half-written folder is never picked up.
        try JSONEncoder().encode(item).write(to: dir.appendingPathComponent("item.json"), options: .atomic)
    }

    /// The oldest waiting item, taken out of the folder.
    static func next() -> SharedPayload? {
        guard let folder,
              let dirs = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        let items: [(dir: URL, item: SharedItem)] = dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("item.json")),
                  let item = try? JSONDecoder().decode(SharedItem.self, from: data) else { return nil }
            return (dir, item)
        }
        guard let oldest = items.min(by: { $0.item.created < $1.item.created }) else { return nil }
        let photos = (0..<oldest.item.photoCount).compactMap { try? Data(contentsOf: oldest.dir.appendingPathComponent("\($0).jpg")) }
        try? FileManager.default.removeItem(at: oldest.dir)
        return SharedPayload(item: oldest.item, photos: photos)
    }

    /// A JPEG at most `maxSide` pixels on its long side, upright.
    static func shrink(_ data: Data, maxSide: Int = 2048) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
