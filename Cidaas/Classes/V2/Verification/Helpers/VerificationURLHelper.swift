//
//  VerificationURLHelper.swift
//  Cidaas
//
//  Created by ganesh on 06/05/19.
//

import Foundation

public class VerificationURLHelper {
    
    public static var shared : VerificationURLHelper = VerificationURLHelper()
    
    
    public var setupURL: String = "/verification-actions-srv/setup/"
    public var scannedURL: String = "/verification-actions-srv/setup/"
    public var enrolledURL: String = "/verification-actions-srv/setup/"

    public var initiateURL: String = "/verification-srv/authentication/"
    public var cancelURL: String = "/verification-srv/authentication/"
    public var pushAckURL: String = "/verification-srv/authentication/"
    public var pushAllowURL: String = "/verification-srv/authentication/"
    public var pushRejectURL: String = "/verification-srv/authentication/"
    public var authenticateURL: String = "/verification-srv/authentication/"

    public var deleteAllURL: String = "/verification-actions-srv/setup/devices/"
    public var deleteURL: String = "/verification-actions-srv/setup/devices/"
    public var configuredListURL: String = "/verification-actions-srv/setup/devices/"
    public var pendingNotificationListURL: String = "/verification-actions-srv/setup/devices/notifications"
    public var fcmURL: String = "/verification-actions-srv/setup/devices/"

    public var mfaHistoryURL: String = "/verification-actions-srv/mfa/history"
    public var timeLineURL: String = "/verification-actions-srv/mfa/timeline"

    public var passwordlessContinueURL: String = "/login-srv/verification/sdk/login"

    public var unlinkURL: String = "/verification-actions-srv/devices/"
    public var listURL: String = "/verification-actions-srv/devices/"

    public var deviceRegistrationInitiationURL: String = "/verification-actions-srv/devices/registration/initiation"
    public var deviceRegistrationVerificationURL: String = "/verification-actions-srv/devices/registration/verification"
    
    public func getSetupURL(verificationType: String) -> String {
        return setupURL + verificationType + "/initiation"
    }
    
    public func getScannedURL(verificationType: String) -> String {
        return scannedURL + verificationType + "/scan"
    }
    
    public func getEnrolledURL(verificationType: String) -> String {
        return enrolledURL + verificationType + "/verification"
    }
    
    public func getInitiateURL(verificationType: String) -> String {
        return initiateURL + verificationType + "/initiation"
    }

    public func getCancelURL(verificationType: String) -> String {
        return cancelURL + verificationType + "/cancel"
    }

    public func getCancelSetupURL(verificationType: String) -> String {
        return setupURL + verificationType + "/cancellation"
    }
    
    public func getPushAcknowledgeURL(verificationType: String) -> String {
        return pushAckURL + verificationType + "/push/acknowledge"
    }
    
    public func getPushAllowURL(verificationType: String) -> String {
        return pushAllowURL + verificationType + "/allow"
    }
    
    public func getPushRejectURL(verificationType: String) -> String {
        return pushRejectURL + verificationType + "/deny"
    }
    
    public func getAuthenticateURL(verificationType: String) -> String {
        return authenticateURL + verificationType + "/verification"
    }
    
    public func getDeleteAllURL(deviceId: String) -> String {
        return deleteAllURL + deviceId
    }
    
    public func getDeleteURL(verificationType: String, sub: String) -> String {
        return deleteURL + verificationType + "/" + sub
    }
    
    public func getConfiguredListURL() -> String {
        return configuredListURL
    }
    
    public func getPendingNotificationListURL() -> String {
        return pendingNotificationListURL
    }
    
    public func getMFAHistoryURL() -> String {
        return mfaHistoryURL
    }
    
    public func getPasswordlessContinueURL() -> String {
        return passwordlessContinueURL
    }
    
    public func getUpdateFCMURL() -> String {
        return fcmURL
    }
    
    public func getTimeLineURL() -> String {
        return timeLineURL
    }
    
    public func getDeleteDeviceURL() -> String {
        return unlinkURL
    }
    
    public func getListURL() -> String {
        return listURL
    }

   public func getDeviceRegistrationInitiationURL() -> String {
        return deviceRegistrationInitiationURL
    }

    public func getDeviceRegistrationVerificationURL() -> String {
        return deviceRegistrationVerificationURL
    }
}
