//
//  DeviceRegistrationProofs.swift
//  Cidaas
//

import Foundation

@available(iOS 14.0, *)
enum DeviceRegistrationProofs {

    struct PreparedVerificationRequest {
        let bodyParams: [String: Any]
        let extraHeaders: [String: String]
    }

    /// Uses the same DPoP/biometric keys as ``Cidaas/shared`` `useDpop` / `useBiometric`.
    static func prepareVerificationRequest(
        verificationURLString: String,
        sessionId: String,
        attestation: String,
        keyId: String,
        appVersion: String,
        platform: String
    ) throws -> PreparedVerificationRequest {
        let attestationValue = attestation.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyIdB64 = keyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let biometricReason = "Verify your identity to register this device"
        let extraHeaders = try CidaasHTTPProof.proofHeaders(
            urlString: verificationURLString,
            httpMethod: "POST",
            useDpop: true,
            useBiometric: true,
            biometricLocalizedReason: biometricReason
        )
        let thumbprints = try CidaasHTTPProof.jwkThumbprints(
            useDpop: true,
            useBiometric: true,
            biometricLocalizedReason: biometricReason
        )
        guard let dpopThumbprint = thumbprints.dpop, let biometricThumbprint = thumbprints.biometric else {
            throw NSError(
                domain: "CidaasDeviceRegistration",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "DPoP and biometric proofs are required for device registration"]
            )
        }

        let bodyParams: [String: Any] = [
            "session_id": sessionId.lowercased(),
            "attestation": attestationValue,
            "key_id": keyIdB64,
            "app_version": appVersion,
            "platform": platform,
            "dpop_jwk_thumbprint": dpopThumbprint,
            "biometric_jwk_thumbprint": biometricThumbprint,
        ]
        return PreparedVerificationRequest(bodyParams: bodyParams, extraHeaders: extraHeaders)
    }
}
