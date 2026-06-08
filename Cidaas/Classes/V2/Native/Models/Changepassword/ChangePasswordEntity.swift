//
//  ChangePasswordEntity.swift
//  Cidaas
//
//  Created by ganesh on 01/08/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

public class ChangePasswordEntity : Codable {
    
    // properties
    public var confirm_password: String = ""
    public var new_password: String = ""
    public var old_password: String = ""
    public var sub: String = ""
    public var identityId: String = ""
    public var logout_option: String = ""
    
    // Constructors
    public init() {
        
    }
}
