//
//  CidaasV3Callback.swift
//  Cidaas
//

import Foundation

enum CidaasV3Callback {
    static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    static func deliver<T>(_ result: Result<T>, to completion: @escaping (Result<T>) -> Void) {
        onMain { completion(result) }
    }
}
