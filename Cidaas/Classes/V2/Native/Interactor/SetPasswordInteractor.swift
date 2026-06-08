//
//  SetPasswordInteractor.swift
//  Cidaas
//

import Foundation

public class SetPasswordInteractor {

    public static var shared: SetPasswordInteractor = SetPasswordInteractor()
    var sharedService: SetPasswordServiceWorker
    var sharedPresenter: SetPasswordPresenter

    public init() {
        sharedService = SetPasswordServiceWorker.shared
        sharedPresenter = SetPasswordPresenter.shared
    }

    public func setPassword(
        access_token: String,
        incomingData: SetPasswordEntity,
        callback: @escaping (Result<SetPasswordResponseEntity>) -> Void
    ) {
        if incomingData.password.isEmpty || incomingData.confirmPassword.isEmpty {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "password and confirmPassword are required",
                statusCode: 417
            )
            sharedPresenter.setPassword(response: nil, errorResponse: error, callback: callback)
            return
        }
        if incomingData.password != incomingData.confirmPassword {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "password and confirmPassword must match",
                statusCode: 417
            )
            sharedPresenter.setPassword(response: nil, errorResponse: error, callback: callback)
            return
        }

        guard let savedProp = getProperties() else {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "properties cannot be empty",
                statusCode: 417
            )
            sharedPresenter.setPassword(response: nil, errorResponse: error, callback: callback)
            return
        }

        sharedService.setPassword(access_token: access_token, incomingData: incomingData, properties: savedProp) { response, error in
            self.sharedPresenter.setPassword(response: response, errorResponse: error, callback: callback)
        }
    }

    func getProperties() -> Dictionary<String, String>? {
        DBHelper.shared.getPropertyFile()
    }
}
