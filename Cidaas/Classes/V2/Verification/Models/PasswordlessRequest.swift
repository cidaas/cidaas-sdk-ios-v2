//
//  PasswordlessRequest.swift
//  Cidaas
//
//  Created by ganesh on 03/07/19.
//

import Foundation

public class PasswordlessRequest: Codable {
    
    public init() {}
    
    public var sub: String = ""
    public var requestId: String = ""
    public var status_id: String = ""
    public var verificationType: String = ""
    public var device_id: String = ""
    public var push_id: String = ""
    public var client_id: String = ""
    public var track_id: String = ""
}
