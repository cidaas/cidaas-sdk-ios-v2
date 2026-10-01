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
    public var single_factor_auth: Bool = false
    /// Biometric proof JWT for touchId/fingerprint authenticate (biometric+jwt from Secure Enclave EC P-256)
    public var attestation: String = ""
    /// FIDO2 / passkey assertion payload (`fido2_client_response`).
    public var fido2_client_response: Fido2ClientResponse?
    
    private enum CodingKeys: String, CodingKey {
        case sub, exchange_id, push_id, device_id, client_id, pass_code, password, attempt, usage_type, request_id, attestation, single_factor_auth, fido2_client_response
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sub, forKey: .sub)
        try container.encode(exchange_id, forKey: .exchange_id)
        try container.encode(push_id, forKey: .push_id)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(client_id, forKey: .client_id)
        try container.encode(pass_code, forKey: .pass_code)
        try container.encode(password, forKey: .password)
        try container.encode(attempt, forKey: .attempt)
        try container.encode(usage_type, forKey: .usage_type)
        try container.encode(request_id, forKey: .request_id)
        try container.encode(single_factor_auth, forKey: .single_factor_auth)
        if !attestation.isEmpty {
            try container.encode(attestation, forKey: .attestation)
        }
        try container.encodeIfPresent(fido2_client_response, forKey: .fido2_client_response)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sub = try container.decodeIfPresent(String.self, forKey: .sub) ?? ""
        exchange_id = try container.decodeIfPresent(String.self, forKey: .exchange_id) ?? ""
        push_id = try container.decodeIfPresent(String.self, forKey: .push_id) ?? ""
        device_id = try container.decodeIfPresent(String.self, forKey: .device_id) ?? ""
        client_id = try container.decodeIfPresent(String.self, forKey: .client_id) ?? ""
        pass_code = try container.decodeIfPresent(String.self, forKey: .pass_code) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        attempt = try container.decodeIfPresent(Int.self, forKey: .attempt) ?? 0
        usage_type = try container.decodeIfPresent(String.self, forKey: .usage_type) ?? ""
        request_id = try container.decodeIfPresent(String.self, forKey: .request_id) ?? ""
        single_factor_auth = try container.decodeIfPresent(Bool.self, forKey: .single_factor_auth) ?? false
        attestation = try container.decodeIfPresent(String.self, forKey: .attestation) ?? ""
        fido2_client_response = try container.decodeIfPresent(Fido2ClientResponse.self, forKey: .fido2_client_response)
    }
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
