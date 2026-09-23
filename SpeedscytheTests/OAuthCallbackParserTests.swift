import XCTest
@testable import Speedscythe

final class OAuthCallbackParserTests: XCTestCase {
    private let state = "expected-state"

    func testParsesFragmentParameters() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&token_type=bearer&expires_in=1209600&state=expected-state&scope=harvest%3A123")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback, OAuthCallback(accessToken: "abc", expiresIn: 1_209_600, accountScope: .account(123)))
    }

    func testParsesQueryParameters() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback?access_token=abc&token_type=bearer&expires_in=60&state=expected-state&scope=harvest:123")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback, OAuthCallback(accessToken: "abc", expiresIn: 60, accountScope: .account(123)))
    }

    func testKeepsEncodedCharactersInFragmentValues() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=a%26b%3Dc&expires_in=60&state=expected-state&scope=harvest%3A123")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback.accessToken, "a&b=c")
    }

    func testRejectsStateMismatch() {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=other&scope=harvest%3A123")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .stateMismatch)
        }
    }

    func testRejectsMissingState() {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&scope=harvest%3A123")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .stateMismatch)
        }
    }

    func testChecksStateBeforeReportingErrors() {
        let url = URL(string: "http://127.0.0.1:47823/callback#error=access_denied&state=other")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .stateMismatch)
        }
    }

    func testReportsAuthorizationError() {
        let url = URL(string: "http://127.0.0.1:47823/callback#error=access_denied&state=expected-state")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .authorizationFailed("access_denied"))
        }
    }

    func testPrefersErrorDescription() {
        let url = URL(string: "http://127.0.0.1:47823/callback#error=access_denied&error_description=User%20declined&state=expected-state")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .authorizationFailed("User declined"))
        }
    }

    func testRequiresAccessToken() {
        let url = URL(string: "http://127.0.0.1:47823/callback#expires_in=60&state=expected-state&scope=harvest%3A123")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .missingParameter("access_token"))
        }
    }

    func testRequiresNumericExpiresIn() {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=soon&state=expected-state&scope=harvest%3A123")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .missingParameter("expires_in"))
        }
    }

    func testRequiresScope() {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .missingParameter("scope"))
        }
    }

    func testFindsHarvestAccountInCombinedScope() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state&scope=forecast%3A9%20harvest%3A123")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback.accountScope, .account(123))
    }

    func testAcceptsPlusSeparatedScope() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state&scope=forecast:9+harvest:123")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback.accountScope, .account(123))
    }

    func testMapsHarvestAllScopeToAllAccounts() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state&scope=harvest%3Aall")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback.accountScope, .allAccounts)
    }

    func testMapsAllScopeToAllAccounts() throws {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state&scope=all")!

        let callback = try OAuthCallbackParser.parse(url, expectedState: state)

        XCTAssertEqual(callback.accountScope, .allAccounts)
    }

    func testRejectsForecastOnlyScope() {
        let url = URL(string: "http://127.0.0.1:47823/callback#access_token=abc&expires_in=60&state=expected-state&scope=forecast%3A9")!

        XCTAssertThrowsError(try OAuthCallbackParser.parse(url, expectedState: state)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .unsupportedScope("forecast:9"))
        }
    }
}
