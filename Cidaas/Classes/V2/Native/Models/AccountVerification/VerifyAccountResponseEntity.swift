//
//  VerifyAccountResponseEntity.swift
//  Cidaas
//
//  Created by ganesh on 27/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

public class VerifyAccountResponseEntity : Codable {
    // properties
    public var success: Bool = false
    public var status: Int16 = 400
    public var data: VerifyAccountResponseDataEntity = VerifyAccountResponseDataEntity()
    
    // Constructors
    public init() {
        
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int16.self, forKey: .status) ?? 400
        self.data = try container.decodeIfPresent(VerifyAccountResponseDataEntity.self, forKey: .data) ?? VerifyAccountResponseDataEntity()
    }
}

public class VerifyAccountResponseDataEntity : Codable {
    public var suggested_action: String = ""
    public var trackId: String = ""

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.suggested_action = try container.decodeIfPresent(String.self, forKey: .suggested_action) ?? ""
        self.trackId = try container.decodeIfPresent(String.self, forKey: .trackId)
            ?? container.decodeIfPresent(String.self, forKey: .track_id)
            ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(suggested_action, forKey: .suggested_action)
        try container.encode(trackId, forKey: .trackId)
    }

    enum CodingKeys: String, CodingKey {
        case suggested_action
        case trackId
        case track_id
    }
}
