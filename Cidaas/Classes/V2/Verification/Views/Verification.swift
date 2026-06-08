//
//  Verification.swift
//  Cidaas
//
//  Created by ganesh on 10/05/19.
//

import Foundation
import UIKit

public class CidaasVerification {
    
    public static var shared: CidaasVerification = CidaasVerification()
    var sharedViewController: VerificationViewController
    
    public init() {
        sharedViewController = VerificationViewController.shared
    }
    
    public func setup(verificationType: String, setupRequest: SetupRequest, callback:@escaping (Result<SetupResponse>) -> Void) {
        sharedViewController.setup(verificationType: verificationType, incomingData: setupRequest, callback: callback)
    }
    
    public func scanned(verificationType: String, scannedRequest: ScannedRequest, callback:@escaping (Result<ScannedResponse>) -> Void) {
        sharedViewController.scanned(verificationType: verificationType, incomingData: scannedRequest, callback: callback)
    }
    
    public func enroll(verificationType: String, photo: UIImage = UIImage(), voice: Data = Data(), enrollRequest: EnrollRequest, callback:@escaping (Result<EnrollResponse>) -> Void) {
        sharedViewController.enroll(verificationType: verificationType, photo: photo, voice: voice, incomingData: enrollRequest, callback: callback)
    }
    
    public func pushAcknowledge(verificationType: String, pushAckRequest: PushAcknowledgeRequest, callback:@escaping (Result<PushAcknowledgeResponse>) -> Void) {
        sharedViewController.pushAcknowledge(verificationType: verificationType, incomingData: pushAckRequest, callback: callback)
    }
    
    public func pushAllow(verificationType: String, pushAllowRequest: PushAllowRequest, callback:@escaping (Result<PushAllowResponse>) -> Void) {
        sharedViewController.pushAllow(verificationType: verificationType, incomingData: pushAllowRequest, callback: callback)
    }
    
    public func pushReject(verificationType: String, pushRejectRequest: PushRejectRequest, callback:@escaping (Result<PushRejectResponse>) -> Void) {
        sharedViewController.pushReject(verificationType: verificationType, incomingData: pushRejectRequest, callback: callback)
    }
    
    public func authenticate(verificationType: String, photo: UIImage = UIImage(), voice: Data = Data(), authenticateRequest: AuthenticateRequest, callback:@escaping (Result<AuthenticateResponse>) -> Void) {
        sharedViewController.authenticate(verificationType: verificationType, photo: photo, voice: voice, incomingData: authenticateRequest, callback: callback)
    }
    
    public func deleteAll(deleteRequest: DeleteRequest, callback:@escaping (Result<DeleteResponse>) -> Void) {
        sharedViewController.deleteAll(incomingData: deleteRequest, callback: callback)
    }
    
    public func delete(deleteRequest: DeleteRequest, callback:@escaping (Result<DeleteResponse>) -> Void) {
        sharedViewController.delete(incomingData: deleteRequest, callback: callback)
    }
    
    public func getConfiguredList(mfaListRequest: MFAListRequest, callback:@escaping (Result<MFAListResponse>) -> Void) {
        sharedViewController.getConfiguredList(incomingData: mfaListRequest, callback: callback)
    }
    
    public func getPendingNotificationList(pendingNotificationRequest: PendingNotificationRequest, callback:@escaping (Result<PendingNotificationResponse>) -> Void) {
        sharedViewController.getPendingNotificationList(incomingData: pendingNotificationRequest, callback: callback)
    }
    
    public func getMFAHistoryList(mfaHistoryRequest: MFAHistoryRequest, callback:@escaping (Result<MFAHistoryResponse>) -> Void) {
        sharedViewController.getMFAHistoryList(incomingData: mfaHistoryRequest, callback: callback)
    }
    
    public func updateFCM(push_id: String) {
        sharedViewController.updateFCM(push_id: push_id)
    }
    
    public func configure(configureRequest: ConfigureRequest, photo: UIImage = UIImage(), voice: Data = Data(), callback: @escaping(Result<EnrollResponse>) -> Void) {
        sharedViewController.configure(incomingData: configureRequest, photo: photo, voice: voice, callback: callback)
    }
    
    public func login(loginRequest: LoginRequest, photo: UIImage = UIImage(), voice: Data = Data(), callback: @escaping(Result<LoginResponse>) -> Void) {
        sharedViewController.login(incomingData: loginRequest, photo: photo, voice: voice, callback: callback)
    }
    
    public func initiate(verificationType: String, initiateRequest: InitiateRequest, callback:@escaping (Result<InitiateResponse>) -> Void) {
        sharedViewController.initiate(verificationType: verificationType, incomingData: initiateRequest, callback: callback)
    }
    
    public func verify(verificationType: String, authenticateRequest: AuthenticateRequest, callback:@escaping (Result<LoginResponse>) -> Void) {
        sharedViewController.verify(verificationType: verificationType, incomingData: authenticateRequest, callback: callback)
    }
    
//    public func denyNotificationRequest(sub: String, statusId: String, rejectReason: denyReason, callback: @escaping (Result<DenyNotif>) -> Void) {
//        sharedViewController.denyNotificationRequest(push_id: push_id)
//    }
    
    public func updateFCMToken(updateFCMRequest: UpdateFCMRequest, callback: @escaping (Result<UpdateFCMResponse>) -> Void) {
        sharedViewController.updateFCMToken(updateFCMRequest: updateFCMRequest, callback: callback)
     }
    
    public func getTimelineDetails(timeLineRequest: TimeLineRequest, callback: @escaping (Result<TimeLineDetailsResponse>) -> Void) {
        sharedViewController.getTimeLineDetails(timeLineRequest: timeLineRequest, callback: callback)
    }
    
    public func getMfaConfigureDeviceList(mfaConfiguredDeviceListRequest: MFAConfiguredDeviceListRequest, callback: @escaping (Result<MFAConfiguredDeviceListResponse>) -> Void) {
        sharedViewController.getMFAConfiguredDeviceList(mfaConfiguredDeviceListRequest: mfaConfiguredDeviceListRequest, callback: callback)
    }
    
    public func deleteDevice(deleteRequest: DeleteDeviceRequest, callback: @escaping (Result<DeleteResponse>) -> Void) {
        sharedViewController.deleteDevice(deleteRequest: deleteRequest, callback: callback)
    }
    
    public func getDeviceConfiguredList(mfaListRequest: MFAListRequest, callback: @escaping (Result<MFAListResponse>) -> Void) {
        sharedViewController.getDeviceConfiguredList(mfaListRequest: mfaListRequest, callback: callback)
    }
    
    public func cancelAuthentication(verificationType: String, cancelAuthenticationRequest: CancelExchangeRequest,callback: @escaping (Result<CancelAuthenticationResponse>) -> Void) {
        sharedViewController.cancelAuthentication(verificationType: verificationType, cancelAuthenticationRequest: cancelAuthenticationRequest, callback: callback)
    }

    public func cancelEnrollmentSetup(
        verificationType: String,
        cancelSetupRequest: CancelExchangeRequest,
        callback: @escaping (Result<EnrollResponse>) -> Void
    ) {
        sharedViewController.cancelEnrollmentSetup(
            verificationType: verificationType,
            cancelSetupRequest: cancelSetupRequest,
            callback: callback
        )
    }
}
