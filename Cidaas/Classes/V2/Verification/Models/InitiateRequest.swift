//
//  InitiateRequest.swift
//  Cidaas
//
//  Created by ganesh on 08/05/19.
//

import Foundation

public class InitiateRequest: Codable {
    
    public init() {}
    
    public var sub: String = ""
    public var identifier: String = ""
    public var medium_id: String = ""
    public var request_id: String = ""
    public var usage_type: String = ""
    public var device_id: String = ""
    public var push_id: String = ""
    public var single_factor_auth: Bool = false
    /// Used for FIDO2 authentication.
    public var domainURL: String = ""
    public var allowedDomains: [String] = []

    private enum CodingKeys: String, CodingKey {
        case sub, identifier, medium_id, request_id, usage_type, device_id, push_id, single_factor_auth, domainURL, allowedDomains
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sub, forKey: .sub)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(medium_id, forKey: .medium_id)
        try container.encode(request_id, forKey: .request_id)
        try container.encode(usage_type, forKey: .usage_type)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(push_id, forKey: .push_id)
        try container.encode(single_factor_auth, forKey: .single_factor_auth)
        if !domainURL.isEmpty {
            try container.encode(domainURL, forKey: .domainURL)
        }
        if !allowedDomains.isEmpty {
            try container.encode(allowedDomains, forKey: .allowedDomains)
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sub = try container.decodeIfPresent(String.self, forKey: .sub) ?? ""
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        medium_id = try container.decodeIfPresent(String.self, forKey: .medium_id) ?? ""
        request_id = try container.decodeIfPresent(String.self, forKey: .request_id) ?? ""
        usage_type = try container.decodeIfPresent(String.self, forKey: .usage_type) ?? ""
        device_id = try container.decodeIfPresent(String.self, forKey: .device_id) ?? ""
        push_id = try container.decodeIfPresent(String.self, forKey: .push_id) ?? ""
        single_factor_auth = try container.decodeIfPresent(Bool.self, forKey: .single_factor_auth) ?? false
        domainURL = try container.decodeIfPresent(String.self, forKey: .domainURL) ?? ""
        allowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
    }
}
