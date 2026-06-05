//
//  InitiateResponse.swift
//  Cidaas
//
//  Created by ganesh on 08/05/19.
//

import Foundation

public class InitiateResponse : Codable {
    public init() {}
    
    public var success: Bool = false
    public var status: Int32 = 0
    public var data: InitiateResponseData = InitiateResponseData()
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int32.self, forKey: .status) ?? 0
        self.data = try container.decodeIfPresent(InitiateResponseData.self, forKey: .data) ?? InitiateResponseData()
    }
}

public class InitiateResponseData: Codable {
    public var sub : String = ""
    public var maskedSub: String = ""
    public var status_id: String = ""
    public var exchange_id : ExchangeIdResponse = ExchangeIdResponse()
    public var push_selected_number: String = ""
    
    public init() {
        
    }
    
    enum CodingKeys: String, CodingKey {
        case sub
        case maskedSub = "q"
        case status_id
        case exchange_id
        case push_selected_number
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sub = try container.decodeIfPresent(String.self, forKey: .sub) ?? ""
        self.maskedSub = try container.decodeIfPresent(String.self, forKey: .maskedSub) ?? ""
        self.status_id = try container.decodeIfPresent(String.self, forKey: .status_id) ?? ""
        self.exchange_id = try container.decodeIfPresent(ExchangeIdResponse.self, forKey: .exchange_id) ?? ExchangeIdResponse()
        self.push_selected_number = try container.decodeIfPresent(String.self, forKey: .push_selected_number) ?? ""
    }
}
