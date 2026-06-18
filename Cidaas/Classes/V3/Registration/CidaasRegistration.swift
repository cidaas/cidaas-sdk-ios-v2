//
//  CidaasRegistration.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Native user registration for custom in-app forms (not hosted browser registration).
    /// Call on ``Cidaas/shared``, e.g. `Cidaas.shared.nativeRegistration()`.
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

    private var dpopOption = CidaasDpopBuilderOption()

    /// Includes `dpop_jkt` on the OAuth `request_id` call when enabled (iOS 14+).
    @discardableResult
    public func useDpop(_ enabled: Bool = true) -> Self {
        dpopOption.setUseDpop(enabled)
        return self
    }

    /// Tenant registration field metadata for building a native signup form.
    public func registrationFields(
        acceptLanguage: String = "en-us",
        requestId: String,
        completion: @escaping (Result<RegistrationFieldsResponseEntity>) -> Void
    ) {
        let rid = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            completion(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "request_id is required", statusCode: 417
            )))
            return
        }
        CidaasNative.shared.getRegistrationFields(
            acceptlanguage: acceptLanguage,
            requestId: rid,
            callback: completion
        )
    }

    /// Registers a new user with a previously fetched OAuth `request_id`.
    public func registerUser(
        requestId: String,
        entity: RegistrationEntity,
        completion: @escaping (Result<CidaasNativeRegistrationResult>) -> Void
    ) {
        let rid = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            completion(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "request_id is required", statusCode: 417
            )))
            return
        }
        CidaasNative.shared.registerUser(requestId: rid, incomingData: entity) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error: error))
            case .success(let response):
                guard response.success else {
                    completion(.failure(error: WebAuthError.shared.serviceFailureException(
                        errorCode: Int(response.status),
                        errorMessage: "Registration failed (status=\(response.status))",
                        statusCode: Int(response.status)
                    )))
                    return
                }
                let data = response.data
                completion(.success(result: CidaasNativeRegistrationResult(
                    sub: data.sub,
                    userStatus: data.userStatus,
                    trackId: data.trackId,
                    suggestedAction: data.suggested_action,
                    emailVerified: data.email_verified
                )))
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
                completion(.failure(error: error))
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
                completion(.failure(error: error))
            case .success(let requestId):
                self.registrationFields(acceptLanguage: acceptLanguage, requestId: requestId) { fieldsResult in
                    switch fieldsResult {
                    case .failure(let error):
                        completion(.failure(error: error))
                    case .success(let fields):
                        completion(.success(result: (requestId: requestId, fields: fields)))
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
            .useDpop(dpopOption.useDpop)
            .requestId(extraParams: extraParams) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error: error))
                case .success(let response):
                    guard response.success else {
                        completion(.failure(error: WebAuthError.shared.serviceFailureException(
                            errorCode: 2,
                            errorMessage: "authz requestId success=false status=\(response.status)",
                            statusCode: Int(response.status)
                        )))
                        return
                    }
                    let requestId = response.data.requestId.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !requestId.isEmpty else {
                        completion(.failure(error: WebAuthError.shared.serviceFailureException(
                            errorCode: 3,
                            errorMessage: "Empty requestId in authz response",
                            statusCode: 417
                        )))
                        return
                    }
                    completion(.success(result: requestId))
                }
            }
    }
}
