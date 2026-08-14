//
//  TokenHelper.swift
//  Cidaas
//
//  Created by Ganesh on 25/05/2025.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

public class TokenHelper: NSObject {

    public static var shared: TokenHelper = TokenHelper()

    func getSubFromAccessToken(from token: String) -> String? {
        guard let payload = Self.jwtPayload(token) else { return nil }
        return payload["sub"] as? String
    }

    /// Decodes a JWT payload (middle segment)
    private static func jwtPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return nil }
        guard let data = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}
