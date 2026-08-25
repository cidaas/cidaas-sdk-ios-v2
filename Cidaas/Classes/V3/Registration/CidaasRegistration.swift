//
//  CidaasRegistration.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Native user registration for custom in-app forms (not hosted browser registration).
    public func nativeRegistration() -> CidaasNativeRegistrationBuilder {
        CidaasNativeRegistrationBuilder()
    }
}

public struct CidaasNativeRegistrationResult {
    public let sub: String
    public let userStatus: String
    public let trackId: String
    public let suggestedAction: String
    public let emailVerified: Bool

    public init(
        sub: String,
        userStatus: String,
        trackId: String,
        suggestedAction: String,
        emailVerified: Bool
    ) {
        self.sub = sub
        self.userStatus = userStatus
        self.trackId = trackId
        self.suggestedAction = suggestedAction
        self.emailVerified = emailVerified
    }
}

public final class CidaasNativeRegistrationBuilder {

    /// Tenant registration field metadata for building a native signup form.
    public func registrationFields(
        acceptLanguage: String = "en-us",
        requestId: String,
        completion: @escaping (Result<RegistrationFieldsResponseEntity>) -> Void
    ) {
        let rid = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "request_id is required", statusCode: 417
            )), to: completion)
            return
        }
        CidaasNative.shared.getRegistrationFields(
            acceptlanguage: acceptLanguage,
            requestId: rid,
            callback: { result in
            CidaasV3Callback.deliver(result, to: completion)
        })
    }

    /// Registers a new user with a previously fetched OAuth `request_id`.
    public func registerUser(
        requestId: String,
        entity: RegistrationEntity,
        completion: @escaping (Result<CidaasNativeRegistrationResult>) -> Void
    ) {
        let rid = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "request_id is required", statusCode: 417
            )), to: completion)
            return
        }
        CidaasNative.shared.registerUser(requestId: rid, incomingData: entity) { result in
            switch result {
            case .failure(let error):
                CidaasV3Callback.deliver(.failure(error: error), to: completion)
            case .success(let response):
                guard response.success else {
                    CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                        errorCode: Int(response.status),
                        errorMessage: "Registration failed (status=\(response.status))",
                        statusCode: Int(response.status)
                    )), to: completion)
                    return
                }
                let data = response.data
                CidaasV3Callback.deliver(.success(result: CidaasNativeRegistrationResult(
                    sub: data.sub,
                    userStatus: data.userStatus,
                    trackId: data.trackId,
                    suggestedAction: data.suggested_action,
                    emailVerified: data.email_verified
                )), to: completion)
            }
        }
    }

    /// Completes login after account verification: `POST /login-srv/login/handle/afterregister/{trackId}` → 302 `Location` with OAuth `code` → token exchange.
    public func loginAfterRegister(
        trackId: String,
        completion: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "trackId is required", statusCode: 417
            )), to: completion)
            return
        }
        CidaasNative.shared.loginAfterRegister(trackId: trimmed) { result in
            CidaasV3Callback.deliver(result, to: completion)
        }
    }

    /// Async variant of ``loginAfterRegister(trackId:completion:)``.
    @available(iOS 13.0, *)
    public func loginAfterRegister(trackId: String) async throws -> LoginResponseEntity {
        try await withCheckedThrowingContinuation { continuation in
            loginAfterRegister(trackId: trackId) { result in
                switch result {
                case .success(result: let value):
                    continuation.resume(returning: value)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fetches OAuth `request_id`, then registers the user.
    public func register(
        acceptLanguage: String = "en-us",
        entity: RegistrationEntity,
        extraParams: [String: String] = [:],
        completion: @escaping (Result<CidaasNativeRegistrationResult>) -> Void
    ) {
        fetchRequestId(extraParams: extraParams) { [self] ridResult in
            switch ridResult {
            case .failure(let error):
                CidaasV3Callback.deliver(.failure(error: error), to: completion)
            case .success(let requestId):
                self.registerUser(requestId: requestId, entity: entity, completion: completion)
            }
        }
    }

    /// Fetches `request_id` and registration field metadata for dynamic native forms.
    public func loadForm(
        acceptLanguage: String = "en-us",
        extraParams: [String: String] = [:],
        completion: @escaping (Result<(requestId: String, fields: RegistrationFieldsResponseEntity)>) -> Void
    ) {
        fetchRequestId(extraParams: extraParams) { [self] ridResult in
            switch ridResult {
            case .failure(let error):
                CidaasV3Callback.deliver(.failure(error: error), to: completion)
            case .success(let requestId):
                self.registrationFields(acceptLanguage: acceptLanguage, requestId: requestId) { fieldsResult in
                    switch fieldsResult {
                    case .failure(let error):
                        CidaasV3Callback.deliver(.failure(error: error), to: completion)
                    case .success(let fields):
                        CidaasV3Callback.deliver(.success(result: (requestId: requestId, fields: fields)), to: completion)
                    }
                }
            }
        }
    }

    private func fetchRequestId(
        extraParams: [String: String],
        completion: @escaping (Result<String>) -> Void
    ) {
        Cidaas.shared.publicAPI()
            .requestId(extraParams: extraParams) { result in
                switch result {
                case .failure(error: let error):
                    CidaasV3Callback.deliver(.failure(error: error), to: completion)
                case .success(result: let response):
                    guard response.success else {
                        CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                            errorCode: 2,
                            errorMessage: "authz requestId success=false status=\(response.status)",
                            statusCode: Int(response.status)
                        )), to: completion)
                        return
                    }
                    let requestId = response.data.requestId.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !requestId.isEmpty else {
                        CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                            errorCode: 3,
                            errorMessage: "Empty requestId in authz response",
                            statusCode: 417
                        )), to: completion)
                        return
                    }
                    CidaasV3Callback.deliver(.success(result: requestId), to: completion)
                }
            }
    }
}
