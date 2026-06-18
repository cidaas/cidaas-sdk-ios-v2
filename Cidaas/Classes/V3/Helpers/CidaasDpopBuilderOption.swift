//
//  CidaasDpopBuilderOption.swift
//  Cidaas
//

import Foundation

/// Optional per-builder DPoP flag for authz / token flows.
struct CidaasDpopBuilderOption {
    private(set) var useDpop = false

    mutating func setUseDpop(_ enabled: Bool) {
        useDpop = enabled
    }
}
