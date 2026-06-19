//
//  CidaasDevice.swift
//  Cidaas
//

import Foundation
import Alamofire

extension Cidaas {

    /// Device registration entry point (App Attest or Firebase App Check + DPoP-bound attestation JWT). iOS 14+. Call on ``Cidaas/shared``, e.g. `Cidaas.shared.device()`.
    public func device() -> CidaasDevice {
        CidaasDevice()
    }
}

/// Registers this iOS device using App Attest or Firebase App Check (per initiate `provider`).
/// Verify sends a `dpop+jwt` in `attestation` (platform attestation + biometric public key DER in the payload).
public final class CidaasDevice {

    /// Optional hook to supply a Firebase App Check JWT when `provider` is `firebase`.
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

    private static let logCategory = "cidaas-sdk-device-log"
    private static let initiationPath = "/devices/registration/initiation"
    private static let verificationPath = "/devices/registration/verification"

    /// Always logs initiate/verify API responses to the Xcode console.
    private func logDeviceRegistration(_ phase: String, response: String? = nil, error: Error? = nil) {
        let endpoint = phase == "initiate" ? Self.initiationPath : Self.verificationPath
        if let response, !response.isEmpty {
            logw("[CidaasDevice] POST \(endpoint) response: \(response)", cname: Self.logCategory)
        } else if response != nil {
            logw("[CidaasDevice] POST \(endpoint) response: (empty body)", cname: Self.logCategory)
        }
        if let error {
            let errorText: String
            if let webAuth = error as? WebAuthError {
                errorText = "\(webAuth.errorMessage) (status=\(webAuth.statusCode))"
            } else {
                errorText = error.localizedDescription
            }
            logw("[CidaasDevice] POST \(endpoint) error: \(errorText)", cname: Self.logCategory)
        }
    }

    @available(iOS 14.0, *)
    private func appAttestUnavailableError() -> WebAuthError {
        let err = WebAuthError.shared.serviceFailureException(
            errorCode: 400,
            errorMessage: DeviceRegistrationAppAttest.unsupportedError().localizedDescription,
            statusCode: 400
        )
        return err
    }

    /// Full flow: request session + nonce, then attest the app and complete registration.
    @available(iOS 14.0, *)
    public func registerDevice(
        clientId: String,
        pushId: String,
        completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
    ) {
        startRegistration(clientId: clientId, pushId: pushId) { initiateResult in
            switch initiateResult {
            case .failure(error: let error):
                // Backend returns HTTP 409 on /initiation when the device is already registered.
                if let alreadyRegistered = self.alreadyRegisteredResult(responseString: nil, error: error) {
                    self.persistDeviceId(alreadyRegistered.deviceId)
                    self.logDeviceRegistration("initiate", error: error)
                    logw("[CidaasDevice] POST \(Self.initiationPath) treated HTTP 409 as already registered (deviceId=\(alreadyRegistered.deviceId))", cname: Self.logCategory)
                    completion(.success(result: alreadyRegistered))
                } else {
                    completion(.failure(error: error))
                }
            case .success(result: let initiate):
                self.completeRegistration(initiateResult: initiate, completion: completion)
            }
        }
    }

