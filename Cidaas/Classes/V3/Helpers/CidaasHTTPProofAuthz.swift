//
//  CidaasHTTPProofAuthz.swift
//  Cidaas
//

import Foundation

/// `dpop_jkt` on authz URLs and requestId payloads (binds the authorization code server-side).
enum CidaasHTTPProofAuthz {
    /// Merges `dpop_jkt` when global ``Cidaas/ENABLE_DPOP`` is on.
    static func mergingDpopJKT(into params: [String: String]) -> [String: String] {
        var merged = params
        guard Cidaas.shared.ENABLE_DPOP, merged["dpop_jkt"] == nil else { return merged }
        if #available(iOS 14.0, *) {
            if let jkt = CidaasHTTPProof.dpopJKT(), !jkt.isEmpty {
                merged["dpop_jkt"] = jkt
            }
        }
        return merged
    }
}
