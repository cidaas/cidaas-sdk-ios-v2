import XCTest
@testable import Cidaas
import Alamofire

final class LimitedRedirectHandlerTests: XCTestCase {

    func testStopsAfterMaxRedirects() {
        let handler = LimitedRedirectHandler(maxRedirects: 2)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/a")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com/b"]
        )!
        let next = URLRequest(url: URL(string: "https://example.com/b")!)

        let exp1 = expectation(description: "follow-1")
        let exp2 = expectation(description: "follow-2")
        let exp3 = expectation(description: "stop-3")

        handler.task(URLSession.shared.dataTask(with: next), willBeRedirectedTo: next, for: response) { req in
            XCTAssertNotNil(req)
            exp1.fulfill()
        }
        handler.task(URLSession.shared.dataTask(with: next), willBeRedirectedTo: next, for: response) { req in
            XCTAssertNotNil(req)
            exp2.fulfill()
        }
        handler.task(URLSession.shared.dataTask(with: next), willBeRedirectedTo: next, for: response) { req in
            XCTAssertNil(req)
            exp3.fulfill()
        }

        wait(for: [exp1, exp2, exp3], timeout: 1)
    }

    func testDoesNotFollowCustomSchemeRedirect() {
        let handler = LimitedRedirectHandler(maxRedirects: 2)
        let response = HTTPURLResponse(
            url: URL(string: "https://login.example.com/tokenresp")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "myapp://callback?code=ABC"]
        )!
        let next = URLRequest(url: URL(string: "myapp://callback?code=ABC")!)
        let exp = expectation(description: "stop-custom-scheme")

        handler.task(URLSession.shared.dataTask(with: next), willBeRedirectedTo: next, for: response) { req in
            XCTAssertNil(req, "custom-scheme redirect_uri must not be followed")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)
    }

    func testIsHTTPURL() {
        XCTAssertTrue(LimitedRedirectHandler.isHTTPURL(URL(string: "https://a.com")))
        XCTAssertTrue(LimitedRedirectHandler.isHTTPURL(URL(string: "http://a.com")))
        XCTAssertFalse(LimitedRedirectHandler.isHTTPURL(URL(string: "myapp://callback")))
        XCTAssertFalse(LimitedRedirectHandler.isHTTPURL(nil))
    }
}
