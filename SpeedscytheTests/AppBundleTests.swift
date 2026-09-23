import XCTest

final class AppBundleTests: XCTestCase {
    func testAppRunsAsAgentWithoutDockIcon() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
    }
}
