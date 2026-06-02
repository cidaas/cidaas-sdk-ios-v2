//
//  DeviceRegistrationAppAttest.swift
//  Cidaas
//

import CryptoKit
import DeviceCheck
import Foundation

/// Apple App Attest: create a device key and prove the app is genuine.
@available(iOS 14.0, *)
enum DeviceRegistrationAppAttest {

    static var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    static func unsupportedError() -> NSError {
        NSError(
            domain: "CidaasDeviceRegistration",
            code: 10,
            userInfo: [NSLocalizedDescriptionKey: "App Attest is not supported on this device or environment."]
        )
    }

    /// Creates a new App Attest key in the Secure Enclave.
    static func generateKeyId() async throws -> String {
        guard isSupported else { throw unsupportedError() }
        return try await DCAppAttestService.shared.generateKey()
    }

    /// Signs an attestation over SHA256 of the registration nonce.
    static func attest(keyId: String, challengeB64FromServer: String) async throws -> Data {
        guard let challengeData = DeviceRegistrationChallengeB64.decodeToData(challengeB64FromServer) else {
            throw NSError(
                domain: "CidaasDeviceRegistration",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "invalid challenge base64"]
            )
        }
        let hash = Data(SHA256.hash(data: challengeData))
        return try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash)
    }
}
