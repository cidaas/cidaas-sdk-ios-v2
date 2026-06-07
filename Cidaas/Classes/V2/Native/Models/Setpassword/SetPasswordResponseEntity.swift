//
//  SetPasswordResponseEntity.swift
//  Cidaas
//

import Foundation

public class SetPasswordResponseEntity: Codable {
    public var success: Bool = false
    public var status: Int16 = 400
    public var data: SetPasswordResponseDataEntity = SetPasswordResponseDataEntity()

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int16.self, forKey: .status) ?? 400
        self.data = try container.decodeIfPresent(SetPasswordResponseDataEntity.self, forKey: .data) ?? SetPasswordResponseDataEntity()
    }
}

public class SetPasswordResponseDataEntity: Codable {
    public var saved: Bool = false

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.saved = try container.decodeIfPresent(Bool.self, forKey: .saved) ?? false
    }
}
