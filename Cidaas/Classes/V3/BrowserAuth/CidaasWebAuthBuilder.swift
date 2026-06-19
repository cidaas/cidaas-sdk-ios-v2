//
//  CidaasWebAuthBuilder.swift
//  Cidaas
//

import Foundation
import UIKit

extension Cidaas {

    /// Fluent browser sign-in / sign-out (see ``CidaasWebAuthBuilder``). Call on ``Cidaas/shared``, e.g. `Cidaas.shared.webAuth(delegate: self)`.
    /// - Parameter delegate: View controller used to present the system browser / auth UI.
    public func webAuth(delegate: UIViewController) -> CidaasWebAuthBuilder {
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
    private var storedExtraParameters: [String: String] = [:]
    private var dpopOption = CidaasDpopBuilderOption()
    private weak var delegateViewController: UIViewController?

    public init(delegate: UIViewController) {
        delegateViewController = delegate
    }

    /// Enables DPoP for browser auth: `dpop_jkt` on the authorization URL / ``requestId``, and a `DPoP` proof header on `POST /token-srv/token` (code exchange and refresh) (iOS 14+).
    @discardableResult
    public func useDpop(_ enabled: Bool = true) -> Self {
        dpopOption.setUseDpop(enabled)
        return self
    }

    /// Fetches an OAuth `request_id` (e.g. before ``social(provider:requestId:)``). Includes `dpop_jkt` when ``useDpop()`` is enabled (iOS 14+).
    public func requestId(
        extraParams: [String: String] = [:],
        completion: @escaping (Result<RequestIdResponseEntity>) -> Void
    ) {
        let params = CidaasHTTPProofAuthz.mergingDpopJKT(into: extraParams, useDpop: dpopOption.useDpop)
        AuthzInteractor.shared.getRequestId(extraParams: params, callback: completion)
    }

    @discardableResult
    public func extraParameters(_ params: [String: String]) -> Self {
        storedExtraParameters = params
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
        "Pass a live UIViewController to Cidaas.shared.webAuth(delegate:). The reference was missing or deallocated before sign-in or sign-out."

    public func signIn(completion: @escaping (Result<LoginResponseEntity>) -> Void) {
        guard let viewController = delegateViewController else {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = Self.missingDelegateMessage
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        CidaasDpopFlowContext.runWithUseDpop(dpopOption.useDpop, operation: { wrapped in
            switch sessionKind {
            case .login:
                BrowserAuthPerform.startLogin(
                    presentingFrom: viewController,
                    extraParameters: storedExtraParameters,
                    completion: wrapped
                )
            case .registration:
                BrowserAuthPerform.startRegistration(
                    presentingFrom: viewController,
                    extraParameters: storedExtraParameters,
                    completion: wrapped
                )
            case .social(let provider, let requestId):
                guard !provider.isEmpty, !requestId.isEmpty else {
                    let error = WebAuthError.shared.propertyMissingException()
                    error.errorMessage = "social(provider:requestId:) requires non-empty values"
                    DispatchQueue.main.async {
                        wrapped(.failure(error: error))
                    }
                    return
                }
                BrowserAuthPerform.startSocialLogin(
                    provider: provider,
                    requestId: requestId,
                    presentingFrom: viewController,
                    completion: wrapped
                )
            }
        }, completion: completion)
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
