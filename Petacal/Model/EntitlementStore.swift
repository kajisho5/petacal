import Foundation
import Observation
import StoreKit

/// ペタカレ Pro: what was bought (StoreKit 2), and the screen that sells it.
/// The products live in App Store Connect (tools/asc_products.py creates them).
@Observable
final class EntitlementStore {
    static let yearly = "com.seventhwell.petacal.pro.yearly"
    static let monthly = "com.seventhwell.petacal.pro.monthly"
    static let lifetime = "com.seventhwell.petacal.pro.lifetime"
    static let productIDs = [yearly, monthly, lifetime]

    /// Free plan limits (design-spec A-1).
    static let freePhotos = 1

    private(set) var products: [String: Product] = [:]
    private(set) var owned: Set<String> = []
    private(set) var didLoad = false
    /// TestFlight or a debug build where the products cannot be found yet: everything stays open,
    /// so testing does not stop. Never on the App Store.
    private(set) var testUnlock = false
    /// Why the Pro screen is showing (nil: not showing).
    var paywallReason: String?

    private let forced: Bool?
    private var updates: Task<Void, Never>?

    /// `forced` decides Pro without StoreKit (screenshots and tests).
    init(forced: Bool? = nil) {
        self.forced = forced
        didLoad = forced != nil
    }

    var isPro: Bool { forced ?? (!owned.isEmpty || testUnlock) }
    var hasLifetime: Bool { owned.contains(EntitlementStore.lifetime) }
    var hasSubscription: Bool { owned.contains(EntitlementStore.yearly) || owned.contains(EntitlementStore.monthly) }

    var planName: String {
        if hasLifetime { return String(localized: "Pro（買い切り）") }
        if owned.contains(EntitlementStore.yearly) { return String(localized: "Pro（年額）") }
        if owned.contains(EntitlementStore.monthly) { return String(localized: "Pro（月額）") }
        if testUnlock { return String(localized: "テスト中（すべて使えます）") }
        return String(localized: "無料版")
    }

    /// Opens the Pro screen, saying which feature asked for it.
    func ask(_ reason: String) {
        paywallReason = reason
    }

    func start() async {
        guard forced == nil, updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        await refresh()
        await loadProducts()
    }

    func refresh() async {
        guard forced == nil else { return }
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        owned = ids
    }

    func loadProducts() async {
        guard forced == nil else { return }
        let list = (try? await Product.products(for: EntitlementStore.productIDs)) ?? []
        products = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        didLoad = true
        testUnlock = list.isEmpty ? await EntitlementStore.isTestBuild() : false
    }

    /// After a purchase from the Pro screen.
    func finish(_ result: Product.PurchaseResult) async -> Bool {
        guard case .success(let verification) = result, case .verified(let transaction) = verification else { return false }
        await transaction.finish()
        await refresh()
        return true
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private static func isTestBuild() async -> Bool {
        #if DEBUG
        return true
        #else
        guard let result = try? await AppTransaction.shared, case .verified(let app) = result else { return false }
        return app.environment != .production
        #endif
    }
}
