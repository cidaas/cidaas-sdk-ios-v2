//
//  CidaasHTTPProofAuthz.swift
//  Cidaas
//

import Foundation

/// `dpop_jkt` on authz URLs and requestId payloads (binds the authorization code server-side).
enum CidaasHTTPProofAuthz {
    static func mergingDpopJKT(into params: [String: String], useDpop: Bool) -> [String: String] {
        var merged = params
        guard useDpop, merged["dpop_jkt"] == nil else { return merged }
        if #available(iOS 14.0, *) {
            if let jkt = CidaasHTTPProof.dpopJKT(), !jkt.isEmpty {
                merged["dpop_jkt"] = jkt
            }
        }
        return merged
    }
}
