import XCTest
@testable import GoLinks

final class GoLinkCoreTests: XCTestCase {
    func testNameNormalizationAcceptsCommonInput() throws {
        XCTAssertEqual(try GoLinkInput.normalizedName(" Docs "), "docs")
        XCTAssertEqual(try GoLinkInput.normalizedName("go/Team_Wiki"), "team_wiki")
        XCTAssertEqual(try GoLinkInput.normalizedName("go/Team/Wiki"), "team/wiki")
        XCTAssertEqual(try GoLinkInput.normalizedName("https://go/Launch-Plan"), "launch-plan")
    }

    func testNameNormalizationRejectsInvalidInput() {
        XCTAssertThrowsError(try GoLinkInput.normalizedName(""))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("-bad"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("bad//path"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("bad path"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("paste"))
        XCTAssertThrowsError(try GoLinkInput.normalizedName("paste/item"))
    }

    func testURLNormalizationAddsSchemeAndRestrictsProtocols() throws {
        XCTAssertEqual(try GoLinkInput.normalizedURL("example.com"), "https://example.com")
        XCTAssertEqual(try GoLinkInput.normalizedURL("http://example.com"), "http://example.com")
        XCTAssertEqual(
            try GoLinkInput.normalizedURL("www.google.com/search?q={path}"),
            "https://www.google.com/search?q={path}"
        )
        XCTAssertThrowsError(try GoLinkInput.normalizedURL("ftp://example.com"))
        XCTAssertThrowsError(try GoLinkInput.normalizedURL("www.google.com/search?q={term}"))
    }

    func testRouterLeavesUntemplatedDestinationPathUnchanged() {
        let resolver = GoLinkResolver()
        let pasteResolver = PasteResolver()
        resolver.replace(with: [
            GoLink(shortName: "docs", destinationURL: "https://example.com/base")
        ])
        let router = GoLinkRouter(linkResolver: resolver, pasteResolver: pasteResolver)
        let request = Data("GET /docs/team%20page?tab=owned HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 302 Found") == true)
        XCTAssertTrue(response?.contains("Location: https://example.com/base?tab=owned") == true)
    }

    func testRouterResolvesLongestNestedShortcutPrefix() {
        let resolver = GoLinkResolver()
        resolver.replace(with: [
            GoLink(shortName: "abc", destinationURL: "https://fallback.example.com"),
            GoLink(shortName: "abc/def", destinationURL: "https://example.com/base")
        ])
        let router = GoLinkRouter(linkResolver: resolver, pasteResolver: PasteResolver())
        let request = Data("GET /abc/def/ghi HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 302 Found") == true)
        XCTAssertTrue(response?.contains("Location: https://example.com/base") == true)
    }

