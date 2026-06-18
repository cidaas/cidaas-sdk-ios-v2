//
//  AuthenticateRequest.swift
//  Cidaas
//
//  Created by ganesh on 10/05/19.
//

import Foundation

public class AuthenticateRequest: Codable {
    
    public init() {}
    
    public var sub: String = ""
    public var exchange_id: String = ""
    public var push_id: String = ""
    public var device_id: String = ""
    public var client_id: String = ""
    public var pass_code: String = ""
    public var password: String = ""
    public var attempt: Int = 0
    public var localizedReason: String = ""
    public var usage_type: String = ""
    public var request_id: String = ""
}

extension AuthenticateRequest {
    /// Maps OTP/pattern/push credentials to `pass_code`, or password to `password` per verification type.
    func applyVerificationCredential(verificationType: String, value: String) {
        if verificationType == VerificationTypes.PASSWORD.rawValue {
            password = value
            pass_code = ""
        } else {
            pass_code = value
            password = ""
        }
    }
}
