//
//  DeviceRegistrationProofs.swift
//  Cidaas
//

import Foundation

enum DeviceRegistrationProofs {

    struct PreparedVerificationRequest {
        let bodyParams: [String: Any]
    }

    /// Builds the verify body with a `dpop+jwt`.
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
        let material = try CidaasHTTPProof.loadDeviceRegistrationMaterial()
        let attestationJWT = try material.attestationJWT(
            rawAttestation: attestationValue,
            verificationURLString: verificationURLString,
            httpMethod: "POST"
        )

        let bodyParams: [String: Any] = [
            "session_id": sessionId.lowercased(),
            "attestation": attestationJWT,
            "key_id": keyIdB64,
            "app_version": appVersion,
            "platform": platform,
            "dpop_jwk_thumbprint": material.dpopThumbprint,
            "biometric_jwk_thumbprint": material.biometricThumbprint,
        ]
        return PreparedVerificationRequest(bodyParams: bodyParams)
    }
}
