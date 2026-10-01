//
//  EnrollRequest.swift
//  Cidaas
//
//  Created by ganesh on 07/05/19.
//

import Foundation

public class EnrollRequest: Codable {
    
    public init() {}
    
    public var exchange_id: String = ""
    public var device_id: String = ""
    public var client_id: String = ""
    public var push_id: String = ""
    public var pass_code: String = ""
    public var attempt: Int = 0
    public var localizedReason: String = ""
    /// Biometric proof JWT for fingerprint/touchId enrollment (biometric+jwt from Secure Enclave EC P-256)
    public var attestation: String = ""
    /// FIDO2 / passkey attestation payload (`fido2_client_response`).
    public var fido2_client_response: Fido2ClientResponse?
    
    private enum CodingKeys: String, CodingKey {
        case exchange_id, device_id, client_id, push_id, pass_code, attempt, attestation, fido2_client_response
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exchange_id, forKey: .exchange_id)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(client_id, forKey: .client_id)
        try container.encode(push_id, forKey: .push_id)
        try container.encode(pass_code, forKey: .pass_code)
        try container.encode(attempt, forKey: .attempt)
        if !attestation.isEmpty {
            try container.encode(attestation, forKey: .attestation)
        }
        try container.encodeIfPresent(fido2_client_response, forKey: .fido2_client_response)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exchange_id = try container.decodeIfPresent(String.self, forKey: .exchange_id) ?? ""
        device_id = try container.decodeIfPresent(String.self, forKey: .device_id) ?? ""
        client_id = try container.decodeIfPresent(String.self, forKey: .client_id) ?? ""
        push_id = try container.decodeIfPresent(String.self, forKey: .push_id) ?? ""
        pass_code = try container.decodeIfPresent(String.self, forKey: .pass_code) ?? ""
        attempt = try container.decodeIfPresent(Int.self, forKey: .attempt) ?? 0
        attestation = try container.decodeIfPresent(String.self, forKey: .attestation) ?? ""
        fido2_client_response = try container.decodeIfPresent(Fido2ClientResponse.self, forKey: .fido2_client_response)
    }
}
