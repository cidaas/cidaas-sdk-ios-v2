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

    private static let networkLogSeparator = String(repeating: "─", count: 56)

    private static func logNetworkRequest(
        url: String,
        method: String,
        headers: HTTPHeaders,
        bodyParams: [String: Any]?
    ) {
        guard DBHelper.shared.getEnableLog() else { return }
        let cname = "cidaas-sdk-network-log"
        logw(networkLogSeparator, cname: cname)
        logw("→ REQUEST  \(method.uppercased()) \(url)", cname: cname)
        logw("  Headers:", cname: cname)
        for header in headers {
            logw("    \(header.name): \(truncatedHeaderValue(header.name, header.value))", cname: cname)
        }
        if let bodyParams {
            logw("  Body:", cname: cname)
            logw("    \(prettyJSONObject(bodyParams))", cname: cname)
        } else {
            logw("  Body: <none>", cname: cname)
        }
    }

    private static func responseRefNumber(from response: HTTPURLResponse?) -> String? {
        guard let response else { return nil }
        for (key, value) in response.allHeaderFields {
            guard let keyString = key as? String else { continue }
            let normalized = keyString.lowercased().replacingOccurrences(of: "-", with: "_")
            if normalized == "x_ref_number",
               let ref = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ref.isEmpty {
                return ref
            }
        }
        return nil
    }

    private static func truncatedBodyPreview(_ body: String?, limit: Int = 2000) -> String {
        guard let body else { return "<empty>" }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "<empty>" }
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

    /// Shorten long values; always redact sensitive auth/proof headers regardless of length.
    private static func truncatedHeaderValue(_ name: String, _ value: String, limit: Int = 96) -> String {
        let lower = name.lowercased()
        let isSensitive = lower == "dpop"
            || lower == "authorization"
            || lower == "cookie"
        guard value.count > limit || isSensitive else { return value }
        let previewLimit = isSensitive ? min(limit, 24) : limit
        if value.count <= previewLimit {
            return "<redacted \(lower), \(value.count) chars>"
        }
        return String(value.prefix(previewLimit)) + "… (\(value.count) chars)"
    }

    private static func prettyJSONObject(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return truncatedBodyPreview(String(describing: object))
        }
        return truncatedBodyPreview(text.replacingOccurrences(of: "\n", with: "\n    "))
    }

    private static func prettyJSONString(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8) else {
            return truncatedBodyPreview(trimmed)
        }
        return truncatedBodyPreview(text.replacingOccurrences(of: "\n", with: "\n    "))
    }

    private static func logNetworkResponse(_ response: AFDataResponse<String>) {
        guard DBHelper.shared.getEnableLog() else { return }
        let cname = "cidaas-sdk-network-log"
        let url = response.request?.url?.absoluteString ?? "<unknown url>"
        let method = response.request?.httpMethod ?? "—"
        let status = response.response.map { String($0.statusCode) } ?? "—"
        let refNumber = responseRefNumber(from: response.response) ?? "<missing>"
        logw("← RESPONSE \(status) \(method) \(url)", cname: cname)
        logw("  x_ref_number: \(refNumber)", cname: cname)
        switch response.result {
        case .success(let body):
            logw("  Body:", cname: cname)
            logw("    \(prettyJSONString(body))", cname: cname)
        case .failure(let error):
            logw("  Error: \(error.localizedDescription)", cname: cname)
            if let data = response.data, !data.isEmpty {
                let body = String(decoding: data, as: UTF8.self)
                logw("  Body:", cname: cname)
                logw("    \(prettyJSONString(body))", cname: cname)
            }
        }
        logw(networkLogSeparator, cname: cname)
        logw("", cname: cname)
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
        encoding: ParameterEncoding = JSONEncoding.default,
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
        Self.mergeDpopHeaderIfNeeded(
            into: &requestHeaders,
            urlString: url,
            httpMethod: method.rawValue,
            extraheaders: extraheaders
        )
        for (key, value) in extraheaders {
            requestHeaders[key] = value
        }
        // Form body for PAR; do not override an explicit caller Content-Type
        if encoding is URLEncoding {
            let callerSetContentType = extraheaders.keys.contains {
                $0.caseInsensitiveCompare("Content-Type") == .orderedSame
            }
            if !callerSetContentType {
                requestHeaders["Content-Type"] = "application/x-www-form-urlencoded"
            }
        }
        if let locale = bodyParams?["locale"] as? String {
            requestHeaders["Accept-Language"] = locale
        }

        Self.logNetworkRequest(
            url: url,
            method: method.rawValue,
            headers: requestHeaders,
            bodyParams: bodyParams
        )

        // Manual `Cookie` headers must not compete with URLSession cookie storage.
        let hasManualCookie = extraheaders.keys.contains {
            $0.caseInsensitiveCompare("Cookie") == .orderedSame
        }

        session.request(
            url,
            method: method,
            parameters: bodyParams,
            encoding: encoding,
            headers: requestHeaders
        ) { urlRequest in
            if hasManualCookie {
                urlRequest.httpShouldHandleCookies = false
            }
        }
            .redirect(using: Redirector.doNotFollow)
            .validate(statusCode: 200..<303)
            .responseString(encoding: .utf8, emptyResponseCodes: Set([204, 205, 302])) { response in
                self.responseRedirect(response: response, callback: callback)
            }
    }

    /// Single place: attach a fresh `DPoP` proof when ``Cidaas/ENABLE_DPOP`` is on or the session is DPoP-bound.
    /// Includes RFC 9449 `ath` when an access token is present on the request (never on bare `/token` calls).
    private static func mergeDpopHeaderIfNeeded(
        into headers: inout HTTPHeaders,
        urlString: String,
        httpMethod: String,
        extraheaders: [String: String] = [:]
    ) {
        guard #available(iOS 14.0, *) else { return }
        guard CidaasHTTPProofToken.shouldSendDpopHeader(for: urlString) else { return }
        do {
            let accessToken = accessTokenForDpopAth(extraheaders: extraheaders, headers: headers)
            let dpopHeaders = try CidaasHTTPProof.dpopProofHeader(
                urlString: urlString,
                httpMethod: httpMethod,
                accessToken: accessToken
            )
            for (key, value) in dpopHeaders where extraheaders[key] == nil && headers.value(for: key) == nil {
                headers[key] = value
            }
        } catch {
            logw(
                "DPoP proof failed for \(httpMethod) \(urlString): \(error.localizedDescription)",
                cname: "cidaas-sdk-error-log"
            )
        }
    }

    private static func applyDpopHeaderIfNeeded(to urlRequest: inout URLRequest) {
        guard #available(iOS 14.0, *),
              let urlString = urlRequest.url?.absoluteString
        else { return }
        guard CidaasHTTPProofToken.shouldSendDpopHeader(for: urlString) else { return }
        let method = (urlRequest.httpMethod ?? "POST").uppercased()
        do {
            let accessToken = accessTokenForDpopAth(from: urlRequest)
            let dpopHeaders = try CidaasHTTPProof.dpopProofHeader(
                urlString: urlString,
                httpMethod: method,
                accessToken: accessToken
            )
            for (key, value) in dpopHeaders {
                if urlRequest.value(forHTTPHeaderField: key) == nil {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
            }
        } catch {
            logw(
                "DPoP proof failed for \(method) \(urlString): \(error.localizedDescription)",
                cname: "cidaas-sdk-error-log"
            )
        }
    }

    /// Raw access token for `ath` when this request presents one (resource APIs).
    private static func accessTokenForDpopAth(
        extraheaders: [String: String],
        headers: HTTPHeaders
    ) -> String? {
        if let token = rawAccessToken(fromHeaderValues: extraheaders) {
            return token
        }
        var values: [String: String] = [:]
        for header in headers {
            values[header.name] = header.value
        }
        return rawAccessToken(fromHeaderValues: values)
    }

    private static func accessTokenForDpopAth(from urlRequest: URLRequest) -> String? {
        guard let all = urlRequest.allHTTPHeaderFields else { return nil }
        return rawAccessToken(fromHeaderValues: all)
    }

    private static func rawAccessToken(fromHeaderValues values: [String: String]) -> String? {
        for (key, value) in values {
            let normalized = key.lowercased()
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if normalized == "access_token" {
                return trimmed
            }
            if normalized == "authorization" {
                return stripAuthorizationScheme(trimmed)
            }
        }
        return nil
    }

    private static func stripAuthorizationScheme(_ value: String) -> String? {
        let lower = value.lowercased()
        for prefix in ["dpop ", "bearer "] {
            if lower.hasPrefix(prefix) {
                let token = String(value.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return token.isEmpty ? nil : token
            }
        }
        return value
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
        var urlReq = preparedUploadRequest(from: url)
        Self.logNetworkRequest(
            url: urlReq.url?.absoluteString ?? "",
            method: urlReq.httpMethod ?? "POST",
            headers: HTTPHeaders(urlReq.allHTTPHeaderFields ?? [:]),
            bodyParams: parameters as [String: Any]
        )
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
        var urlReq = preparedUploadRequest(from: url)
        Self.logNetworkRequest(
            url: urlReq.url?.absoluteString ?? "",
            method: urlReq.httpMethod ?? "POST",
            headers: HTTPHeaders(urlReq.allHTTPHeaderFields ?? [:]),
            bodyParams: parameters as [String: Any]
        )
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

    /// Merges default SDK headers + DPoP; disables cookie jar when a manual Cookie is present.
    private func preparedUploadRequest(from url: URLRequest) -> URLRequest {
        var urlReq = url
        for header in headers where urlReq.value(forHTTPHeaderField: header.name) == nil {
            urlReq.setValue(header.value, forHTTPHeaderField: header.name)
        }
        Self.applyDpopHeaderIfNeeded(to: &urlReq)
        if urlReq.value(forHTTPHeaderField: "Cookie") != nil {
            urlReq.httpShouldHandleCookies = false
        }
        return urlReq
    }
    
    func responseRedirect(response: AFDataResponse<String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        Self.logNetworkResponse(response)
        switch response.result {
        case .success(let value):
            if response.response?.statusCode == 200 || response.response?.statusCode == 201 {
                callback(value, nil)
                return
            }
            if (response.response?.statusCode == 204) {
                callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 204, errorMessage: "No data found", statusCode: response.response?.statusCode ?? 400))
                return
            }
            if response.response?.statusCode == 302 {
                let loc = response.response?.headers.value(for: "Location")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !loc.isEmpty {
                    callback(loc, nil)
                } else {
                    let body = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !body.isEmpty {
                        callback(body, nil)
                    } else {
                        callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 302, errorMessage: "302 without Location header", statusCode: 302))
                    }
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
