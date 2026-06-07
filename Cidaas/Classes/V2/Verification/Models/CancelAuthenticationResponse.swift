//
//  CancelAuthenticationResponse.swift
//  Cidaas
//

import Foundation

public class CancelAuthenticationResponse: Codable {

    public init() {}

    public var success: Bool = false
    public var status: Int32 = 0
    public var data: CancelAuthenticationResponseData = CancelAuthenticationResponseData()

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int32.self, forKey: .status) ?? 0
        self.data = try container.decodeIfPresent(CancelAuthenticationResponseData.self, forKey: .data) ?? CancelAuthenticationResponseData()
    }
}

public class CancelAuthenticationResponseData: Codable {
    public var sub: String = ""
    public var status_id: String = ""
    public var exchange_id: ExchangeIdConfig = ExchangeIdConfig()

    public init() {}
}
