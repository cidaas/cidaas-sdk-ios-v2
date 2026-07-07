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
    
    private enum CodingKeys: String, CodingKey {
        case exchange_id, device_id, client_id, push_id, pass_code, attempt, attestation
    }
}
