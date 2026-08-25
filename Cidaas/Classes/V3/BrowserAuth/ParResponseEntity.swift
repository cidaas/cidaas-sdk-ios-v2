//
//  ParResponseEntity.swift
//  Cidaas
//

import Foundation

/// `POST /authz-srv/par` response (RFC 9126).
public class ParResponseEntity: Codable {

    public var request_uri: String = ""
    public var expires_in: Int = 0

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.request_uri = try container.decodeIfPresent(String.self, forKey: .request_uri) ?? ""
        self.expires_in = try container.decodeIfPresent(Int.self, forKey: .expires_in) ?? 0
    }
}
