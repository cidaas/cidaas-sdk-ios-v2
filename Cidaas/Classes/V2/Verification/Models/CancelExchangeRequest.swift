//
//  CancelExchangeRequest.swift
//  Cidaas
//

import Foundation

public class CancelExchangeRequest: Codable {

    public var reason: String = ""
    public var exchange_id: String = ""

    public init() {}
}
