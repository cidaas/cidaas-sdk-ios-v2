import XCTest
@testable import Cidaas

final class CidaasSessionCookiesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CidaasSessionCookies.clear()
    }

    override func tearDown() {
        CidaasSessionCookies.clear()
        super.tearDown()
    }

    func testPersistStoresSidAndSsoInKeychain() {
        CidaasSessionCookies.persist(sid: "sid-value", sso: "sso-value")
        XCTAssertEqual(CidaasSessionCookies.sid, "sid-value")
        XCTAssertEqual(CidaasSessionCookies.sso, "sso-value")
    }

    func testPersistPartialLeavesOtherCookieUnchanged() {
        CidaasSessionCookies.persist(sid: "sid-1", sso: "sso-1")
        CidaasSessionCookies.persist(sid: "sid-2", sso: nil)
        XCTAssertEqual(CidaasSessionCookies.sid, "sid-2")
        XCTAssertEqual(CidaasSessionCookies.sso, "sso-1")
    }

    func testPersistFromSetCookieHeaders() {
        let headers: [AnyHashable: Any] = [
            "Set-Cookie": "cidaas_sid=abc123; Path=/; HttpOnly, cidaas_sso=xyz789; Path=/; HttpOnly"
        ]
        CidaasSessionCookies.persist(fromResponseHeaders: headers)
        XCTAssertEqual(CidaasSessionCookies.sid, "abc123")
        XCTAssertEqual(CidaasSessionCookies.sso, "xyz789")
    }

    func testMergeCookieHeaderWithCidaasDr() {
        CidaasSessionCookies.persist(sid: "S", sso: "O")
        let merged = CidaasSessionCookies.mergeIntoCookieHeader("cidaas_dr=DEVICE")
        XCTAssertEqual(merged, "cidaas_dr=DEVICE; cidaas_sid=S; cidaas_sso=O")
    }

    func testMergeReplacesExistingSidSsoWithoutDuplicating() {
        CidaasSessionCookies.persist(sid: "new-sid", sso: "new-sso")
        let merged = CidaasSessionCookies.mergeIntoCookieHeader(
            "cidaas_dr=DEVICE; cidaas_sid=old; cidaas_sso=old"
        )
        XCTAssertEqual(merged, "cidaas_dr=DEVICE; cidaas_sid=new-sid; cidaas_sso=new-sso")
    }

    func testMergeEmptyStoreReturnsExistingOrNil() {
        XCTAssertNil(CidaasSessionCookies.mergeIntoCookieHeader(nil))
        XCTAssertEqual(
            CidaasSessionCookies.mergeIntoCookieHeader("cidaas_dr=DEVICE"),
            "cidaas_dr=DEVICE"
        )
    }

    func testClearRemovesKeychainValues() {
        CidaasSessionCookies.persist(sid: "sid", sso: "sso")
        CidaasSessionCookies.clear()
        XCTAssertEqual(CidaasSessionCookies.sid, "")
        XCTAssertEqual(CidaasSessionCookies.sso, "")
        XCTAssertNil(CidaasSessionCookies.mergeIntoCookieHeader(nil))
    }
}
