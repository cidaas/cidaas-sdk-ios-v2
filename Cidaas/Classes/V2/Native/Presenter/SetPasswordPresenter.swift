//
//  SetPasswordPresenter.swift
//  Cidaas
//

import Foundation

public class SetPasswordPresenter {

    public static var shared: SetPasswordPresenter = SetPasswordPresenter()

    public init() {}

    public func setPassword(
        response: String?,
        errorResponse: WebAuthError?,
        callback: @escaping (Result<SetPasswordResponseEntity>) -> Void
    ) {
        if errorResponse != nil {
            logw(errorResponse!.errorMessage, cname: "cidaas-sdk-verification-error-log")
            callback(Result.failure(error: errorResponse!))
        } else {
            let decoder = JSONDecoder()
            do {
                let data = response!.data(using: .utf8)!
                let resp = try decoder.decode(SetPasswordResponseEntity.self, from: data)
                logw(response ?? "Empty response string", cname: "cidaas-sdk-verification-success-log")
                callback(Result.success(result: resp))
            } catch let error {
                logw("\(String(describing: error)) JSON parsing issue, Response: \(String(describing: response))", cname: "cidaas-sdk-verification-error-log")
                callback(Result.failure(error: WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: error.localizedDescription, statusCode: 400)))
            }
        }
    }
}
