//
//  CidaasWebAuthBuilder.swift
//  Cidaas
//

import Foundation
import UIKit

extension Cidaas {

    /// Entry point for fluent browser sign-in / sign-out (see ``CidaasWebAuthBuilder``).
    /// - Parameter delegate: View controller used to present the system browser / auth UI.
    public static func webAuth(delegate: UIViewController) -> CidaasWebAuthBuilder {
        CidaasWebAuthBuilder(delegate: delegate)
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
    private weak var delegateViewController: UIViewController?

    public init(delegate: UIViewController) {
        delegateViewController = delegate
    }

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

    private static let missingDelegateMessage =
        "Pass a live UIViewController to webAuth(delegate:). The reference was missing or deallocated before sign-in or sign-out."

    public func signIn(completion: @escaping (Result<LoginResponseEntity>) -> Void) {
        guard let viewController = delegateViewController else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = Self.missingDelegateMessage
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

    public func signOut(sub: String, completion: @escaping (Result<Bool>) -> Void) {
        guard let viewController = delegateViewController else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = Self.missingDelegateMessage
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        let trimmedSub = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSub.isEmpty else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = "signOut(sub:) requires a non-empty sub."
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        BrowserAuthPerform.startLogout(
            presentingFrom: viewController,
            sub: trimmedSub,
            completion: completion
        )
    }

    @available(iOS 13.0, *)
    public func signOut(sub: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            signOut(sub: sub) { result in
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
