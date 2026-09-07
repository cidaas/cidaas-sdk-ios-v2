import XCTest
@testable import Cidaas

final class InitLoginLocationParserTests: XCTestCase {

    func testRedirectURIWithCodeReturnsAuthorizationCode() {
        let outcome = InitLoginLocationParser.parse(
            location: "myapp://callback?code=AUTHCODE&state=xyz",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .authorizationCode("AUTHCODE"))
    }

    func testRedirectURIPrefixMatchIsCaseInsensitive() {
        let outcome = InitLoginLocationParser.parse(
            location: "MyApp://Callback?code=C1",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .authorizationCode("C1"))
    }

    func testRequestIdWithoutRedirectReturnsLoginRequired() {
        let outcome = InitLoginLocationParser.parse(
            location: "https://login.example.com/login?request_id=req-123&view=login",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .loginRequired(requestId: "req-123"))
    }

    func testRequestIdCamelCaseAlsoAccepted() {
        let outcome = InitLoginLocationParser.parse(
            location: "https://login.example.com/?requestId=req-456",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .loginRequired(requestId: "req-456"))
    }

    func testTrackIdPreferredOverRequestId() {
        let location =
            "https://app.example/callback?iss=https%3A%2F%2Fkube-nightlybuild-dev.cidaas.de"
            + "&track_id=8700ed5c-a957-4029-9b8e-5e62a726956e"
            + "&sub=e52d2e60-3703-4e52-9fc5-45534bd584a9"
            + "&q=e52d2e60-3703-4e52-9fc5-45534bd584a9"
            + "&requestId=89c5a66c-6841-4e3d-a201-9b1893b27c9d"
            + "&hint=stepup-required"
        let outcome = InitLoginLocationParser.parse(
            location: location,
            redirectURI: "https://other-app/callback"
        )
        XCTAssertEqual(
            outcome,
            .preloginTrack(
                trackId: "8700ed5c-a957-4029-9b8e-5e62a726956e",
                requestId: "89c5a66c-6841-4e3d-a201-9b1893b27c9d",
                sub: "e52d2e60-3703-4e52-9fc5-45534bd584a9"
            )
        )
    }

    func testTrackIdOnRedirectURIWithoutCode() {
        let outcome = InitLoginLocationParser.parse(
            location: "myapp://callback?track_id=tid-1&requestId=rid-1&sub=sub-1&hint=stepup-required",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(
            outcome,
            .preloginTrack(trackId: "tid-1", requestId: "rid-1", sub: "sub-1")
        )
    }

    func testNeitherRedirectNorRequestIdIsUnrecognized() {
        let outcome = InitLoginLocationParser.parse(
            location: "https://login.example.com/error",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .unrecognized)
    }

    func testRedirectWithoutCodeIsUnrecognized() {
        let outcome = InitLoginLocationParser.parse(
            location: "myapp://callback?state=only",
            redirectURI: "myapp://callback"
        )
        XCTAssertEqual(outcome, .unrecognized)
    }
}

final class PreloginMetadataDecodingTests: XCTestCase {

    func testDecodesMfaRequiredSample() throws {
        let json = """
        {
            "success": true,
            "status": 200,
            "data": {
                "logged_in": false,
                "validation_type": "mfa_required",
                "meta_data": {
                    "amr_values": ["10", "101", "108"],
                    "acr_values": "cidaas:acr:strong",
                    "last_auth_time": "2026-09-04T05:40:43Z",
                    "terminal_error": "stepup-required",
                    "userConfiguredMethods": [
                        {
                            "type": "TOUCHID",
                            "mediums": [
                                { "id": "1043ea4b-82e4-4544-9e81-d5ec24966948", "key_name": "" }
                            ]
                        }
                    ]
                },
                "used": false
            }
        }
        """
        let decoded = try JSONDecoder().decode(
            PreloginMetadataResponse.self,
            from: Data(json.utf8)
        )
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data.validation_type, "mfa_required")
        XCTAssertEqual(decoded.data.meta_data.userConfiguredMethods.count, 1)
        XCTAssertEqual(decoded.data.meta_data.userConfiguredMethods[0].type, "TOUCHID")
        XCTAssertEqual(
            decoded.data.meta_data.userConfiguredMethods[0].mediums[0].id,
            "1043ea4b-82e4-4544-9e81-d5ec24966948"
        )
    }
}

final class CidaasRequestCookiesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CidaasSessionCookies.clear()
    }

    override func tearDown() {
        CidaasSessionCookies.clear()
        super.tearDown()
    }

    func testMergeInjectsDeviceIdAsCidaasDr() {
        let merged = CidaasSessionCookies.mergeIntoCookieHeader(nil, deviceId: "DEV1")
        XCTAssertEqual(merged, "cidaas_dr=DEV1")
    }

    func testMergeInjectsAllThreeWhenPresent() {
        CidaasSessionCookies.persist(sid: "S", sso: "O")
        let merged = CidaasSessionCookies.mergeIntoCookieHeader(nil, deviceId: "DEV1")
        XCTAssertEqual(merged, "cidaas_dr=DEV1; cidaas_sid=S; cidaas_sso=O")
    }

    func testMergeOmitsMissingCookies() {
        CidaasSessionCookies.persist(sid: "S", sso: nil)
        let merged = CidaasSessionCookies.mergeIntoCookieHeader(nil, deviceId: "")
        XCTAssertEqual(merged, "cidaas_sid=S")
    }

    func testMergeNilWhenNothingPresent() {
        XCTAssertNil(CidaasSessionCookies.mergeIntoCookieHeader(nil, deviceId: nil))
        XCTAssertNil(CidaasSessionCookies.mergeIntoCookieHeader(nil, deviceId: ""))
    }
}
