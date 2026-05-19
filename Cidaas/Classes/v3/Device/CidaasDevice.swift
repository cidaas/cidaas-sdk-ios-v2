//
//  CidaasDevice.swift
//  Cidaas
//

import Foundation
import Alamofire

extension Cidaas {
    /// Device registration entry point.
    public var device: CidaasDevice {
        CidaasDevice()
    }
}

/// Registers this iOS device with App Attest, DPoP and biometric-bound keys.
public final class CidaasDevice {

    fileprivate init() {}

    /// Logs initiate/verify API responses; includes error details when the call fails.
    private func logDeviceRegistration(_ phase: String, response: String? = nil, error: Error? = nil) {
        if let response {
            print("[CidaasDevice] \(phase) response: \(response)")
        }
        if let error {
            if let webAuth = error as? WebAuthError {
                print("[CidaasDevice] \(phase) error: \(webAuth.errorMessage) (status=\(webAuth.statusCode))")
            } else {
                print("[CidaasDevice] \(phase) error: \(error.localizedDescription)")
            }
        }
    }

    /// Full flow: request session + nonce, then attest the app and complete registration with Face ID / Touch ID.
    /// Requires `NSFaceIDUsageDescription` in the host app Info.plist.
    @available(iOS 14.0, *)
    public func registerDevice(
        clientId: String,
        pushId: String,
        completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
    ) {
        startRegistration(clientId: clientId, pushId: pushId) { initiateResult in
            switch initiateResult {
            case .failure(error: let error):
                completion(.failure(error: error))
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

    /// Step 1: obtain `sessionId` and `nonce` for this device (internal).
    func startRegistration(
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
                    nonce: payload.nonce
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

    /// Step 2: App Attest + proof JWTs + finish registration (internal; prompts for biometrics).
    @available(iOS 14.0, *)
    func completeRegistration(
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
                // App Attest key + attestation bound to the registration nonce.
                let appAttestKeyId = try await DeviceRegistrationAppAttest.generateKeyId()
                let attestation = try await DeviceRegistrationAppAttest.attest(
                    keyId: appAttestKeyId,
                    challengeB64FromServer: nonce
                )
                let prepared = try DeviceRegistrationProofs.prepareVerificationRequest(
                    verificationURLString: urlString,
                    sessionId: sessionId,
                    attestationObject: attestation,
                    appAttestKeyId: appAttestKeyId,
                    appVersion: appVersion,
                    platform: "ios"
                )
                SessionManager.shared.startSession(
                    url: urlString,
                    method: .post,
                    parameters: prepared.bodyParams,
                    extraheaders: prepared.extraHeaders
                ) { responseString, error in
                    if let error {
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
                DispatchQueue.main.async {
                    completion(.failure(error: err))
                }
            }
        }
    }
}