    /// Async convenience over the completion-based `registerDevice`.
    @available(iOS 14.0, *)
    public func registerDevice(clientId: String, pushId: String) async throws -> DeviceRegistrationVerifyResult {
        try await withCheckedThrowingContinuation { continuation in
            registerDevice(clientId: clientId, pushId: pushId) { result in
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
        guard !trimmedPushId.isEmpty else {
            let err = WebAuthError.shared.propertyMissingException()
            err.errorMessage = "push_id (FCM) is required for device registration."
            DispatchQueue.main.async {
                completion(.failure(error: err))
            }
            return
        }

        DBHelper.shared.setFCM(fcmToken: trimmedPushId)

        let deviceId = SDKDeviceIdResolver.resolve().trimmingCharacters(in: .whitespacesAndNewlines)
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
        let bodyParams: [String: Any] = [
            "push_id": trimmedPushId,
            "client_id": trimmedClientId,
            "device_id": deviceId,
            "platform": "ios"
        ]

        SessionManager.shared.startSession(url: urlString, method: .post, parameters: bodyParams) { responseString, error in
            if let error {
                self.logDeviceRegistration("initiate", response: responseString, error: error)
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
                return
            }
            guard let responseString, let data = responseString.data(using: .utf8) else {
                let err = WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Empty response", statusCode: 400)
                self.logDeviceRegistration("initiate", error: err)
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
                    self.logDeviceRegistration("initiate", response: responseString, error: err)
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
                self.logDeviceRegistration("initiate", response: responseString)
                DispatchQueue.main.async {
                    completion(.success(result: result))
                }
            } catch {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: error.localizedDescription,
                    statusCode: 400
                )
                self.logDeviceRegistration("initiate", response: responseString, error: err)
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
            }
        }
    }

    @available(iOS 14.0, *)
    private func completeRegistration(
        initiateResult: DeviceRegistrationInitiateResult,
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

        Task {
            do {
                let attestation: String
                let keyId: String

                switch initiateResult.provider {
                case .apple:
                    guard DeviceRegistrationAppAttest.isSupported else {
                        let err = appAttestUnavailableError()
                        self.logDeviceRegistration("verify", error: err)
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
                    let err = WebAuthError.shared.serviceFailureException(
                        errorCode: 400,
                        errorMessage: "Unsupported device registration provider: \(value)",
                        statusCode: 400
                    )
                    self.logDeviceRegistration("verify", error: err)
                    DispatchQueue.main.async {
                        completion(.failure(error: err))
                    }
                    return
                }

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
                        if let alreadyRegistered = self.alreadyRegisteredResult(
                            responseString: responseString,
                            error: error
                        ) {
                            self.persistDeviceId(alreadyRegistered.deviceId)
                            self.logDeviceRegistration("verify", response: responseString)
                            DispatchQueue.main.async {
                                completion(.success(result: alreadyRegistered))
                            }
                            return
                        }
                        self.logDeviceRegistration("verify", response: responseString, error: error)
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
                        self.logDeviceRegistration("verify", error: err)
                        DispatchQueue.main.async {
                            completion(.failure(error: err))
                        }
                        return
                    }
                    do {
                        let decoded = try JSONDecoder().decode(DeviceRegistrationVerifyAPIResponse.self, from: data)
                        if decoded.status == 409 {
                            if let alreadyRegistered = self.alreadyRegisteredResult(
                                responseString: responseString,
                                error: nil,
                                decoded: decoded
                            ) {
                                self.persistDeviceId(alreadyRegistered.deviceId)
                                self.logDeviceRegistration("verify", response: responseString)
                                DispatchQueue.main.async {
                                    completion(.success(result: alreadyRegistered))
                                }
                                return
                            }
                        }
                        guard decoded.success, let payload = decoded.data else {
                            let err = WebAuthError.shared.serviceFailureException(
                                errorCode: Int(decoded.status),
                                errorMessage: "Device registration verification was not successful.",
                                statusCode: Int(decoded.status)
                            )
                            self.logDeviceRegistration("verify", response: responseString, error: err)
                            DispatchQueue.main.async {
                                completion(.failure(error: err))
                            }
                            return
                        }
                        let deviceId = payload.device_id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        self.persistDeviceId(deviceId)
                        self.logDeviceRegistration("verify", response: responseString)
                        DispatchQueue.main.async {
                            completion(.success(result: DeviceRegistrationVerifyResult(deviceId: deviceId)))
                        }
                    } catch {
                        let err = WebAuthError.shared.serviceFailureException(
                            errorCode: 400,
                            errorMessage: error.localizedDescription,
                            statusCode: 400
                        )
                        self.logDeviceRegistration("verify", response: responseString, error: err)
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
                self.logDeviceRegistration("verify", error: err)
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
            }
        }
    }

    private func persistDeviceId(_ deviceId: String) {
        var info = DBHelper.shared.getDeviceInfo()
        info.deviceId = deviceId
        DBHelper.shared.setDeviceInfo(deviceInfo: info)
    }

    /// HTTP 409 means the device is already registered — treat as success for the app flow.
    /// Backend returns 409 on `/initiation` when a device verification record exists; `/verification` does not emit 409 today.
    private func alreadyRegisteredResult(
        responseString: String?,
        error: WebAuthError?,
        decoded: DeviceRegistrationVerifyAPIResponse? = nil
    ) -> DeviceRegistrationVerifyResult? {
        let statusFromError = error?.statusCode == 409
        let statusFromBody = decoded?.status == 409
        let statusFromJSON: Bool = {
            guard let responseString, let data = responseString.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode(DeviceRegistrationVerifyAPIResponse.self, from: data)
            else { return false }
            return parsed.status == 409
        }()
        guard statusFromError || statusFromBody || statusFromJSON else { return nil }

        if let responseString, let data = responseString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(DeviceRegistrationVerifyAPIResponse.self, from: data),
           let payload = parsed.data {
            let deviceId = payload.device_id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !deviceId.isEmpty {
                return DeviceRegistrationVerifyResult(deviceId: deviceId)
            }
        }

        let stored = DBHelper.shared.getDeviceInfo().deviceId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !stored.isEmpty {
            return DeviceRegistrationVerifyResult(deviceId: stored)
        }

        let resolved = SDKDeviceIdResolver.resolve().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !resolved.isEmpty else { return nil }
        return DeviceRegistrationVerifyResult(deviceId: resolved)
    }
}
