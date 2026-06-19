//
//  SessionManager.swift
//  Cidaas
//
//  Created by Ganesh on 11/05/20.
//

import Foundation
import Alamofire
import UIKit

public class SessionManager {
    
    public static var shared : SessionManager = SessionManager()
    public var headers: HTTPHeaders
    public var session: Session
    var deviceInfo: DeviceInfoModel
    var push_id: String

    private var publicKeyPinningOptions: CidaasPublicKeyPinningOptions?
    private let sessionLock = NSLock()

    public init() {
        deviceInfo = DBHelper.shared.getDeviceInfo()
        push_id = DBHelper.shared.getFCM()
        headers = Self.makeDefaultHeaders(deviceInfo: deviceInfo)
        session = Self.makeSession(headers: headers, pinningOptions: nil)
    }

    func setPublicKeyPinning(_ options: CidaasPublicKeyPinningOptions?) {
        sessionLock.lock()
        publicKeyPinningOptions = options
        session = Self.makeSession(headers: headers, pinningOptions: options)
        sessionLock.unlock()
    }

    private static func makeDefaultHeaders(deviceInfo: DeviceInfoModel) -> HTTPHeaders {
        let location = DBHelper.shared.getLocation()
        var headers = AF.session.configuration.headers
        headers["User-Agent"] = CidaasUserAgentBuilder.shared.UAString()
        headers["lat"] = location.0
        headers["lon"] = location.1
        headers["deviceId"] = deviceInfo.deviceId
        headers["deviceMake"] = deviceInfo.deviceMake
        headers["deviceModel"] = deviceInfo.deviceModel
        headers["deviceVersion"] = deviceInfo.deviceVersion
        return headers
    }

    private static func logNetworkRequest(url: String, headers: HTTPHeaders, bodyParams: [String: Any]?) {
        guard DBHelper.shared.getEnableLog() else { return }
        logw("HTTP \(url)", cname: "cidaas-sdk-network-log")
        logw("Headers: \(headers)", cname: "cidaas-sdk-network-log")
        if let bodyParams {
            logw("Payload: \(bodyParams)", cname: "cidaas-sdk-network-log")
        }
    }