    func testRouterUsesPathTemplateForRemainingPath() {
        let resolver = GoLinkResolver()
        resolver.replace(with: [
            GoLink(shortName: "abc", destinationURL: "https://www.google.com/search?q={path}")
        ])
        let router = GoLinkRouter(linkResolver: resolver, pasteResolver: PasteResolver())
        let request = Data("GET /abc/hij?safe=off HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 302 Found") == true)
        XCTAssertTrue(response?.contains("Location: https://www.google.com/search?q=hij&safe=off") == true)
    }

    func testRouterRejectsUnsupportedMethods() {
        let router = GoLinkRouter(linkResolver: GoLinkResolver(), pasteResolver: PasteResolver())
        let request = Data("POST /docs HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "http"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 405 Method Not Allowed") == true)
        XCTAssertTrue(response?.contains("Allow: GET, HEAD") == true)
    }

    func testPasteInputPreservesBodyWhitespace() throws {
        XCTAssertEqual(PasteInput.normalizedTitle("  "), "Untitled Paste")
        XCTAssertEqual(try PasteInput.normalizedBody("  hello\n"), "  hello\n")
        XCTAssertThrowsError(try PasteInput.normalizedBody(" \n\t "))
    }

    @MainActor
    func testClipboardCaptureCreatesPasteWithReadableTitle() {
        let store = makePasteStore()
        let capturedAt = Date(timeIntervalSince1970: 1_000)

        let result = store.captureClipboard("  Deploy notes  \nship the app", capturedAt: capturedAt)

        guard case .created(let paste) = result else {
            return XCTFail("Expected a created paste")
        }
        XCTAssertEqual(store.pastes.count, 1)
        XCTAssertEqual(paste.title, "Deploy notes")
        XCTAssertEqual(paste.body, "  Deploy notes  \nship the app")
        XCTAssertEqual(paste.createdAt, capturedAt)
        XCTAssertEqual(store.pastes.first?.id, paste.id)
    }

    @MainActor
    func testClipboardCaptureRefreshesDuplicateContent() {
        let store = makePasteStore()
        let firstCapture = Date(timeIntervalSince1970: 1_000)
        let secondCapture = Date(timeIntervalSince1970: 2_000)

        _ = store.captureClipboard("same content", capturedAt: firstCapture)
        let originalID = store.pastes[0].id
        let result = store.captureClipboard("same content", capturedAt: secondCapture)

        guard case .refreshed(let paste) = result else {
            return XCTFail("Expected a refreshed paste")
        }
        XCTAssertEqual(store.pastes.count, 1)
        XCTAssertEqual(paste.id, originalID)
        XCTAssertEqual(store.pastes[0].id, originalID)
        XCTAssertEqual(store.pastes[0].createdAt, firstCapture)
        XCTAssertEqual(store.pastes[0].updatedAt, secondCapture)
    }

    @MainActor
    func testClipboardCaptureIgnoresEmptyText() {
        let store = makePasteStore()

        XCTAssertEqual(store.captureClipboard(" \n\t "), .ignored)
        XCTAssertTrue(store.pastes.isEmpty)
    }

    func testRouterServesPasteHTMLAndRawText() {
        let pasteResolver = PasteResolver()
        pasteResolver.replace(with: [
            PasteItem(id: "abc123", title: "Deploy Notes", body: "ship it\nnow")
        ])
        let router = GoLinkRouter(linkResolver: GoLinkResolver(), pasteResolver: pasteResolver)

        let pageRequest = Data("GET /paste/abc123 HTTP/1.1\r\nHost: go\r\n\r\n".utf8)
        let rawRequest = Data("GET /paste/abc123/raw HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let pageResponse = String(data: router.responseData(for: pageRequest, scheme: "https"), encoding: .utf8)
        let rawResponse = String(data: router.responseData(for: rawRequest, scheme: "https"), encoding: .utf8)

        XCTAssertTrue(pageResponse?.contains("HTTP/1.1 200 OK") == true)
        XCTAssertTrue(pageResponse?.contains("<h1>Deploy Notes</h1>") == true)
        XCTAssertTrue(pageResponse?.contains("<pre>ship it\nnow</pre>") == true)
        XCTAssertTrue(rawResponse?.contains("Content-Type: text/plain; charset=utf-8") == true)
        XCTAssertTrue(rawResponse?.hasSuffix("ship it\nnow") == true)
    }

    func testRouterListsPasteIndex() {
        let pasteResolver = PasteResolver()
        pasteResolver.replace(with: [
            PasteItem(id: "abc123", title: "Deploy Notes", body: "ship it")
        ])
        let router = GoLinkRouter(linkResolver: GoLinkResolver(), pasteResolver: pasteResolver)
        let request = Data("GET /paste HTTP/1.1\r\nHost: go\r\n\r\n".utf8)

        let response = String(data: router.responseData(for: request, scheme: "https"), encoding: .utf8)

        XCTAssertTrue(response?.contains("HTTP/1.1 200 OK") == true)
        XCTAssertTrue(response?.contains("https://go/paste/abc123") == true)
        XCTAssertTrue(response?.contains("Deploy Notes") == true)
    }

    @MainActor
    private func makePasteStore() -> PasteStore {
        let suiteName = "CommandShelfTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PasteStore(defaults: defaults, resolver: PasteResolver())
    }
}
