//
//  AuthzInteractor.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class AuthzInteractor {
    
    public static var shared: AuthzInteractor = AuthzInteractor()
    var sharedService: AuthzServiceWorker
    var sharedPresenter: AuthzPresenter

    private let registrationLock = NSLock()
    private var registrationInFlight = false
    private var registrationWaiters: [(Result<Bool>) -> Void] = []
    
    public init() {
        sharedService = AuthzServiceWorker.shared
        sharedPresenter = AuthzPresenter.shared
    }
    
    /// Generates `request_id`. Registers the device first if needed, then sends `Cookie: cidaas_dr=<deviceId>`.
    public func getRequestId(
        extraParams: Dictionary<String, String>,
        callback: @escaping(Result<RequestIdResponseEntity>) -> Void
    ) {
        ensureDeviceRegisteredForRequestId { [weak self] regResult in
            guard let self else { return }
            switch regResult {
            case .failure(error: let error):
                self.sharedPresenter.getRequestId(response: nil, errorResponse: error, callback: callback)
            case .success(result: _):
                self.performGetRequestId(extraParams: extraParams, callback: callback)
            }
        }
    }

    private func performGetRequestId(
        extraParams: Dictionary<String, String>,
        callback: @escaping(Result<RequestIdResponseEntity>) -> Void
    ) {
        guard let savedProp = getProperties() else {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "properties cannot be empty",
                statusCode: 417
            )
            sharedPresenter.getRequestId(response: nil, errorResponse: error, callback: callback)
            return
        }

        let deviceId = SDKDeviceIdResolver.resolve()
        guard !deviceId.isEmpty else {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "deviceId missing for cidaas_dr Cookie",
                statusCode: 417
            )
            sharedPresenter.getRequestId(response: nil, errorResponse: error, callback: callback)
            return
        }

        sharedService.getRequestId(
            extraParams: extraParams,
            properties: savedProp
        ) { response, error in
            self.sharedPresenter.getRequestId(response: response, errorResponse: error, callback: callback)
        }
    }

    /// Uses the in-memory flag after a successful check this process; otherwise hits initiate (409 = already registered).
    private func ensureDeviceRegisteredForRequestId(
        completion: @escaping (Result<Bool>) -> Void
    ) {
        registrationLock.lock()

        if Cidaas.shared.isDeviceRegistrationCompleted {
            let deviceId = SDKDeviceIdResolver.resolve()
            if !deviceId.isEmpty {
                registrationLock.unlock()
                DispatchQueue.main.async {
                    completion(.success(result: true))
                }
                return
            }
            Cidaas.shared.isDeviceRegistrationCompleted = false
        }

        if registrationInFlight {
            registrationWaiters.append(completion)
            registrationLock.unlock()
            return
        }

        registrationInFlight = true
        registrationWaiters.append(completion)
        registrationLock.unlock()

        startDeviceRegistrationForRequestId()
    }

    private func startDeviceRegistrationForRequestId() {
        guard #available(iOS 14.0, *) else {
            finishDeviceRegistration(
                .failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: "Device registration requires iOS 14+",
                    statusCode: 400
                ))
            )
            return
        }

        let clientId = DBHelper.shared.getPropertyFile()?["ClientId"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clientId.isEmpty else {
            finishDeviceRegistration(
                .failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 417,
                    errorMessage: "ClientId is required before generating requestId",
                    statusCode: 417
                ))
            )
            return
        }

        let pushId = DBHelper.shared.getFCM().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pushId.isEmpty else {
            finishDeviceRegistration(
                .failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 417,
                    errorMessage: "push_id (FCM) is required before generating requestId",
                    statusCode: 417
                ))
            )
            return
        }

        Cidaas.shared.device().registerDevice(clientId: clientId, pushId: pushId) { [weak self] result in
            switch result {
            case .failure(error: let error):
                self?.finishDeviceRegistration(.failure(error: error))
            case .success(result: _):
                self?.finishDeviceRegistration(.success(result: true))
            }
        }
    }

    private func finishDeviceRegistration(_ result: Result<Bool>) {
        registrationLock.lock()
        let waiters = registrationWaiters
        registrationWaiters.removeAll()
        registrationInFlight = false
        if case .success = result {
            Cidaas.shared.isDeviceRegistrationCompleted = true
        }
        registrationLock.unlock()

        DispatchQueue.main.async {
            for waiter in waiters {
                waiter(result)
            }
        }
    }
    
    func getProperties() -> Dictionary<String, String>? {
        DBHelper.shared.getPropertyFile()
    }
}