    private static func makeSession(
        headers: HTTPHeaders,
        pinningOptions: CidaasPublicKeyPinningOptions?
    ) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.headers = headers
        let serverTrustManager = pinningOptions.flatMap { CidaasCertificatePinning.makeServerTrustManager(options: $0) }
        if let serverTrustManager {
            return Session(configuration: configuration, serverTrustManager: serverTrustManager)
        }
        return Session(configuration: configuration)
    }
    
    func startSession(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        extraheaders: [String: String] = [String: String](),
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        
        var bodyParams = parameters
        
        // assign device_id value if it is empty
        if bodyParams != nil && (bodyParams?["device_id"] as? String == "") {
            bodyParams!["device_id"] = deviceInfo.deviceId
        }
        
        // assign push_id value if it is empty
        if bodyParams != nil && (bodyParams?["push_id"] as? String == "") {
            bodyParams!["push_id"] = DBHelper.shared.getFCM()
        }
        
        var requestHeaders = headers
        if CidaasHTTPProofToken.shouldSendDpopHeader(for: url), #available(iOS 14.0, *) {
            if let dpopHeaders = try? CidaasHTTPProof.dpopProofHeader(
                urlString: url,
                httpMethod: method.rawValue
            ) {
                for (key, value) in dpopHeaders where extraheaders[key] == nil {
                    requestHeaders[key] = value
                }
            }
        }
        for (key, value) in extraheaders {
            requestHeaders[key] = value
        }
        if let locale = bodyParams?["locale"] as? String {
            requestHeaders["Accept-Language"] = locale
        }

        Self.logNetworkRequest(url: url, headers: requestHeaders, bodyParams: bodyParams)

        session.request(url, method: method, parameters: bodyParams, encoding: JSONEncoding.default, headers: requestHeaders)
            .redirect(using: Redirector.doNotFollow)
            .validate(statusCode: 200..<303)
            .responseString(encoding: .utf8, emptyResponseCodes: Set([204, 205, 302])) { response in
                self.responseRedirect(response: response, callback: callback)
            }
    }

    func uploadPhoto(url: URLRequest, parameters: [String: String], photo: UIImage, callback: @escaping (String?, WebAuthError?) -> Void) {
        guard let uploadImage = photo.jpegData(compressionQuality: 0.8) else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "Photo is required for face verification",
                statusCode: 417
            ))
            return
        }
        var urlReq: URLRequest = url
        session.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                guard let data = value.data(using: .utf8) else { continue }
                multipartFormData.append(data, withName: key)
            }
            multipartFormData.append(uploadImage, withName: "photo", fileName: "photo.jpg", mimeType: "image/jpeg")
            urlReq.addValue(multipartFormData.contentType, forHTTPHeaderField: "Content-Type")
        }, with: urlReq)
        .responseString(completionHandler: { data in
            self.responseRedirect(response: data, callback: callback)
        })
    }
    
    func uploadAudio(url: URLRequest, parameters: [String: String], voice: Data, callback: @escaping (String?, WebAuthError?) -> Void) {
        var urlReq: URLRequest = url
        session.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
            multipartFormData.append(voice, withName: "voice", fileName: "voice.wav", mimeType: "audio/mpeg")
            urlReq.addValue(multipartFormData.contentType, forHTTPHeaderField: "Content-Type")
        }, with: urlReq)
        .responseString(completionHandler: { data in
            self.responseRedirect(response: data, callback: callback)
        })
    }
    
    func responseRedirect(response: AFDataResponse<String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        switch response.result {
        case .success(let value):
            if (response.response?.statusCode == 200) {
                callback(value, nil)
                return
            }
            if (response.response?.statusCode == 204) {
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 204, errorMessage: "No data found", statusCode: response.response?.statusCode ?? 400))
                return
            }
            if response.response?.statusCode == 302 {
                let loc = response.response?.headers.value(for: "Location")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if loc.isEmpty {
                    callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 302, errorMessage: "302 without Location header", statusCode: 302))
                } else {
                    callback(loc, nil)
                }
                return
            }
            else if response.data != nil {
                var dataResponse = String(decoding: response.data!, as: UTF8.self)
                let errorData = extractErrorResponseData(from: dataResponse)
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: errorData.errorCode, errorMessage: errorData.errorMessage ?? "", statusCode: response.response?.statusCode ?? 400))
            }
            else {
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: response.description, statusCode: response.response?.statusCode ?? 400))
            }
            
            break
        case .failure(let error):
            if response.response?.statusCode == 302 {
                let loc = response.response?.headers.value(for: "Location")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !loc.isEmpty {
                    callback(loc, nil)
                    return
                }
            }
            if error._domain == NSURLErrorDomain {
                // return failure
                callback(nil, WebAuthError.shared.netWorkTimeoutException())
                return
            }
            if response.data != nil {
                var dataResponse = String(decoding: response.data!, as: UTF8.self)
                let errorData = extractErrorResponseData(from: dataResponse)
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: errorData.errorCode, errorMessage: errorData.errorMessage ?? "", statusCode: response.response?.statusCode ?? 400))
            }
            else {
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 500, errorMessage: error.localizedDescription, statusCode: response.response?.statusCode ?? 400))
            }
            break
        }
    }
    
    public func string2error(string: String) -> ErrorResponseEntity {
        let decoder = JSONDecoder()
        do {
            let data = string.data(using: .utf8)!
            // decode the json data to object
            let errorResponseEntity = try decoder.decode(ErrorResponseEntity.self, from: data)
            
            // return failure
            return errorResponseEntity
        }
        catch( _) {
            // return failure
            let errorResponseEntity = ErrorResponseEntity()
            errorResponseEntity.success = false
            errorResponseEntity.status = 400
            return errorResponseEntity
        }
    }
}


// Function to extract value dynamically for one level or two levels deep
func getDynamicValue(from json: [String: Any], keys: [String]) -> Any? {
    for key in keys {
        let keyComponents = key.split(separator: ".").map { String($0) }
        var currentObject: Any? = json
        
        for component in keyComponents {
            if let dictionary = currentObject as? [String: Any] {
                currentObject = dictionary[component]
            } else {
                currentObject = nil
                break
            }
        }
        
        // If a valid value is found for the current key path, return it
        if currentObject != nil {
            return currentObject
        }
    }
    return nil
}

// Function to parse JSON string and extract both errorCode and errorMessage
func extractErrorResponseData(from jsonString: String) -> (errorCode: String?, errorMessage: String?) {
    var errorCode: String = ""
    var errorMessage: String = ""
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                
                // List of possible key paths for errorCode
                let possibleErrorCodeKeyPaths = ["code", "error.code"]
                
                // Get errorCode and convert it to String if possible
                if let value = getDynamicValue(from: jsonObject, keys: possibleErrorCodeKeyPaths) {
                    if let stringValue = value as? String {
                        errorCode = stringValue
                    } else if let intValue = value as? Int {
                        errorCode = String(intValue)
                    }
                }
                
                // Handle errorMessage for both single-level and nested "error" keys
                if let errorValue = jsonObject["error"] {
                    if let errorString = errorValue as? String {
                        // Case 1: "error" is a string
                        errorMessage = errorString
                    } else if let errorDict = errorValue as? [String: Any], let nestedError = errorDict["error"] as? String {
                        // Case 2: "error" is a dictionary with an inner "error" string
                        errorMessage = nestedError
                    }
                }
            }
        } catch {
            if DBHelper.shared.getEnableLog() {
                logw("Error parsing JSON: \(error.localizedDescription)", cname: "cidaas-sdk-network-log")
            }
        }
    }
    
    return (errorCode, errorMessage)
}
