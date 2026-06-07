//
//  ChangePasswordInteractor.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class ChangePasswordInteractor {
    
    public static var shared: ChangePasswordInteractor = ChangePasswordInteractor()
    var sharedService: ChangePasswordServiceWorker
    var sharedPresenter: ChangePasswordPresenter
    
    public init() {
        sharedService = ChangePasswordServiceWorker.shared
        sharedPresenter = ChangePasswordPresenter.shared
    }
    
    // Change password
    public func changePassword(access_token: String, incomingData : ChangePasswordEntity, callback: @escaping(Result<ChangePasswordResponseEntity>) -> Void) {
        
        // validation
        if (incomingData.new_password == "" || incomingData.confirm_password == "" || incomingData.old_password == "" || (incomingData.identityId == "" && incomingData.sub == "")) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub or identityId, old_password, new_password and confirm_password are required", statusCode: 417)
            sharedPresenter.changePassword(response: nil, errorResponse: error, callback: callback)
            return
        }
        if (incomingData.new_password != incomingData.confirm_password) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "new_password and confirm_password must be same", statusCode: 417)
            sharedPresenter.changePassword(response: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.changePassword(response: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.changePassword(access_token: access_token, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.changePassword(response: response, errorResponse: error, callback: callback)
        }
    }
    
    func getProperties() -> Dictionary<String, String>? {
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            return savedProp!
        }
        return nil
    }
}
