//
//  SetPasswordServiceWorker.swift
//  Cidaas
//

import Foundation
import Alamofire

public class SetPasswordServiceWorker {

    public static var shared: SetPasswordServiceWorker = SetPasswordServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: ChangePasswordURLHelper

    public init() {
        sharedSession = SessionManager.shared
        sharedURL = ChangePasswordURLHelper.shared
    }

    public func setPassword(
        access_token: String,
        incomingData: SetPasswordEntity,
        properties: Dictionary<String, String>,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        let baseURL = properties["DomainURL"] ?? ""
        guard !baseURL.isEmpty else {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }

        var bodyParams = Dictionary<String, Any>()
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        } catch {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }

        var headers: [String: String] = [:]
        headers["access_token"] = access_token

        let urlString = baseURL + sharedURL.getSetPasswordURL()
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, extraheaders: headers, callback: callback)
    }
}
