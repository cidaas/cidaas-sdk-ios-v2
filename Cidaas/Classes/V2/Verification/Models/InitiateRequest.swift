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
}
