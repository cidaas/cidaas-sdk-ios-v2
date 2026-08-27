//
//  CidaasDevice.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Device registration entry point.
    public func device() -> CidaasDevice {
        CidaasDevice()
    }
}

/// Registers the device via initiate → verify.
/// App Attest / App Check needs iOS 14+; without platform attestation it works on older OS versions.
public final class CidaasDevice {

    /// Host-app hook that returns a Firebase App Check token when initiate `provider` is `firebase`.
    public static var firebaseAppCheckTokenProvider: (@Sendable () async throws -> String)? {
        get {
            if #available(iOS 14.0, *) {
                return DeviceRegistrationFirebaseAppCheck.tokenProvider
            }
            return nil
        }
        set {
            if #available(iOS 14.0, *) {
                DeviceRegistrationFirebaseAppCheck.tokenProvider = newValue
            }
        }
    }

    fileprivate init() {}

    /// Runs initiate → verify.
    ///
    /// - Parameters:
    ///   - clientId: OAuth client id.
    ///   - pushId: FCM token; required when `includePlatformAttestation` is `true`.
    ///   - includePlatformAttestation: Collects App Attest / App Check when true; otherwise DPoP + biometric proof only.
    ///   - completion: Registered `device_id`, or an error.
    public func registerDevice(
        clientId: String,
        pushId: String = "",
        includePlatformAttestation: Bool = false,
        completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
    ) {
        if includePlatformAttestation {
            guard #available(iOS 14.0, *) else {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: "Platform attestation requires iOS 14+.",
                    statusCode: 400
                )
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
                return
            }
        }

        startRegistration(
            clientId: clientId,
            pushId: pushId,
            includePlatformAttestation: includePlatformAttestation
        ) { initiateResult in
            switch initiateResult {
            case .failure(error: let error):
                // 409 on initiate = already registered
                if let alreadyRegistered = self.alreadyRegisteredResult(error: error) {
                    self.persistDeviceId(alreadyRegistered.deviceId)
                    completion(.success(result: alreadyRegistered))
                } else {
                    completion(.failure(error: error))
                }
            case .success(result: let initiate):
                self.completeRegistration(
                    initiateResult: initiate,
                    includePlatformAttestation: includePlatformAttestation,
                    completion: completion
                )
            }
        }
    }

    /// Async convenience over the completion-based `registerDevice`.
    @available(iOS 13.0, *)
    public func registerDevice(
        clientId: String,
        pushId: String = "",
        includePlatformAttestation: Bool = false
    ) async throws -> DeviceRegistrationVerifyResult {
        try await withCheckedThrowingContinuation { continuation in
            registerDevice(
                clientId: clientId,
                pushId: pushId,
                includePlatformAttestation: includePlatformAttestation
            ) { result in
                switch result {
                case .success(result: let value):
                    continuation.resume(returning: value)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startRegistration(
        clientId: String,
        pushId: String,
        includePlatformAttestation: Bool,
        completion: @escaping (Result<DeviceRegistrationInitiateResult>) -> Void
    ) {
        let trimmedClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientId.isEmpty else {
            let err = WebAuthError.shared.propertyMissingException()
            err.errorMessage = "client_id is required for device registration."
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        let trimmedPushId = pushId.trimmingCharacters(in: .whitespacesAndNewlines)
        if includePlatformAttestation {
            guard !trimmedPushId.isEmpty else {
                let err = WebAuthError.shared.propertyMissingException()
                err.errorMessage = "push_id (FCM) is required when includePlatformAttestation is true."
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
                return
            }
            DBHelper.shared.setFCM(fcmToken: trimmedPushId)
        } else if !trimmedPushId.isEmpty {
            // Cache locally only; omitted from initiate when includePlatformAttestation is false.
            DBHelper.shared.setFCM(fcmToken: trimmedPushId)
        }

        let deviceId = SDKDeviceIdResolver.resolve()
        guard !deviceId.isEmpty else {
            let err = WebAuthError.shared.propertyMissingException()
            err.errorMessage = "device_id could not be resolved for device registration."
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        guard let props = DBHelper.shared.getPropertyFile(), let baseURL = props["DomainURL"], !baseURL.isEmpty else {
            let err = WebAuthError.shared.fileNotFoundException()
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        let urlString = baseURL + VerificationURLHelper.shared.getDeviceRegistrationInitiationURL()
        var bodyParams: [String: Any] = [
            "client_id": trimmedClientId,
            "device_id": deviceId,
            "platform": "ios"
        ]
        // push_id is sent only when the host opts into the platform-attestation path.
        if includePlatformAttestation {
            bodyParams["push_id"] = trimmedPushId
        }

        SessionManager.shared.startSession(url: urlString, method: .post, parameters: bodyParams) { responseString, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
                return
            }
            guard let responseString, let data = responseString.data(using: .utf8) else {
                let err = WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Empty response", statusCode: 400)
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(DeviceRegistrationInitiateAPIResponse.self, from: data)
                guard decoded.success, let payload = decoded.data else {
                    let err = WebAuthError.shared.serviceFailureException(
                        errorCode: Int(decoded.status),
                        errorMessage: "Device registration initiation was not successful.",
                        statusCode: Int(decoded.status)
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error: err))
                    }
                    return
                }
                let result = DeviceRegistrationInitiateResult(
                    sessionId: payload.session_id,
                    nonce: payload.nonce,
                    provider: DeviceRegistrationProvider(apiValue: payload.provider)
                )
                DispatchQueue.main.async {
                    completion(.success(result: result))
                }
            } catch {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: error.localizedDescription,
                    statusCode: 400
                )
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
            }
        }
    }

    private func completeRegistration(
        initiateResult: DeviceRegistrationInitiateResult,
        includePlatformAttestation: Bool,
        completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
    ) {
        let sessionId = initiateResult.sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonce = initiateResult.nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sessionId.isEmpty, UUID(uuidString: sessionId) != nil else {
            let err = WebAuthError.shared.propertyMissingException()
            err.errorMessage = "sessionId must be a non-empty UUID (session_id)."
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }
        guard !nonce.isEmpty else {
            let err = WebAuthError.shared.propertyMissingException()
            err.errorMessage = "nonce is required for device registration verification."
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        guard let props = DBHelper.shared.getPropertyFile(), let baseURL = props["DomainURL"], !baseURL.isEmpty else {
            let err = WebAuthError.shared.fileNotFoundException()
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        let urlString = baseURL + VerificationURLHelper.shared.getDeviceRegistrationVerificationURL()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        if initiateResult.provider.hasPlatformAttestationProvider {
            guard includePlatformAttestation else {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: "Device registration requires platform attestation. Pass includePlatformAttestation: true.",
                    statusCode: 400
                )
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
                return
            }
            guard #available(iOS 14.0, *) else {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: "Platform attestation requires iOS 14+.",
                    statusCode: 400
                )
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
                return
            }
            Task {
                do {
                    let attestation: String
                    let keyId: String
                    switch initiateResult.provider {
                    case .apple:
                        guard DeviceRegistrationAppAttest.isSupported else {
                            let err = WebAuthError.shared.serviceFailureException(
                                errorCode: 400,
                                errorMessage: DeviceRegistrationAppAttest.unsupportedError().localizedDescription,
                                statusCode: 400
                            )
                            DispatchQueue.main.async {
                                completion(.failure(error: err))
                            }
                            return
                        }
                        let appAttestKeyId = try await DeviceRegistrationAppAttest.generateKeyId()
                        let attestationObject = try await DeviceRegistrationAppAttest.attest(
                            keyId: appAttestKeyId,
                            challengeB64FromServer: nonce
                        )
                        attestation = attestationObject.base64EncodedString()
                        keyId = try DeviceRegistrationChallengeB64.standardBase64KeyId(fromAppleKeyId: appAttestKeyId)
                    case .firebase:
                        attestation = try await DeviceRegistrationFirebaseAppCheck.fetchAttestationToken()
                        keyId = "firebase"
                    case .unknown(let value):
                        assertionFailure("Unexpected unknown provider while collecting platform attestation: \(value)")
                        let err = WebAuthError.shared.serviceFailureException(
                            errorCode: 400,
                            errorMessage: "Unsupported device registration provider: \(value)",
                            statusCode: 400
                        )
                        DispatchQueue.main.async {
                            completion(.failure(error: err))
                        }
                        return
                    }
                    self.submitVerification(
                        urlString: urlString,
                        sessionId: sessionId,
                        attestation: attestation,
                        keyId: keyId,
                        appVersion: appVersion,
                        completion: completion
                    )
                } catch {
                    let err = WebAuthError.shared.serviceFailureException(
                        errorCode: 400,
                        errorMessage: error.localizedDescription,
                        statusCode: 400
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error: err))
                    }
                }
            }
            return
        }

        if case .unknown(let value) = initiateResult.provider, !value.isEmpty {
            let err = WebAuthError.shared.serviceFailureException(
                errorCode: 400,
                errorMessage: "Unsupported device registration provider: \(value)",
                statusCode: 400
            )
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        // No platform provider: DPoP + biometric only.
        DispatchQueue.global(qos: .userInitiated).async {
            self.submitVerification(
                urlString: urlString,
                sessionId: sessionId,
                attestation: "",
                keyId: "",
                appVersion: appVersion,
                completion: completion
            )
        }
    }

    private func submitVerification(
        urlString: String,
        sessionId: String,
        attestation: String,
        keyId: String,
        appVersion: String,
        completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
    ) {
        do {
            let prepared = try DeviceRegistrationProofs.prepareVerificationRequest(
                verificationURLString: urlString,
                sessionId: sessionId,
                attestation: attestation,
                keyId: keyId,
                appVersion: appVersion,
                platform: "ios"
            )
            SessionManager.shared.startSession(
                url: urlString,
                method: .post,
                parameters: prepared.bodyParams
            ) { responseString, error in
                if let error {
                    DispatchQueue.main.async {
                        completion(.failure(error: error))
                    }
                    return
                }
                guard let responseString, let data = responseString.data(using: .utf8) else {
                    let err = WebAuthError.shared.serviceFailureException(
                        errorCode: 400,
                        errorMessage: "Empty response",
                        statusCode: 400
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error: err))
                    }
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(DeviceRegistrationVerifyAPIResponse.self, from: data)
                    guard decoded.success, let payload = decoded.data else {
                        let err = WebAuthError.shared.serviceFailureException(
                            errorCode: Int(decoded.status),
                            errorMessage: "Device registration verification was not successful.",
                            statusCode: Int(decoded.status)
                        )
                        DispatchQueue.main.async {
                            completion(.failure(error: err))
                        }
                        return
                    }
                    let deviceId = payload.device_id.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !deviceId.isEmpty else {
                        let err = WebAuthError.shared.serviceFailureException(
                            errorCode: 400,
                            errorMessage: "Verify response missing device_id",
                            statusCode: 400
                        )
                        DispatchQueue.main.async {
                            completion(.failure(error: err))
                        }
                        return
                    }
                    self.persistDeviceId(deviceId)
                    DispatchQueue.main.async {
                        completion(.success(result: DeviceRegistrationVerifyResult(deviceId: deviceId)))
                    }
                } catch {
                    let err = WebAuthError.shared.serviceFailureException(
                        errorCode: 400,
                        errorMessage: error.localizedDescription,
                        statusCode: 400
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error: err))
                    }
                }
            }
        } catch {
            let err = WebAuthError.shared.serviceFailureException(
                errorCode: 400,
                errorMessage: error.localizedDescription,
                statusCode: 400
            )
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
        }
    }

    private func persistDeviceId(_ deviceId: String) {
        SDKDeviceIdResolver.persist(deviceId)
        SessionManager.shared.refreshDeviceIdFromStorage()
        Cidaas.shared.deviceInfo.deviceId = SessionManager.shared.deviceInfo.deviceId
        Cidaas.shared.isDeviceRegistrationCompleted = true
    }

    /// Maps HTTP 409 (already registered) to a successful local `device_id` when possible.
    private func alreadyRegisteredResult(error: WebAuthError?) -> DeviceRegistrationVerifyResult? {
        guard error?.statusCode == 409 else { return nil }
        let resolved = SDKDeviceIdResolver.resolve()
        guard !resolved.isEmpty else { return nil }
        return DeviceRegistrationVerifyResult(deviceId: resolved)
    }
}
