import Foundation
import PetaCore
import Testing

/// What App Store Connect and App Review look at in the app itself.
struct MacStoreReadinessTests {
    /// The privacy manifest is in the app (UserDefaults is a required-reason API: CA92.1).
    @Test func privacyManifestIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(types.contains { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
    }

    /// The version is the one App Store Connect has (1.0) and encryption is declared as not used.
    @Test func googleClientIDIsUsable() throws {
        let raw = try #require(Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)
        let config = try #require(GoogleOAuthConfig(clientID: raw))
        #expect(config.redirectScheme.hasPrefix("com.googleusercontent.apps."))
    }

    @Test func versionAndEncryption() {
        let info = Bundle.main.infoDictionary ?? [:]
        #expect(info["CFBundleShortVersionString"] as? String == "1.0")
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }
}
