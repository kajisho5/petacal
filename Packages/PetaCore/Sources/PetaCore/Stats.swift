import Foundation

public enum RecordKind: String, Sendable, Codable, CaseIterable {
    /// 収支: plus and minus amounts (FX, 競馬, 競艇 ...)
    case balance
    /// 推し活: spending
    case oshi
    /// 自由: photo and memo only
    case free
}

/// The part of a record that statistics need.
public struct RecordAmount: Equatable, Sendable {
    public var kind: RecordKind
    public var category: String?
    /// Yen. Plus is income, minus is spending. nil when the record has no amount.
    public var amount: Int?

    public init(kind: RecordKind, category: String? = nil, amount: Int? = nil) {
        self.kind = kind
        self.category = category
        self.amount = amount
    }
}

public struct CategoryTotal: Equatable, Sendable {
    public var name: String
    public var total: Int
    public var count: Int
}

public struct MonthStats: Equatable, Sendable {
    public var balanceTotal = 0
    public var plusCount = 0
    public var minusCount = 0
    /// Balance records by category, largest total first.
    public var byCategory: [CategoryTotal] = []
    /// 推し活 spending as a positive number.
    public var oshiSpent = 0
    public var oshiCount = 0
}

public enum StatsCalculator {
    public static let uncategorized = "その他"

    public static func monthStats(_ records: [RecordAmount]) -> MonthStats {
        var stats = MonthStats()
        var totals: [String: (total: Int, count: Int)] = [:]
        for record in records {
            switch record.kind {
            case .balance:
                guard let amount = record.amount else { continue }
                stats.balanceTotal += amount
                if amount > 0 { stats.plusCount += 1 } else if amount < 0 { stats.minusCount += 1 }
                let name = record.category.flatMap { $0.isEmpty ? nil : $0 } ?? uncategorized
                let current = totals[name] ?? (0, 0)
                totals[name] = (current.total + amount, current.count + 1)
            case .oshi:
                stats.oshiCount += 1
                if let amount = record.amount, amount < 0 { stats.oshiSpent += -amount }
            case .free:
                continue
            }
        }
        stats.byCategory = totals
            .map { CategoryTotal(name: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { ($0.total, $1.name) > ($1.total, $0.name) }
        return stats
    }
}

/// How much of a monthly budget is used.
public struct BudgetUsage: Equatable, Sendable {
    public enum Level: Sendable { case ok, near, over }

    public var limit: Int
    public var spent: Int

    public init(limit: Int, spent: Int) {
        self.limit = limit
        self.spent = spent
    }

    public var remaining: Int { limit - spent }
    /// Rounded percent. 0 when no limit is set.
    public var percent: Int {
        limit > 0 ? Int((Double(spent) / Double(limit) * 100).rounded()) : 0
    }
    /// near from 80%, over above 100%.
    public var level: Level {
        guard limit > 0 else { return .ok }
        if spent > limit { return .over }
        return spent * 5 >= limit * 4 ? .near : .ok
    }
}
