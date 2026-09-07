import XCTest
@testable import Cidaas

final class ContinueLoginChallengeParserTests: XCTestCase {

    func testParsesMfaRequiredSample() {
        let json = """
        {
          "data" : {
            "client_id" : "f04f0c45-68ff-4c64-9422-a2796b6aef6b",
            "error" : "mfa_required",
            "q" : "10c2bbc0-7524-4548-ac9f-3b1a73825100",
            "requestId" : "c1012190-86d0-4b2e-9058-65a03b58ad4f",
            "sub" : "10c2bbc0-7524-4548-ac9f-3b1a73825100",
            "suggested_url" : "https://example.com/identity/mfa_required?track_id=3eb5179b-318c-4ede-96d6-ff76e07c6e2a",
            "track_id" : "3eb5179b-318c-4ede-96d6-ff76e07c6e2a",
            "trackId" : "3eb5179b-318c-4ede-96d6-ff76e07c6e2a",
            "view_type" : "login",
            "viewtype" : "login"
          },
          "response_type" : "json",
          "status" : 417,
          "success" : true
        }
        """
        let challenge = ContinueLoginChallengeParser.parse(json)
        XCTAssertNotNil(challenge)
        XCTAssertTrue(challenge!.isMFARequired)
        XCTAssertEqual(challenge!.trackId, "3eb5179b-318c-4ede-96d6-ff76e07c6e2a")
        XCTAssertEqual(challenge!.requestId, "c1012190-86d0-4b2e-9058-65a03b58ad4f")
        XCTAssertEqual(challenge!.sub, "10c2bbc0-7524-4548-ac9f-3b1a73825100")
        XCTAssertEqual(challenge!.error, "mfa_required")
    }

    func testNonMfaErrorIsNotMFARequired() {
        let json = """
        { "success": true, "status": 417, "data": { "error": "consent_required", "track_id": "t1" } }
        """
        let challenge = ContinueLoginChallengeParser.parse(json)
        XCTAssertNotNil(challenge)
        XCTAssertFalse(challenge!.isMFARequired)
    }
}
