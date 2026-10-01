//
//  SetupRequest.swift
//  Cidaas
//
//  Created by ganesh on 01/07/19.
//

import Foundation

public class SetupRequest: Codable {
    
    public init() {}
    
    public var access_token: String = ""
    public var sub: String = ""
    public var device_id: String = ""
    public var push_id: String = ""
    /// Used for FIDO2 enrolment (hostname derived server-side).
    public var domainURL: String = ""
    public var allowedDomains: [String] = []

    private enum CodingKeys: String, CodingKey {
        case access_token, sub, device_id, push_id, domainURL, allowedDomains
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(access_token, forKey: .access_token)
        try container.encode(sub, forKey: .sub)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(push_id, forKey: .push_id)
        if !domainURL.isEmpty {
            try container.encode(domainURL, forKey: .domainURL)
        }
        if !allowedDomains.isEmpty {
            try container.encode(allowedDomains, forKey: .allowedDomains)
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try container.decodeIfPresent(String.self, forKey: .access_token) ?? ""
        sub = try container.decodeIfPresent(String.self, forKey: .sub) ?? ""
        device_id = try container.decodeIfPresent(String.self, forKey: .device_id) ?? ""
        push_id = try container.decodeIfPresent(String.self, forKey: .push_id) ?? ""
        domainURL = try container.decodeIfPresent(String.self, forKey: .domainURL) ?? ""
        allowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
    }
}
