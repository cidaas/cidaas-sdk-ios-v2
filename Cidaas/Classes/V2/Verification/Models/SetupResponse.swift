//
//  SetupResponse.swift
//  Cidaas
//
//  Created by ganesh on 01/07/19.
//

import Foundation

public class SetupResponse: Codable {
    
    public init() {}
    
    public var success: Bool = false
    public var status: Int32 = 0
    public var data: SetupResponseData = SetupResponseData()
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int32.self, forKey: .status) ?? 0
        self.data = try container.decodeIfPresent(SetupResponseData.self, forKey: .data) ?? SetupResponseData()
    }
}

public class SetupResponseData: Codable {
    
    public init() {}
    
    public var exchange_id: ExchangeIdResponse = ExchangeIdResponse()
    public var sub: String = ""
    public var status_id: String = ""
    public var authenticator_client_id: String = ""
    public var push_selected_number: String = ""
    public var totp_secret: String = ""
    /// Present for FIDO2 / passkey enrolment initiation.
    public var fido2_entity: Fido2Entity?
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.exchange_id = try container.decodeIfPresent(ExchangeIdResponse.self, forKey: .exchange_id) ?? ExchangeIdResponse()
        self.sub = try container.decodeIfPresent(String.self, forKey: .sub) ?? ""
        self.status_id = try container.decodeIfPresent(String.self, forKey: .status_id) ?? ""
        self.authenticator_client_id = try container.decodeIfPresent(String.self, forKey: .authenticator_client_id) ?? ""
        self.push_selected_number = try container.decodeIfPresent(String.self, forKey: .push_selected_number) ?? ""
        self.totp_secret = try container.decodeIfPresent(String.self, forKey: .totp_secret) ?? ""
        self.fido2_entity = try container.decodeIfPresent(Fido2Entity.self, forKey: .fido2_entity)
    }
}
