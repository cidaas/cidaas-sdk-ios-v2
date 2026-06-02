//
//  CidaasUsers.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Entry point for ``CidaasUsersBuilder`` (userinfo, password reset, account verification).
    public static func users() -> CidaasUsersBuilder {
        CidaasUsersBuilder()
    }
}

public enum CidaasPasswordResetAction {
    case initiate(InitiateResetPasswordEntity)
    case validate(HandleResetPasswordEntity)
    case accept(ResetPasswordEntity)
}

public enum CidaasPasswordResetOutcome {
    case initiate(InitiateResetPasswordResponseEntity)
    case validate(HandleResetPasswordResponseEntity)
    case accept(ResetPasswordResponseEntity)
}

public enum CidaasAccountVerificationAction {
    case initiate(InitiateAccountVerificationEntity)
    case validate(VerifyAccountEntity)
}

public enum CidaasAccountVerificationOutcome {
    case initiate(InitiateAccountVerificationResponseEntity)
    case validate(VerifyAccountResponseEntity)
}
