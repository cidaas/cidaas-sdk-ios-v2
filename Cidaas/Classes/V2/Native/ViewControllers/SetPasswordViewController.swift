//
//  SetPasswordViewController.swift
//  Cidaas
//

import Foundation

public class SetPasswordViewController {

    public static var shared: SetPasswordViewController = SetPasswordViewController()
    var sharedInteractor: SetPasswordInteractor

    init() {
        sharedInteractor = SetPasswordInteractor.shared
    }

    public func setPassword(
        access_token: String,
        incomingData: SetPasswordEntity,
        callback: @escaping (Result<SetPasswordResponseEntity>) -> Void
    ) {
        sharedInteractor.setPassword(access_token: access_token, incomingData: incomingData, callback: callback)
    }
}
