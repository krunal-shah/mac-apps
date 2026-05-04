import XCTest
@testable import GoLinks

final class GoLinkCoreTests: XCTestCase {
    func testNameNormalizationAcceptsCommonInput() throws {
        XCTAssertEqual(try GoLinkInput.normalizedName(" Docs "), "docs")
        XCTAssertEqual(try GoLinkInput.normalizedName("go/Team_Wiki"), "team_wiki")
        XCTAssertEqual(try GoLinkInput.normalizedName("https://go/Launch-Plan"), "launch-plan")
    }

    func testNameNormalizationRejectsInvalidInput() {
        XCTAssertThrowsError(try GoLinkInput.normalizedName(""))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("-bad"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("bad/path"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("bad path"))
    }

    func testURLNormalizationAddsSchemeAndRestrictsProtocols() throws {
        XCTAssertEqual(try GoLinkInput.normalizedURL("example.com"), "https://example.com")
        XCTAssertEqual(try GoLinkInput.normalizedURL("http://example.com"), "http://example.com")
        XCTAssertThrowsError(try GoLinkInput.normalizedURL("ftp://example.com"))
    }

    func testRouterRedirectsAndPreservesPathAndQuery() {
        let resolver = GoLinkResolver()
        resolver.replace(with: [
            GoLink(shortName: "docs", destinationURL: "https://example.com/base")
        ])
        let router = GoLinkRouter(resolver: resolver)
        let request = Data("GET /docs/team%20page?tab=owned HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 302 Found") == true)
        XCTAssertTrue(response?.contains("Location: https://example.com/base/team%20page?tab=owned") == true)
    }

    func testRouterRejectsUnsupportedMethods() {
        let router = GoLinkRouter(resolver: GoLinkResolver())
        let request = Data("POST /docs HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 405 Method Not Allowed") == true)
        XCTAssertTrue(response?.contains("Allow: GET, HEAD") == true)
    }
}
