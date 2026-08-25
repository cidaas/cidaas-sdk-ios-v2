//
//  VerificationServiceWorker.swift
//  Cidaas
//
//  Created by ganesh on 06/05/19.
//

import Foundation
import Alamofire
import UIKit

public class VerificationServiceWorker {
    
    public static var shared : VerificationServiceWorker = VerificationServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: VerificationURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = VerificationURLHelper.shared
    }
    
    public func setup(verificationType: String, incomingData: SetupRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getSetupURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        var headers: [String: String] = [String: String]()
        headers["access_token"] = incomingData.access_token
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, extraheaders: headers, callback: callback)
    }
    
    public func scanned(verificationType: String, incomingData: ScannedRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getScannedURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func enroll(verificationType: String, photo: UIImage, voice: Data, incomingData: EnrollRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getEnrolledURL(verificationType: verificationType)
        
        // construct body params
        var bodyParamsDefault = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParamsDefault = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        // construct body params for FACE & VOICE
        var bodyParams = Dictionary<String, String>()
        bodyParams["push_id"] = incomingData.push_id
        bodyParams["device_id"] = incomingData.device_id
        bodyParams["exchange_id"] = incomingData.exchange_id
        bodyParams["client_id"] = incomingData.client_id
        bodyParams["attempt"] = String(describing: incomingData.attempt)
        
        let enrolledURL = try! URLRequest(url: URL(string: urlString)!, method: .post, headers: nil)
        
        switch verificationType {
        case VerificationTypes.FACE.rawValue:
            sharedSession.uploadPhoto(url: enrolledURL, parameters: bodyParams, photo: photo, callback: callback)
            break
        case VerificationTypes.VOICE.rawValue:
            sharedSession.uploadAudio(url: enrolledURL, parameters: bodyParams, voice: voice, callback: callback)
            break
        default:
            sharedSession.startSession(url: urlString, method: .post, parameters: bodyParamsDefault, callback: callback)
            break
        }
    }
    
    public func initiate(verificationType: String, incomingData: InitiateRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getInitiateURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }

        guard let cookieHeaders = SDKDeviceIdResolver.cidaasDrCookieHeaders() else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "deviceId missing for cidaas_dr Cookie",
                statusCode: 417
            ))
            return
        }

        sharedSession.startSession(
            url: urlString,
            method: .post,
            parameters: bodyParams,
            extraheaders: cookieHeaders,
            callback: callback
        )
    }
    
    public func pushAcknowledge(verificationType: String, incomingData: PushAcknowledgeRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getPushAcknowledgeURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func pushAllow(verificationType: String, incomingData: PushAllowRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getPushAllowURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func pushReject(verificationType: String, incomingData: PushRejectRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getPushRejectURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func authenticate(verificationType: String, photo: UIImage, voice: Data, incomingData: AuthenticateRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getAuthenticateURL(verificationType: verificationType)
        
        // construct body params
        var bodyParamsDefault = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParamsDefault = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }

        guard let cookieHeaders = SDKDeviceIdResolver.cidaasDrCookieHeaders() else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "deviceId missing for cidaas_dr Cookie",
                statusCode: 417
            ))
            return
        }
        
        // construct body params for FACE & VOICE
        var bodyParams = Dictionary<String, String>()
        bodyParams["push_id"] = incomingData.push_id
        bodyParams["device_id"] = incomingData.device_id
        bodyParams["exchange_id"] = incomingData.exchange_id
        bodyParams["client_id"] = incomingData.client_id
        
        var enrolledURL = try! URLRequest(url: URL(string: urlString)!, method: .post, headers: nil)
        for (key, value) in cookieHeaders {
            enrolledURL.setValue(value, forHTTPHeaderField: key)
        }
        enrolledURL.httpShouldHandleCookies = false
        
        switch verificationType {
        case VerificationTypes.FACE.rawValue:
            sharedSession.uploadPhoto(url: enrolledURL, parameters: bodyParams, photo: photo, callback: callback)
            break
        case VerificationTypes.VOICE.rawValue:
            sharedSession.uploadAudio(url: enrolledURL, parameters: bodyParams, voice: voice, callback: callback)
            break
        default:
            sharedSession.startSession(
                url: urlString,
                method: .post,
                parameters: bodyParamsDefault,
                extraheaders: cookieHeaders,
                callback: callback
            )
            break
        }
    }
    
    public func deleteAll(incomingData: DeleteRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        
        // construct device details
        let deviceInfo = DBHelper.shared.getDeviceInfo()
        
        // construct scanned url
        urlString = baseURL + sharedURL.getDeleteAllURL(deviceId: deviceInfo.deviceId)
        
        sharedSession.startSession(url: urlString, method: .delete, parameters: bodyParams, callback: callback)
    }
    
    public func delete(incomingData: DeleteRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getDeleteURL(verificationType: incomingData.verificationType, sub: incomingData.sub)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .delete, parameters: bodyParams, callback: callback)
    }
    
    public func getConfiguredList(incomingData: MFAListRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getConfiguredListURL()
        
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func getPendingNotificationList(incomingData: PendingNotificationRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getPendingNotificationListURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func getMFAHistoryList(incomingData: MFAHistoryRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getMFAHistoryURL()

        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func updateFCM(incomingData: UpdateFCMRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        incomingData.client_id = (properties["ClientId"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getUpdateFCMURL()
        
        DBHelper.shared.setFCM(fcmToken: incomingData.push_id)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .put, parameters: bodyParams, callback: callback)
    }
    
    public func passwordlessContinue(incomingData: PasswordlessRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct scanned url
        urlString = baseURL + sharedURL.getPasswordlessContinueURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func updateFCMToken(incomingData: UpdateFCMRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getUpdateFCMURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .put, parameters: bodyParams, callback: callback)
    }
    
    public func getTimeLineDetails(incomingData: TimeLineRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getTimeLineURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func getMFAConfiguredDeviceList(incomingData: MFAConfiguredDeviceListRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getListURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func deleteDevice(incomingData: DeleteDeviceRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getDeleteDeviceURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .delete, parameters: bodyParams, callback: callback)
    }
    
    public func getDeviceConfiguredList(incomingData: MFAListRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getConfiguredListURL()
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    public func cancelAuthentication(verificationType: String,incomingData: CancelExchangeRequest, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlString : String
        
        // assign base url
        let baseURL = (properties["DomainURL"])!
        
        // construct url
        urlString = baseURL + sharedURL.getCancelURL(verificationType: verificationType)
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }

    public func cancelEnrollmentSetup(
        verificationType: String,
        incomingData: CancelExchangeRequest,
        properties: Dictionary<String, String>,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        let baseURL = (properties["DomainURL"])!
        let urlString = baseURL + sharedURL.getCancelSetupURL(verificationType: verificationType)

        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        } catch (_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }

        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
}
