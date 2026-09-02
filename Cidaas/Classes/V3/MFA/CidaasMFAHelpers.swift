//
//  CidaasMFAHelpers.swift
//  Cidaas
//

import Foundation

/// Shared completion hopping for MFA management builders.
enum CidaasMFAHelpers {

    static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
