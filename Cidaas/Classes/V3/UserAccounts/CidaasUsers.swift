//
//  CidaasUsers.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Entry point for ``CidaasUsersBuilder`` (userinfo, password reset, change/set password, account verification).
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

public enum CidaasChangePasswordAction {
    case change(ChangePasswordEntity)
}

public enum CidaasChangePasswordOutcome {
    case change(ChangePasswordResponseEntity)
}

public enum CidaasSetPasswordAction {
    case set(SetPasswordEntity)
}

public enum CidaasSetPasswordOutcome {
    case set(SetPasswordResponseEntity)
}

public enum CidaasAccountVerificationAction {
    case initiate(InitiateAccountVerificationEntity)
    case validate(VerifyAccountEntity)
}

public enum CidaasAccountVerificationOutcome {
    case initiate(InitiateAccountVerificationResponseEntity)
    case validate(VerifyAccountResponseEntity)
}
