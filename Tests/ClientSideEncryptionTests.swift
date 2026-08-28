//
//  ClientSideEncryptionTests.swift
//  CidaasTests
//

import XCTest
@testable import Cidaas

final class ClientSideEncryptionTests: XCTestCase {

    private static let encKeyA = "72375b3f-34ce-48ac-a77b-f2c775999eb6"
    private static let encKeyB = "a481611f-d215-42da-ba8f-e6254b9a7caa"

    private static let sampleJwks = """
    {"keys":[
      {"kid":"\(encKeyA)","kty":"EC","alg":"ECDH-ES","crv":"P-256","use":"enc",
       "x":"dR1oRGTcEuwdU_UgVW2mALpZAwId2ofyJeHTUEoyqZE",
       "y":"YxDzoQJo0WRcOG4_brxBF1CQhuYgt90zoLo041poWJ0"},
      {"kid":"\(encKeyB)","kty":"EC","alg":"ECDH-ES","crv":"P-256","use":"enc",
       "x":"MB05y_sq4O2UygZ2k9Z4oQS2deKu-4aLhf5q2O-XvKY",
       "y":"NNhl1SCJNrys41ZoAO3o_GPVWwRwhlQD-BEc6FnxBbs"},
      {"kid":"sig-key","kty":"RSA","alg":"RS256","use":"sig","n":"someting","e":"AQAB"}
    ]}
    """

    override func setUp() {
        super.setUp()
        Privacy.setEncryptionEnabled(false)
        JwksClient.clearCache()
        JwksClient.fetchOverride = nil
        JwksEncKeySelector.resetRandomSource()
    }

    override func tearDown() {
        Privacy.setEncryptionEnabled(false)
        JwksClient.clearCache()
        JwksClient.fetchOverride = nil
        JwksEncKeySelector.resetRandomSource()
        super.tearDown()
    }

    func testSelectEncryptionKey_picksAnyUseEncKey() throws {
        let key = try JwksEncKeySelector.selectEncryptionKey(from: Self.sampleJwks)
        XCTAssertNotNil(key)
        XCTAssertTrue(key?.kid == Self.encKeyA || key?.kid == Self.encKeyB)
    }

    func testSelectEncryptionKey_choosesRandomAmongMatchingKeys() throws {
        var call: UInt = 0
        JwksEncKeySelector.setRandomSource {
            defer { call += 1 }
            return call
        }
        let first = try JwksEncKeySelector.selectEncryptionKey(from: Self.sampleJwks)
        let second = try JwksEncKeySelector.selectEncryptionKey(from: Self.sampleJwks)
        XCTAssertEqual(first?.kid, Self.encKeyA)
        XCTAssertEqual(second?.kid, Self.encKeyB)
    }

    func testSelectEncryptionKey_rejectsMissingCrv() throws {
        let jwks = """
        {"keys":[{"kid":"no-crv","kty":"EC","alg":"ECDH-ES","use":"enc",
          "x":"dR1oRGTcEuwdU_UgVW2mALpZAwId2ofyJeHTUEoyqZE",
          "y":"YxDzoQJo0WRcOG4_brxBF1CQhuYgt90zoLo041poWJ0"}]}
        """
        let key = try JwksEncKeySelector.selectEncryptionKey(from: jwks)
        XCTAssertNil(key)
    }

    func testSelectEncryptionKey_rejectsWrongAlg() throws {
        let jwks = """
        {"keys":[{"kid":"rsa-oaep","kty":"EC","alg":"RSA-OAEP","crv":"P-256","use":"enc",
          "x":"dR1oRGTcEuwdU_UgVW2mALpZAwId2ofyJeHTUEoyqZE",
          "y":"YxDzoQJo0WRcOG4_brxBF1CQhuYgt90zoLo041poWJ0"}]}
        """
        let key = try JwksEncKeySelector.selectEncryptionKey(from: jwks)
        XCTAssertNil(key)
    }

    func testEncryptIfEnabled_disabledReturnsPlaintext() throws {
        Privacy.setEncryptionEnabled(false)
        let value = try ClientSideEncryption.encryptIfEnabled("secret")
        XCTAssertEqual(value, "secret")
    }

    func testEncryptIfEnabled_emptyUnchanged() throws {
        Privacy.setEncryptionEnabled(true)
        XCTAssertEqual(try ClientSideEncryption.encryptIfEnabled(""), "")
        XCTAssertNil(try ClientSideEncryption.encryptIfEnabled(nil))
    }

