import Foundation
import PetaCore
import SwiftData
import SwiftUI
import UIKit

/// 記録: a photo, an amount and a memo on a day. Every property has a default and relationships are
/// optional, so the same model can sync through iCloud later without changing shape.
@Model
final class Record {
    var id: UUID = UUID()
    /// Midnight of the day the record belongs to.
    var day: Date = Date()
    /// RecordKind raw value: balance / oshi / free.
    var kindRaw: String = RecordKind.balance.rawValue
    /// 種目 (free text, the person's own words).
    var category: String = ""
    /// Yen. Plus is money in, minus is money out. nil when there is no amount.
    var amount: Int?
    var title: String = ""
    var memo: String = ""
    @Relationship(deleteRule: .cascade, inverse: \RecordPhoto.record)
    var photos: [RecordPhoto]? = []
    var createdAt: Date = Date()
    /// manual / share / bulk / ai
    var source: String = "manual"

    init(day: Date, kind: RecordKind, title: String = "", category: String = "", amount: Int? = nil, memo: String = "") {
        self.day = day
        self.kindRaw = kind.rawValue
        self.title = title
        self.category = category
        self.amount = amount
        self.memo = memo
    }

    var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .free }
    var sortedPhotos: [RecordPhoto] { (photos ?? []).sorted { $0.order < $1.order } }

    /// What to show as the row's name when the title is empty.
    var displayTitle: String {
        if !title.isEmpty { return title }
        if !category.isEmpty { return category }
        return kind.label
    }

    /// The amount that counts in totals (memo-only records have none).
    var countedAmount: Int? { kind == .free ? nil : amount }
}

@Model
final class RecordPhoto {
    var id: UUID = UUID()
    var order: Int = 0
    var takenAt: Date?
    @Attribute(.externalStorage) var data: Data = Data()
    var record: Record?

    init(data: Data, order: Int, takenAt: Date? = nil) {
        self.data = data
        self.order = order
        self.takenAt = takenAt
    }
}

extension RecordKind {
    /// The name people see.
    var label: String {
        switch self {
        case .balance: String(localized: "収支")
        case .oshi: String(localized: "推し活・趣味")
        case .free: String(localized: "メモ")
        }
    }

    var symbol: String {
        switch self {
        case .balance: "yensign.circle"
        case .oshi: "heart"
        case .free: "note.text"
        }
    }
}

extension Array where Element == Record {
    /// Amounts keyed by day, for the calendar and the charts.
    func dayAmounts(calendar: Calendar) -> [(day: DayKey, amount: Int)] {
        compactMap { record in
            record.countedAmount.map { (DayKey(date: record.day, calendar: calendar), $0) }
        }
    }

    func totalsByDay(calendar: Calendar) -> [DayKey: Int] {
        var out: [DayKey: Int] = [:]
        for entry in dayAmounts(calendar: calendar) { out[entry.day, default: 0] += entry.amount }
        return out
    }

    func on(_ day: DayKey, calendar: Calendar) -> [Record] {
        filter { DayKey(date: $0.day, calendar: calendar) == day }.sorted { $0.createdAt < $1.createdAt }
    }
}

extension Color {
    /// Plus amounts (always shown with a + sign as well).
    static let plusAmount = Color(uiColor: UIColor { @Sendable traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1) : UIColor(red: 0.09, green: 0.44, blue: 0.18, alpha: 1)
    })
    /// Minus amounts (always shown with a − sign as well).
    static let minusAmount = Color(uiColor: UIColor { @Sendable traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.41, blue: 0.38, alpha: 1) : UIColor(red: 0.77, green: 0, blue: 0.10, alpha: 1)
    })

    static func amount(_ value: Int) -> Color {
        value > 0 ? .plusAmount : (value < 0 ? .minusAmount : .primary)
    }
}

/// Shrinks a picked photo so records stay small enough to sync.
enum PhotoShrinker {
    static func jpeg(from data: Data, maxSide: CGFloat = 2048) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image.jpegData(compressionQuality: 0.85) }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
