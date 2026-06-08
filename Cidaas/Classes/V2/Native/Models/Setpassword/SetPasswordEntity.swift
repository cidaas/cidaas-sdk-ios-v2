//
//  SetPasswordEntity.swift
//  Cidaas
//

import Foundation

public class SetPasswordEntity: Codable {

    public var password: String = ""
    public var confirmPassword: String = ""

    public init() {}
}
