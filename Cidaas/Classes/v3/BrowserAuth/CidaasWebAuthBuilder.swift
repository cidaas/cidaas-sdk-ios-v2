//
//  CidaasWebAuthBuilder.swift
//  Cidaas
//

import Foundation
import UIKit

extension Cidaas {

    /// Entry point for fluent browser sign-in / sign-out (see ``CidaasWebAuthBuilder``).
    public static func webAuth() -> CidaasWebAuthBuilder {
        CidaasWebAuthBuilder()
    }
}

private enum WebAuthSessionKind {
    case login
    case registration
    case social(provider: String, requestId: String)
}

public final class CidaasWebAuthBuilder {

    private var sessionKind: WebAuthSessionKind = .login
    private var extraParameters: [String: String] = [:]
    private weak var presentingViewController: UIViewController?

    public init() {}

    @discardableResult
    public func parameters(_ params: [String: String]) -> Self {
        extraParameters = params
        return self
    }

    @discardableResult
    public func registration() -> Self {
        sessionKind = .registration
        return self
    }

    @discardableResult
    public func social(provider: String, requestId: String) -> Self {
        sessionKind = .social(provider: provider, requestId: requestId)
        return self
    }

    @discardableResult
    public func presenting(from viewController: UIViewController) -> Self {
        presentingViewController = viewController
        return self
    }

    public func signIn(completion: @escaping (Result<LoginResponseEntity>) -> Void) {
        guard let viewController = presentingViewController else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = "presenting(from:) is required before signIn(completion:)"
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        switch sessionKind {
        case .login:
            BrowserAuthPerform.startLogin(
                presentingFrom: viewController,
                extraParameters: extraParameters,
                completion: completion
            )
        case .registration:
            BrowserAuthPerform.startRegistration(
                presentingFrom: viewController,
                extraParameters: extraParameters,
                completion: completion
            )
        case .social(let provider, let requestId):
            guard !provider.isEmpty, !requestId.isEmpty else {
                let error = WebAuthError.shared.propertyMissingException()
                error.errorMessage = "social(provider:requestId:) requires non-empty values"
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
                return
            }
            BrowserAuthPerform.startSocialLogin(
                provider: provider,
                requestId: requestId,
                presentingFrom: viewController,
                completion: completion
            )
        }
    }

    @available(iOS 13.0, *)
    public func signIn() async throws -> LoginResponseEntity {
        try await withCheckedThrowingContinuation { continuation in
            signIn { result in
                continuation.resume(with: result.cidaasToSwiftResult())
            }
        }
    }

    public func signOut(completion: @escaping (Result<Bool>) -> Void) {
        guard let viewController = presentingViewController else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = "presenting(from:) is required before signOut(completion:)"
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        let shared = AccessTokenModel.shared
        let sub = shared.sub
        let model = sub.isEmpty ? shared : DBHelper.shared.getAccessToken(key: sub)

        EntityToModelConverter.shared.accessTokenModelToAccessTokenEntity(accessTokenModel: model) { accessTokenEntity in
            let accessToken = accessTokenEntity.access_token
            let entitySub = accessTokenEntity.sub

            if !accessToken.isEmpty {
                BrowserAuthPerform.startLogout(
                    presentingFrom: viewController,
                    accessToken: accessToken,
                    completion: completion
                )
            } else if !sub.isEmpty {
                BrowserAuthPerform.startLogout(
                    presentingFrom: viewController,
                    sub: sub,
                    completion: completion
                )
            } else if !entitySub.isEmpty {
                BrowserAuthPerform.startLogout(
                    presentingFrom: viewController,
                    sub: entitySub,
                    completion: completion
                )
            } else {
                let error = WebAuthError.shared.propertyMissingException()
                error.errorMessage = "No access token or sub in session; complete a login before browser sign-out."
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
            }
        }
    }

    @available(iOS 13.0, *)
    public func signOut() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            signOut { result in
                continuation.resume(with: result.cidaasBoolToSwiftResult())
            }
        }
    }
}

private extension Result where T == LoginResponseEntity {
    func cidaasToSwiftResult() -> Swift.Result<LoginResponseEntity, Error> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

private extension Result where T == Bool {
    func cidaasBoolToSwiftResult() -> Swift.Result<Bool, Error> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}
