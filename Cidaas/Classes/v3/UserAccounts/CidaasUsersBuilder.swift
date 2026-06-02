//
//  CidaasUsersBuilder.swift
//  Cidaas
//

import Foundation

public final class CidaasUsersBuilder {

    public init() {}

    public func passwordReset(
        _ action: CidaasPasswordResetAction,
        completion: @escaping (Result<CidaasPasswordResetOutcome>) -> Void
    ) {
        switch action {
        case .initiate(let incoming):
            ResetPasswordInteractor.shared.initiateResetPassword(incomingData: incoming) { res in
                Self.lift(res, into: CidaasPasswordResetOutcome.initiate, completion: completion)
            }
        case .validate(let incoming):
            ResetPasswordInteractor.shared.handleResetPassword(incomingData: incoming) { res in
                Self.lift(res, into: CidaasPasswordResetOutcome.validate, completion: completion)
            }
        case .accept(let incoming):
            ResetPasswordInteractor.shared.resetPassword(incomingData: incoming) { res in
                Self.lift(res, into: CidaasPasswordResetOutcome.accept, completion: completion)
            }
        }
    }

    @available(iOS 13.0, *)
    public func passwordReset(_ action: CidaasPasswordResetAction) async throws -> CidaasPasswordResetOutcome {
        try await withCheckedThrowingContinuation { continuation in
            passwordReset(action) { result in
                switch result {
                case .success(result: let outcome):
                    continuation.resume(returning: outcome)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func accountVerification(
        _ action: CidaasAccountVerificationAction,
        completion: @escaping (Result<CidaasAccountVerificationOutcome>) -> Void
    ) {
        switch action {
        case .initiate(let incoming):
            AccountVerificationInteractor.shared.initiateAccountVerification(incomingData: incoming) { res in
                Self.lift(res, into: CidaasAccountVerificationOutcome.initiate, completion: completion)
            }
        case .validate(let incoming):
            AccountVerificationInteractor.shared.verifyAccount(incomingData: incoming) { res in
                Self.lift(res, into: CidaasAccountVerificationOutcome.validate, completion: completion)
            }
        }
    }

    @available(iOS 13.0, *)
    public func accountVerification(_ action: CidaasAccountVerificationAction) async throws -> CidaasAccountVerificationOutcome {
        try await withCheckedThrowingContinuation { continuation in
            accountVerification(action) { result in
                switch result {
                case .success(result: let outcome):
                    continuation.resume(returning: outcome)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func fetchUserInfo(sub: String, completion: @escaping (Result<UserInfoEntity>) -> Void) {
        Cidaas.shared.getUserInfo(sub: sub, callback: completion)
    }

    @available(iOS 13.0, *)
    public func fetchUserInfo(sub: String) async throws -> UserInfoEntity {
        try await withCheckedThrowingContinuation { continuation in
            fetchUserInfo(sub: sub) { result in
                switch result {
                case .success(result: let value):
                    continuation.resume(returning: value)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func fetchUserInfo(accessToken: String, completion: @escaping (Result<UserInfoEntity>) -> Void) {
        Cidaas.shared.getUserInfo(accessToken: accessToken, callback: completion)
    }

    @available(iOS 13.0, *)
    public func fetchUserInfo(accessToken: String) async throws -> UserInfoEntity {
        try await withCheckedThrowingContinuation { continuation in
            fetchUserInfo(accessToken: accessToken) { result in
                switch result {
                case .success(result: let value):
                    continuation.resume(returning: value)
                case .failure(error: let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func lift<T, O>(_ result: Result<T>, into embed: (T) -> O, completion: @escaping (Result<O>) -> Void) {
        switch result {
        case .success(result: let value):
            completion(.success(result: embed(value)))
        case .failure(error: let error):
            completion(.failure(error: error))
        }
    }
}
