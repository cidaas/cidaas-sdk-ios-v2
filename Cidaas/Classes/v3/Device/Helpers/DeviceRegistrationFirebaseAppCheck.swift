//
//  DeviceRegistrationFirebaseAppCheck.swift
//  Cidaas
//

import Foundation

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

/// Fetches a Firebase App Check attestation token for device registration verify (`provider: firebase`).
@available(iOS 14.0, *)
enum DeviceRegistrationFirebaseAppCheck {

    /// Override to supply an App Check JWT when Firebase App Check is linked in the host app.
    static var tokenProvider: (@Sendable () async throws -> String)?

    private static let logCategory = "cidaas-sdk-device-log"

    private static func log(_ message: String) {
        guard Cidaas.shared.ENABLE_LOG else { return }
        logw("[CidaasDevice/AppCheck] \(message)", cname: logCategory)
    }

    static func fetchAttestationToken() async throws -> String {
        if let tokenProvider {
            log("fetching token via host app provider…")
            do {
                let token = try await tokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else {
                    throw missingTokenError("Firebase App Check token provider returned an empty token.")
                }
                log("token received from host app provider")
                return token
            } catch {
                log("host provider failed: \(error.localizedDescription)")
                throw error
            }
        }
#if canImport(FirebaseAppCheck)
        return try await fetchTokenFromFirebaseSDK()
#else
        throw missingTokenError(
            """
            Firebase App Check is not available inside the Cidaas SDK module. \
            Link FirebaseAppCheck in your app, configure an App Check provider before FirebaseApp.configure(), \
            then assign CidaasDevice.firebaseAppCheckTokenProvider to fetch and return the App Check JWT.
            """
        )
#endif
    }

#if canImport(FirebaseAppCheck)
    private static func fetchTokenFromFirebaseSDK() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            AppCheck.appCheck().token(forcingRefresh: false) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = (token?.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    continuation.resume(throwing: missingTokenError("Firebase App Check returned an empty token."))
                    return
                }
                continuation.resume(returning: value)
            }
        }
    }
#endif

    private static func missingTokenError(_ message: String) -> NSError {
        NSError(
            domain: "CidaasDeviceRegistration",
            code: 20,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
