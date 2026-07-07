//
//  VerificationInteractor.swift
//  Cidaas
//
//  Created by ganesh on 06/05/19.
//

import Foundation
import UIKit

public class VerificationInteractor {
    
    var push_selected_number: String = ""
    var secret: String = ""
    
    public static var shared: VerificationInteractor = VerificationInteractor()
    var sharedPresenter: VerificationPresenter
    var sharedService: VerificationServiceWorker
    
    public init() {
        sharedPresenter = VerificationPresenter.shared
        sharedService = VerificationServiceWorker.shared
    }
    
    public func setup(verificationType: String, incomingData: SetupRequest, callback: @escaping (Result<SetupResponse>) -> Void) {
        // validation
        if (verificationType == "" || (incomingData.access_token == "" && incomingData.sub == "")) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or access_token or sub cannot be empty", statusCode: 417)
            sharedPresenter.setup(response: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.setup(response: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.setup(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.setup(response: response, errorResponse: error, callback: callback)
        }
    }
    
    public func scanned(verificationType: String, incomingData: ScannedRequest, callback: @escaping (Result<ScannedResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id or sub cannot be empty", statusCode: 417)
            sharedPresenter.scanned(scannedResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.scanned(scannedResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.scanned(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.scanned(scannedResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func enroll(verificationType: String, photo: UIImage = UIImage(), voice: Data = Data(), incomingData: EnrollRequest, callback: @escaping (Result<EnrollResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id or pass_code cannot be empty", statusCode: 417)
            sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.enroll(verificationType: verificationType, photo: photo, voice: voice, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.enroll(enrollResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func initiate(verificationType: String, incomingData: InitiateRequest, callback: @escaping (Result<InitiateResponse>) -> Void) {
        var validationMessage: String?
        if verificationType.isEmpty || incomingData.request_id.isEmpty || incomingData.usage_type.isEmpty {
            validationMessage = "verificationType, request_id, and usage_type cannot be empty"
        } else if incomingData.usage_type == UsageTypes.INITIAL.rawValue {
            if incomingData.identifier.isEmpty {
                validationMessage = "identifier is required for INITIAL_AUTHENTICATION"
            } else if !incomingData.sub.isEmpty {
                validationMessage = "sub must not be sent for INITIAL_AUTHENTICATION; use identifier"
            }
        } else if incomingData.usage_type == UsageTypes.MFA.rawValue {
            if !incomingData.identifier.isEmpty {
                validationMessage = "identifier is only allowed for INITIAL_AUTHENTICATION"
            } else if incomingData.sub.isEmpty {
                validationMessage = "masked sub is required for MULTIFACTOR_AUTHENTICATION"
            }
        } else if incomingData.sub.isEmpty && incomingData.identifier.isEmpty {
            validationMessage = "sub or identifier is required"
        }
        if let validationMessage {
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: validationMessage, statusCode: 417)
            sharedPresenter.initiate(initiateResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.initiate(initiateResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.initiate(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.initiate(initiateResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func pushAcknowledge(verificationType: String, incomingData: PushAcknowledgeRequest, callback: @escaping (Result<PushAcknowledgeResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id cannot be empty", statusCode: 417)
            sharedPresenter.pushAcknowledge(pushAcknowledgeResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.pushAcknowledge(pushAcknowledgeResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.pushAcknowledge(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.pushAcknowledge(pushAcknowledgeResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func pushAllow(verificationType: String, incomingData: PushAllowRequest, callback: @escaping (Result<PushAllowResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id cannot be empty", statusCode: 417)
            sharedPresenter.pushAllow(pushAllowResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.pushAllow(pushAllowResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.pushAllow(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.pushAllow(pushAllowResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func pushReject(verificationType: String, incomingData: PushRejectRequest, callback: @escaping (Result<PushRejectResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id cannot be empty", statusCode: 417)
            sharedPresenter.pushReject(pushRejectResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.pushReject(pushRejectResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.pushReject(verificationType: verificationType, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.pushReject(pushRejectResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func authenticate(verificationType: String, photo: UIImage = UIImage(), voice: Data = Data(), incomingData: AuthenticateRequest, callback: @escaping (Result<AuthenticateResponse>) -> Void) {
        // validation
        if (verificationType == "" || incomingData.exchange_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "verificationType or exchange_id cannot be empty", statusCode: 417)
            sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.authenticate(verificationType: verificationType, photo: photo, voice: voice, incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.authenticate(authenticateResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func delete(incomingData: DeleteRequest, callback: @escaping (Result<DeleteResponse>) -> Void) {
        // validation
        if (incomingData.sub == "" || incomingData.verificationType == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub or exchange_id or verificationType cannot be empty", statusCode: 417)
            sharedPresenter.delete(deleteResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.deleteAll(deleteResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.delete(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.delete(deleteResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func deleteAll(incomingData: DeleteRequest, callback: @escaping (Result<DeleteResponse>) -> Void) {
        // validation
        // no validation
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.deleteAll(deleteResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.deleteAll(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.deleteAll(deleteResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func getConfiguredList(incomingData: MFAListRequest, callback: @escaping (Result<MFAListResponse>) -> Void) {
        // validation
        if (incomingData.sub == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub cannot be empty", statusCode: 417)
            sharedPresenter.getConfiguredList(mfaListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getConfiguredList(mfaListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.getConfiguredList(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.getConfiguredList(mfaListResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func getPendingNotificationList(incomingData: PendingNotificationRequest, callback: @escaping (Result<PendingNotificationResponse>) -> Void) {
        // validation
        if (incomingData.sub == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub cannot be empty", statusCode: 417)
            sharedPresenter.getPendingNotificationList(pendingNotificationListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getPendingNotificationList(pendingNotificationListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.getPendingNotificationList(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.getPendingNotificationList(pendingNotificationListResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func getMFAHistoryList(incomingData: MFAHistoryRequest, callback: @escaping (Result<MFAHistoryResponse>) -> Void) {
        // validation
        if (incomingData.sub == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub cannot be empty", statusCode: 417)
            sharedPresenter.getMFAHistoryList(authenticatedHistoryListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getMFAHistoryList(authenticatedHistoryListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.getMFAHistoryList(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.getMFAHistoryList(authenticatedHistoryListResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func updateFCM(incomingData: UpdateFCMRequest) {
        // check if first time
        let old_push_id = DBHelper.shared.getFCM()
        
        if (old_push_id == "") {
            DBHelper.shared.setFCM(fcmToken: incomingData.push_id)
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 200, errorMessage: "FCMToken successfully updated", statusCode: 200)
            sharedPresenter.updateFCM(updateFCMResponse: nil, errorResponse: error)
            return
        }
        if (old_push_id == incomingData.push_id) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 200, errorMessage: "No change in FCM", statusCode: 200)
            sharedPresenter.updateFCM(updateFCMResponse: nil, errorResponse: error)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.updateFCM(updateFCMResponse: nil, errorResponse: error)
            return
        }
        
        incomingData.old_push_id = old_push_id
        
        // call worker
        sharedService.updateFCM(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.updateFCM(updateFCMResponse: response, errorResponse: error)
        }
    }
    
    public func configure(incomingData: ConfigureRequest, photo: UIImage = UIImage(), voice: Data = Data(), callback: @escaping (Result<EnrollResponse>) -> Void) {
        
        let setupRequest = SetupRequest()
        setupRequest.access_token = incomingData.access_token
        
        self.setup(verificationType: incomingData.verificationType, incomingData: setupRequest) {
            switch $0 {
            case .success(let setupSuccessResponse):
                    let scannedRequest = ScannedRequest()
                    scannedRequest.sub = setupSuccessResponse.data.sub
                    scannedRequest.exchange_id = setupSuccessResponse.data.exchange_id.exchange_id
                    self.push_selected_number = setupSuccessResponse.data.push_selected_number
                    
                    self.scanned(verificationType: incomingData.verificationType, incomingData: scannedRequest) {
                        switch $0 {
                        case .success(let scannedSuccessResponse):
                            
                            let enrollRequest = EnrollRequest()
                            enrollRequest.pass_code = incomingData.pass_code
                            enrollRequest.exchange_id = scannedSuccessResponse.data.exchange_id.exchange_id
                            enrollRequest.attempt = incomingData.attempt
                            enrollRequest.localizedReason = incomingData.localizedReason
                            
                            if (incomingData.verificationType == VerificationTypes.PUSH.rawValue) {
                                enrollRequest.pass_code = self.push_selected_number
                            }
                            
                            if (incomingData.verificationType == VerificationTypes.TOUCH.rawValue) {
                                self.askForTouchorFaceIdForEnroll(incomingData: enrollRequest, callback: callback)
                            }
                            else {
                                self.enroll(verificationType: incomingData.verificationType, photo: photo, voice: voice, incomingData: enrollRequest, callback: callback)
                            }
                            
                            break
                        case .failure(let scannedErrorResponse):
                            DispatchQueue.main.async {
                                callback(Result.failure(error: scannedErrorResponse))
                            }
                            break
                        }
                    }
                break
            case .failure(let setupErrorResponse):
                DispatchQueue.main.async {
                    callback(Result.failure(error: setupErrorResponse))
                }
                break
            }
        }
    }
    
    public func login(incomingData: LoginRequest, photo: UIImage, voice: Data, callback: @escaping (Result<LoginResponse>) -> Void) {
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.login(loginResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        let initiateRequest = InitiateRequest()
        initiateRequest.sub = incomingData.sub
        initiateRequest.request_id = incomingData.request_id
        initiateRequest.usage_type = incomingData.usage_type
    
        self.initiate(verificationType: incomingData.verificationType, incomingData: initiateRequest) {
            switch $0 {
            case .success(let initiateSuccessResponse):
                
                let authenticateRequest = AuthenticateRequest()
                authenticateRequest.sub = initiateSuccessResponse.data.sub
                authenticateRequest.exchange_id = initiateSuccessResponse.data.exchange_id.exchange_id
                authenticateRequest.applyVerificationCredential(
                    verificationType: incomingData.verificationType,
                    value: incomingData.pass_code
                )
                authenticateRequest.localizedReason = incomingData.localizedReason
                
                self.push_selected_number = initiateSuccessResponse.data.push_selected_number
                
                if (incomingData.verificationType == VerificationTypes.TOUCH.rawValue) {
                    self.askForTouchorFaceIdForAuthenticate(incomingData: authenticateRequest) {
                        switch $0 {
                        case .success(let authenticateSuccessResponse):
                            if (incomingData.usage_type == UsageTypes.PASSWORDLESS.rawValue) {
                                let passwordlessRequest = PasswordlessRequest()
                                passwordlessRequest.requestId = incomingData.request_id
                                passwordlessRequest.status_id = authenticateSuccessResponse.data.status_id
                                passwordlessRequest.sub = incomingData.sub
                                passwordlessRequest.verificationType = incomingData.verificationType
                                self.continueMFA(passwordlessRequest: passwordlessRequest, properties: savedProp!, callback: callback)
                            }
                            break
                        case .failure(let authenticateErrorResponse):
                            self.sharedPresenter.login(loginResponse: nil, errorResponse: authenticateErrorResponse, callback: callback)
                            break
                        }
                    }
                }
                else if (incomingData.verificationType == VerificationTypes.PUSH.rawValue) {
                    authenticateRequest.pass_code = self.push_selected_number
                    self.authenticate(verificationType: incomingData.verificationType, incomingData: authenticateRequest) {
                        switch $0 {
                        case .success(let authenticateSuccessResponse):
                            if (incomingData.usage_type == UsageTypes.PASSWORDLESS.rawValue) {
                                let passwordlessRequest = PasswordlessRequest()
                                passwordlessRequest.requestId = incomingData.request_id
                                passwordlessRequest.status_id = authenticateSuccessResponse.data.status_id
                                passwordlessRequest.sub = incomingData.sub
                                passwordlessRequest.verificationType = incomingData.verificationType

                                self.continueMFA(passwordlessRequest: passwordlessRequest, properties: savedProp!, callback: callback)
                            }
                            break
                        case .failure(let authenticateErrorResponse):
                            self.sharedPresenter.login(loginResponse: nil, errorResponse: authenticateErrorResponse, callback: callback)
                            break
                        }
                    }
                }
                else {
                    self.authenticate(verificationType: incomingData.verificationType, photo: photo, voice: voice, incomingData: authenticateRequest) {
                        switch $0 {
                        case .success(let authenticateSuccessResponse):
                            if (incomingData.usage_type == UsageTypes.PASSWORDLESS.rawValue) {
                                let passwordlessRequest = PasswordlessRequest()
                                passwordlessRequest.requestId = incomingData.request_id
                                passwordlessRequest.status_id = authenticateSuccessResponse.data.status_id
                                passwordlessRequest.sub = incomingData.sub
                                passwordlessRequest.verificationType = incomingData.verificationType
                                self.continueMFA(passwordlessRequest: passwordlessRequest, properties: savedProp!, callback: callback)
                            }
                            break
                        case .failure(let authenticateErrorResponse):
                            self.sharedPresenter.login(loginResponse: nil, errorResponse: authenticateErrorResponse, callback: callback)
                            break
                        }
                    }
                }
                break
            case .failure(let initiateErrorResponse):
                self.sharedPresenter.login(loginResponse: nil, errorResponse: initiateErrorResponse, callback: callback)
                break
            }
        }
    }
    
    public func passwordlessContinue(incomingData: PasswordlessRequest, callback: @escaping (Result<AuthzCodeResponse>) -> Void) {
        
        // validation
        if (incomingData.sub == "" || incomingData.requestId == "" || incomingData.status_id == "" || incomingData.verificationType == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub cannot be empty", statusCode: 417)
            sharedPresenter.passwordlessContinue(passwordlessContinueResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.passwordlessContinue(passwordlessContinueResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.passwordlessContinue(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.passwordlessContinue(passwordlessContinueResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    func getProperties() -> Dictionary<String, String>? {
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            return savedProp!
        }
        return nil
    }
    
    public func askForTouchorFaceIdForEnroll(incomingData: EnrollRequest, callback: @escaping (Result<EnrollResponse>) -> Void) {
        // ask for touch id or face id with attestation
        let touchId = TouchID()
        touchId.checkIfTouchIdAvailable { (success, errorMessage, errorCode) in
            if success == true {
                // Get properties to construct URL for attestation
                guard let savedProp = self.getProperties(),
                      let baseURL = savedProp["DomainURL"] else {
                    let error = WebAuthError.shared.serviceFailureException(
                        errorCode: 417,
                        errorMessage: "properties cannot be empty",
                        statusCode: 417
                    )
                    self.sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
                    return
                }
                
                let enrollURL = baseURL + VerificationURLHelper.shared.getEnrolledURL(verificationType: VerificationTypes.TOUCH.rawValue)
                
                if #available(iOS 14.0, *) {
                    // Generate biometric proof JWT with attestation
                    BiometricProofSigner.createProofJWT(
                        httpMethod: "POST",
                        requestURL: enrollURL,
                        localizedReason: incomingData.localizedReason
                    ) { result in
                        switch result {
                        case .success(jwt: let attestationJWT):
                            incomingData.attestation = attestationJWT
                            self.enroll(verificationType: VerificationTypes.TOUCH.rawValue, incomingData: incomingData, callback: callback)
                        case .failure(error: let proofError):
                            let error = WebAuthError.shared
                            error.errorMessage = proofError.localizedDescription
                            error.errorCode = WebAuthErrorCode.TOUCHID_DEFAULT_ERROR.rawValue
                            self.sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
                        }
                    }
                } else {
                    // Fallback for iOS < 14: use regular biometric check without attestation
                    touchId.checkTouchIDMatching(localizedReason: incomingData.localizedReason, callback: { (res_success, res_errorMessage, res_errorCode) in
                        if res_success == true {
                            self.enroll(verificationType: VerificationTypes.TOUCH.rawValue, incomingData: incomingData, callback: callback)
                        } else {
                            let error = WebAuthError.shared
                            error.errorMessage = res_errorMessage ?? WebAuthError.shared.errorMessage
                            error.errorCode = res_errorCode ?? WebAuthError.shared.errorCode
                            self.sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
                        }
                    })
                }
            }
            else {
                // send response to presenter
                let error = WebAuthError.shared
                error.errorMessage = errorMessage ?? WebAuthError.shared.errorMessage
                error.errorCode = errorCode ?? WebAuthError.shared.errorCode
                
                self.sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
                return
            }
        }
    }
    
    public func askForTouchorFaceIdForAuthenticate(incomingData: AuthenticateRequest, callback: @escaping (Result<AuthenticateResponse>) -> Void) {
        // ask for touch id or face id with attestation
        let touchId = TouchID()
        touchId.checkIfTouchIdAvailable { (success, errorMessage, errorCode) in
            if success == true {
                // Get properties to construct URL for attestation
                guard let savedProp = self.getProperties(),
                      let baseURL = savedProp["DomainURL"] else {
                    let error = WebAuthError.shared.serviceFailureException(
                        errorCode: 417,
                        errorMessage: "properties cannot be empty",
                        statusCode: 417
                    )
                    self.sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
                    return
                }
                
                let authenticateURL = baseURL + VerificationURLHelper.shared.getAuthenticateURL(verificationType: VerificationTypes.TOUCH.rawValue)
                
                if #available(iOS 14.0, *) {
                    // Generate biometric proof JWT with attestation
                    BiometricProofSigner.createProofJWT(
                        httpMethod: "POST",
                        requestURL: authenticateURL,
                        localizedReason: incomingData.localizedReason
                    ) { result in
                        switch result {
                        case .success(jwt: let attestationJWT):
                            incomingData.attestation = attestationJWT
                            self.authenticate(verificationType: VerificationTypes.TOUCH.rawValue, incomingData: incomingData, callback: callback)
                        case .failure(error: let proofError):
                            let error = WebAuthError.shared
                            error.errorMessage = proofError.localizedDescription
                            error.errorCode = WebAuthErrorCode.TOUCHID_DEFAULT_ERROR.rawValue
                            self.sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
                        }
                    }
                } else {
                    // Fallback for iOS < 14: use regular biometric check without attestation
                    touchId.checkTouchIDMatching(localizedReason: incomingData.localizedReason, callback: { (res_success, res_errorMessage, res_errorCode) in
                        if res_success == true {
                            self.authenticate(verificationType: VerificationTypes.TOUCH.rawValue, incomingData: incomingData, callback: callback)
                        } else {
                            let error = WebAuthError.shared
                            error.errorMessage = res_errorMessage ?? WebAuthError.shared.errorMessage
                            error.errorCode = res_errorCode ?? WebAuthError.shared.errorCode
                            self.sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
                        }
                    })
                }
            }
            else {
                // send response to presenter
                let error = WebAuthError.shared
                error.errorMessage = errorMessage ?? WebAuthError.shared.errorMessage
                error.errorCode = errorCode ?? WebAuthError.shared.errorCode
                
                self.sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
                return
            }
        }
    }
    
    public func askForFacePhotoForEnroll(incomingData: EnrollRequest, callback: @escaping (Result<EnrollResponse>) -> Void) {
        FacePhotoCapture.capture { result in
            switch result {
            case .failure(let error):
                self.sharedPresenter.enroll(enrollResponse: nil, errorResponse: error, callback: callback)
            case .success(let photo):
                self.enroll(
                    verificationType: VerificationTypes.FACE.rawValue,
                    photo: photo,
                    voice: Data(),
                    incomingData: incomingData,
                    callback: callback
                )
            }
        }
    }

    public func askForFacePhotoForAuthenticate(incomingData: AuthenticateRequest, callback: @escaping (Result<AuthenticateResponse>) -> Void) {
        FacePhotoCapture.capture { result in
            switch result {
            case .failure(let error):
                self.sharedPresenter.authenticate(authenticateResponse: nil, errorResponse: error, callback: callback)
            case .success(let photo):
                self.authenticate(
                    verificationType: VerificationTypes.FACE.rawValue,
                    photo: photo,
                    voice: Data(),
                    incomingData: incomingData,
                    callback: callback
                )
            }
        }
    }

    public func continueMFA(passwordlessRequest: PasswordlessRequest, properties: Dictionary<String, String>, callback: @escaping (Result<LoginResponse>) -> Void) {
        self.passwordlessContinue(incomingData: passwordlessRequest) {
            switch $0 {
            case .success(let passwordlessContinueSuccessResponse):
                
                AccessTokenService.shared.getAccessToken(code: passwordlessContinueSuccessResponse.data.code, properties: properties) {
                    switch $0 {
                    case .success(let tokenSuccessResponse):
                        let loginResp = LoginResponse()
                        loginResp.success = true
                        loginResp.status = 200
                        loginResp.data = tokenSuccessResponse
                        let encoder = JSONEncoder()
                        do {
                            let data = try encoder.encode(loginResp)
                            let loginResponseString = String(data: data, encoding: .utf8)
                            self.sharedPresenter.login(loginResponse: loginResponseString, errorResponse: nil, callback: callback)
                        }
                        catch(let err) {
                            let error_resp = WebAuthError.shared
                            error_resp.errorCode = 500
                            error_resp.errorMessage = "JSON parsing error: \(err.localizedDescription)"
                            error_resp.statusCode = 500
                            
                            self.sharedPresenter.login(loginResponse: nil, errorResponse: error_resp, callback: callback)
                        }
                        break
                    case .failure(let tokenFailureResponse):
                        self.sharedPresenter.login(loginResponse: nil, errorResponse: tokenFailureResponse, callback: callback)
                        break
                    }
                }
                break
            case .failure(let passwordlessContinueFailureResponse):
                self.sharedPresenter.login(loginResponse: nil, errorResponse: passwordlessContinueFailureResponse, callback: callback)
                break
            }
        }
    }
    
    public func verify(verificationType: String, incomingData: AuthenticateRequest, callback: @escaping(Result<LoginResponse>) -> Void) {
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.login(loginResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        self.authenticate(verificationType: verificationType, incomingData: incomingData) {
            switch $0 {
            case .success(let authenticateSuccessResponse):
                if (incomingData.usage_type == UsageTypes.PASSWORDLESS.rawValue) {
                    let passwordlessRequest = PasswordlessRequest()
                    passwordlessRequest.requestId = incomingData.request_id
                    passwordlessRequest.status_id = authenticateSuccessResponse.data.status_id
                    passwordlessRequest.sub = incomingData.sub
                    passwordlessRequest.verificationType = verificationType
                    
                    self.continueMFA(passwordlessRequest: passwordlessRequest, properties: savedProp!, callback: callback)
                }
                break
            case .failure(let authenticateErrorResponse):
                self.sharedPresenter.login(loginResponse: nil, errorResponse: authenticateErrorResponse, callback: callback)
                break
            }

        }
    }
    
//    public func denyNotificationRequest(sub: String,statusId: String, rejectReason: denyReason, callback: @escaping(Result<LoginResponse>) -> Void) {
//        
//        print("running")
//        
//    }
    
    public func updateFCMToken(updateFCMRequest: UpdateFCMRequest, callback: @escaping (Result<UpdateFCMResponse>) -> Void) {
        
        // validation
        if (updateFCMRequest.push_id == "" || updateFCMRequest.client_id == "" || updateFCMRequest.device_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "push_id or client_id or device_id cannot be empty", statusCode: 417)
            
            sharedPresenter.updateFCMToken(fcmTokenResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.updateFCMToken(fcmTokenResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
            sharedService.updateFCMToken(incomingData: updateFCMRequest, properties: savedProp!) {response, error in
            self.sharedPresenter.updateFCMToken(fcmTokenResponse: response, errorResponse: error, callback: callback)
        }
        
    }
    
    public func getTimeLineDetails(incomingData: TimeLineRequest, callback: @escaping(Result<TimeLineDetailsResponse>) -> Void) {
        // validation
        if (incomingData.client_id == "" || incomingData.push_id == "" || incomingData.status_id == "" ) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "client_id or push_id or status_id cannot be empty", statusCode: 417)
            
            sharedPresenter.getTimeLineDetails(timeLineDetailsResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getTimeLineDetails(timeLineDetailsResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.getTimeLineDetails(incomingData: incomingData, properties: savedProp!) { response, error in
            self.sharedPresenter.getTimeLineDetails(timeLineDetailsResponse: response, errorResponse: error, callback: callback)
        }
       
    }
    
    
    public func getMFAConfiguredDeviceList(mfaConfiguredDeviceListRequest: MFAConfiguredDeviceListRequest, callback: @escaping(Result<MFAConfiguredDeviceListResponse>) -> Void) {
        
        // validation
        if (mfaConfiguredDeviceListRequest.client_id == "" || mfaConfiguredDeviceListRequest.push_id == "" || mfaConfiguredDeviceListRequest.sub.count == 0 ) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "client_id or push_id or sub cannot be empty", statusCode: 417)
            
            sharedPresenter.getMFAConfiguredDeviceList(mfaConfiguredDeviceListResponse: nil, errorResponse: error, callback: callback)
           return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getMFAConfiguredDeviceList(mfaConfiguredDeviceListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.getMFAConfiguredDeviceList(incomingData: mfaConfiguredDeviceListRequest, properties: savedProp!) {
            response, error in
            self.sharedPresenter.getMFAConfiguredDeviceList(mfaConfiguredDeviceListResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    
    public func deleteDevice(deleteDeviceRequest: DeleteDeviceRequest, callback: @escaping(Result<DeleteResponse>) -> Void) {
        
        // validation
        if (deleteDeviceRequest.client_id == "" || deleteDeviceRequest.push_id == "" || deleteDeviceRequest.sub == "" || deleteDeviceRequest.device_id == "" ) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "client_id or push_id or sub or device_id cannot be empty", statusCode: 417)
            
            sharedPresenter.deleteDevice(deleteDeviceResponse: nil, errorResponse: error, callback: callback)
           return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.deleteDevice(deleteDeviceResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.deleteDevice(incomingData: deleteDeviceRequest, properties: savedProp!) {
            response, error in
            self.sharedPresenter.deleteDevice(deleteDeviceResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func getDeviceConfiguredList(mfaListRequest: MFAListRequest, callback: @escaping(Result<MFAListResponse>) -> Void) {
        
        // validation — linked_device_id is optional (only when querying another device)
        if (mfaListRequest.client_id == "" || mfaListRequest.push_id == "" || mfaListRequest.sub == "" || mfaListRequest.device_id == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "client_id or push_id or sub or device_id cannot be empty", statusCode: 417)
            
            sharedPresenter.getDeviceConfiguredList(deviceConfiguredListResponse: nil, errorResponse: error, callback: callback)
           return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.getDeviceConfiguredList(deviceConfiguredListResponse: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
            sharedService.getDeviceConfiguredList(incomingData: mfaListRequest, properties: savedProp!) {
            response, error in
            self.sharedPresenter.getDeviceConfiguredList(deviceConfiguredListResponse: response, errorResponse: error, callback: callback)
        }
    }
    
    public func cancelAuthentication(verificationType: String, cancelAuthenticationRequest: CancelExchangeRequest,callback: @escaping(Result<CancelAuthenticationResponse>) -> Void) {
        
        // validation
        if (cancelAuthenticationRequest.exchange_id == "" || cancelAuthenticationRequest.reason == "") {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "exchange_id or reason cannot be empty", statusCode: 417)
            
            sharedPresenter.cancelAuthentication(cancelAuthenticationResult: nil, errorResponse: error, callback: callback)
           return
        }
        
        // get saved properties
        let savedProp = getProperties()
        if (savedProp == nil) {
            // send response to presenter
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "properties cannot be empty", statusCode: 417)
            sharedPresenter.cancelAuthentication(cancelAuthenticationResult: nil, errorResponse: error, callback: callback)
            return
        }
        
        // call worker
        sharedService.cancelAuthentication(verificationType: verificationType, incomingData: cancelAuthenticationRequest, properties: savedProp!) {
            response, error in
            self.sharedPresenter.cancelAuthentication(cancelAuthenticationResult: response, errorResponse: error, callback: callback)
        }
    }

    public func cancelEnrollmentSetup(
        verificationType: String,
        cancelSetupRequest: CancelExchangeRequest,
        callback: @escaping (Result<EnrollResponse>) -> Void
    ) {
        if cancelSetupRequest.exchange_id == "" || cancelSetupRequest.reason == "" {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "exchange_id or reason cannot be empty",
                statusCode: 417
            )
            sharedPresenter.cancelEnrollmentSetup(cancelSetupResult: nil, errorResponse: error, callback: callback)
            return
        }

        let savedProp = getProperties()
        if savedProp == nil {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "properties cannot be empty",
                statusCode: 417
            )
            sharedPresenter.cancelEnrollmentSetup(cancelSetupResult: nil, errorResponse: error, callback: callback)
            return
        }

        sharedService.cancelEnrollmentSetup(
            verificationType: verificationType,
            incomingData: cancelSetupRequest,
            properties: savedProp!
        ) { response, error in
            self.sharedPresenter.cancelEnrollmentSetup(
                cancelSetupResult: response,
                errorResponse: error,
                callback: callback
            )
        }
    }

}