    func testEncryptIfEnabled_producesCompactJWEWithHeaders() throws {
        Privacy.setEncryptionEnabled(true)
        JwksClient.putCacheForTest(baseUrl: "https://tenant.example", jwksJson: Self.sampleJwks)

        let jwe = try ClientSideEncryption.encryptIfEnabled("password123", baseUrlOverride: "https://tenant.example")
        XCTAssertNotNil(jwe)
        let parts = jwe!.split(separator: ".", omittingEmptySubsequences: false)
        // ECDH-ES compact: protected..iv.ciphertext.tag → 5 segments with empty encrypted key
        XCTAssertEqual(parts.count, 5)
        XCTAssertTrue(parts[1].isEmpty)

        let headerJSON = try decodeBase64URL(String(parts[0]))
        let header = try JSONSerialization.jsonObject(with: headerJSON) as? [String: Any]
        XCTAssertEqual(header?["alg"] as? String, "ECDH-ES")
        XCTAssertEqual(header?["enc"] as? String, "A256GCM")
        XCTAssertNotNil(header?["kid"] as? String)
        XCTAssertNotNil(header?["iat"] as? Int ?? header?["iat"] as? Int64 ?? header?["iat"] as? NSNumber)
        XCTAssertNotNil(header?["jti"] as? String)
        XCTAssertNotNil(header?["epk"] as? [String: Any])
    }

    func testEncryptFields_uniqueJtiPerField() throws {
        Privacy.setEncryptionEnabled(true)
        JwksClient.putCacheForTest(baseUrl: "https://tenant.example", jwksJson: Self.sampleJwks)

        var body: [String: Any] = [
            "password": "same",
            "confirmPassword": "same"
        ]
        try ClientSideEncryption.encryptFieldsInBody(
            &body,
            fieldNames: ["password", "confirmPassword"],
            baseUrlOverride: "https://tenant.example"
        )

        let p1 = body["password"] as? String
        let p2 = body["confirmPassword"] as? String
        XCTAssertNotNil(p1)
        XCTAssertNotNil(p2)
        XCTAssertNotEqual(p1, p2)

        let jti1 = try jtiFromJWE(p1!)
        let jti2 = try jtiFromJWE(p2!)
        XCTAssertNotEqual(jti1, jti2)
    }

    func testShouldEncryptVerificationPassCode() {
        XCTAssertTrue(ClientSideEncryption.shouldEncryptVerificationPassCode("BACKUPCODE"))
        XCTAssertTrue(ClientSideEncryption.shouldEncryptVerificationPassCode("pattern"))
        XCTAssertFalse(ClientSideEncryption.shouldEncryptVerificationPassCode("EMAIL"))
        XCTAssertFalse(ClientSideEncryption.shouldEncryptVerificationPassCode("SMS"))
        XCTAssertFalse(ClientSideEncryption.shouldEncryptVerificationPassCode("TOTP"))
        XCTAssertFalse(ClientSideEncryption.shouldEncryptVerificationPassCode(nil))
    }

    func testEncryptPassCodeIfEnabled_skipsEmailOTP() throws {
        Privacy.setEncryptionEnabled(true)
        JwksClient.putCacheForTest(baseUrl: "https://tenant.example", jwksJson: Self.sampleJwks)
        let otp = try ClientSideEncryption.encryptPassCodeIfEnabled("123456", verificationType: "EMAIL")
        XCTAssertEqual(otp, "123456")
    }

    func testEncryptPassCodeIfEnabled_encryptsBackupCode() throws {
        Privacy.setEncryptionEnabled(true)
        JwksClient.putCacheForTest(baseUrl: "https://tenant.example", jwksJson: Self.sampleJwks)
        let encrypted = try ClientSideEncryption.encryptPassCodeIfEnabled(
            "ABCD-1234",
            verificationType: "BACKUPCODE",
            baseUrlOverride: "https://tenant.example"
        )
        XCTAssertNotEqual(encrypted, "ABCD-1234")
        XCTAssertTrue(encrypted?.contains(".") == true)
    }

    func testEncryptIfEnabled_failsClosedWithoutJwksOnMain() {
        Privacy.setEncryptionEnabled(true)
        JwksClient.clearCache()

        // Run on main (XCTest main) with empty cache → fail closed
        XCTAssertThrowsError(
            try ClientSideEncryption.encryptIfEnabled("secret", baseUrlOverride: "https://tenant.example")
        ) { error in
            let message = error.localizedDescription
            XCTAssertTrue(
                message.contains("Client-side encryption failed") || message.contains("JWKS"),
                "Unexpected error: \(message)"
            )
        }
    }

    func testApplyVerificationEncryption_passwordPath() throws {
        Privacy.setEncryptionEnabled(true)
        JwksClient.putCacheForTest(baseUrl: "https://tenant.example", jwksJson: Self.sampleJwks)

        var body: [String: Any] = ["password": "hunter2", "pass_code": ""]
        try ClientSideEncryption.applyVerificationEncryption(
            &body,
            verificationType: "PASSWORD",
            baseUrlOverride: "https://tenant.example"
        )
        XCTAssertNotEqual(body["password"] as? String, "hunter2")
    }

    // MARK: - Helpers

    private func jtiFromJWE(_ jwe: String) throws -> String {
        let parts = jwe.split(separator: ".", omittingEmptySubsequences: false)
        let headerJSON = try decodeBase64URL(String(parts[0]))
        let header = try JSONSerialization.jsonObject(with: headerJSON) as? [String: Any]
        return header?["jti"] as? String ?? ""
    }

    private func decodeBase64URL(_ value: String) throws -> Data {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad base64url"])
        }
        return data
    }
}
