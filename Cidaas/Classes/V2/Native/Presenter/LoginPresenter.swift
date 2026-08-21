//
//  LoginPresenter.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class LoginPresenter {
    
    public static var shared: LoginPresenter = LoginPresenter()
    
    public init() {}
    
    public func logout(response: String?, errorResponse: WebAuthError?, callback: @escaping (Result<Bool>) -> Void) {
        if errorResponse != nil {
            logw(errorResponse!.errorMessage, cname: "cidaas-sdk-verification-error-log")
            callback(Result.failure(error: errorResponse!))
        }
        else {
             logw(response ?? "Empty response string", cname: "cidaas-sdk-verification-success-log")
            callback(Result.success(result: true))
//            let decoder = JSONDecoder()
//            do {
//                let data = response!.data(using: .utf8)!
//                // decode the json data to object
//                let resp = try decoder.decode(AuthzCodeEntity.self, from: data)
//
//                logw(response ?? "Empty response string", cname: "cidaas-sdk-verification-success-log")
//                // get accesstoken from code
//                AccessTokenController.shared.getAccessToken(code: resp.data.code) {
//                    switch $0 {
//                    case .failure(let error):
//                        // return callback
//                        DispatchQueue.main.async {
//                            callback(Result.failure(error: error))
//                        }
//                        return
//                    case .success(let tokenResponse):
//                        // return callback
//                        DispatchQueue.main.async {
//                            callback(Result.success(result: tokenResponse))
//                        }
//                        return
//                    }
//                }
//            }
//            catch(let error) {
//                // return failure
//                logw("\(String(describing: error)) JSON parsing issue, Response: \(String(describing: response))", cname: "cidaas-sdk-verification-error-log")
//                callback(Result.failure(error: WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: error.localizedDescription, statusCode: 400)))
//            }
        }
    }
    
    // login with credentials service
    public func loginWithCredentials(response: String?, errorResponse: WebAuthError?, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        if errorResponse != nil {
            logw(errorResponse!.errorMessage, cname: "cidaas-sdk-verification-error-log")
            callback(Result.failure(error: errorResponse!))
        }
        else {
            exchangeAuthorizationCode(from: response, callback: callback)
        }
    }

    public func loginAfterRegister(response: String?, errorResponse: WebAuthError?, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        if let errorResponse {
            logw(errorResponse.errorMessage, cname: "cidaas-sdk-verification-error-log")
            callback(Result.failure(error: errorResponse))
        } else {
            exchangeAuthorizationCode(from: response, callback: callback)
        }
    }

    /// Reads OAuth `code` from JSON `{ data.code }` or redirect URL `?code=`, then exchanges for tokens.
    private func exchangeAuthorizationCode(from response: String?, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        guard let raw = response?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            callback(Result.failure(error: WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Empty authorization code response", statusCode: 400)))
            return
        }

        if let code = authorizationCode(from: raw), !code.isEmpty {
            logw(raw, cname: "cidaas-sdk-verification-success-log")
            AccessTokenController.shared.getAccessToken(code: code) { result in
                DispatchQueue.main.async {
                    callback(result)
                }
            }
            return
        }

        logw("Could not read authorization code from: \(raw)", cname: "cidaas-sdk-verification-error-log")
        callback(Result.failure(error: WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Authorization code missing in login-after-register response", statusCode: 400)))
    }

    private func authorizationCode(from raw: String) -> String? {
        if raw.hasPrefix("{") || raw.hasPrefix("[") {
            guard let data = raw.data(using: .utf8) else { return nil }
            if let resp = try? JSONDecoder().decode(AuthzCodeEntity.self, from: data) {
                let code = resp.data.code.trimmingCharacters(in: .whitespacesAndNewlines)
                return code.isEmpty ? nil : code
            }
            return nil
        }
        guard let url = URL(string: raw) else { return nil }
        let code = (url.valueOf("code") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : code
    }
}
