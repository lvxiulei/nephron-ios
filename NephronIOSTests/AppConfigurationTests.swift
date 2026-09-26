import Testing
import Foundation
@testable import NephronIOS

struct AppConfigurationTests {
    @Test func bundleDisplayNameIsProductName() {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #expect(displayName == "eGFR 肾康随记")
    }

    @Test func bundleIdentifierMatchesPlan() {
        #expect(Bundle.main.bundleIdentifier == "com.lvxiulei.nephronios")
    }
}
