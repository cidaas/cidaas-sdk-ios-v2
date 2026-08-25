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
    private var registrationWaiters: [() -> Void] = []
    
    public init() {
        sharedService = AuthzServiceWorker.shared
        sharedPresenter = AuthzPresenter.shared
    }
    
    /// Generates `request_id` with required `cidaas_dr` Cookie.
    /// Device registration is best-effort (iOS 14+ only) and never blocks this call.
    public func getRequestId(
        extraParams: Dictionary<String, String>,
        callback: @escaping(Result<RequestIdResponseEntity>) -> Void
    ) {
        ensureDeviceRegisteredForRequestId { [weak self] in
            self?.performGetRequestId(extraParams: extraParams, callback: callback)
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

        sharedService.getRequestId(
            extraParams: extraParams,
            properties: savedProp
        ) { response, error in
            self.sharedPresenter.getRequestId(response: response, errorResponse: error, callback: callback)
        }
    }

    /// Best-effort register when the persisted flag is unset. Always continues afterward.
    private func ensureDeviceRegisteredForRequestId(completion: @escaping () -> Void) {
        registrationLock.lock()

        if Cidaas.shared.isDeviceRegistrationCompleted {
            let deviceId = SDKDeviceIdResolver.resolve()
            if !deviceId.isEmpty {
                registrationLock.unlock()
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            // Stale flag without a device id — clear and try register again.
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
        // registerDevice needs iOS 14+; older OS versions still get requestId + Cookie.
        guard #available(iOS 14.0, *) else {
            finishDeviceRegistration()
            return
        }

        let clientId = DBHelper.shared.getPropertyFile()?["ClientId"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clientId.isEmpty else {
            finishDeviceRegistration()
            return
        }

        Cidaas.shared.device().registerDevice(
            clientId: clientId,
            pushId: DBHelper.shared.getFCM(),
            includePlatformAttestation: false
        ) { [weak self] _ in
            // Success or failure — requestId continues either way.
            self?.finishDeviceRegistration()
        }
    }

    private func finishDeviceRegistration() {
        registrationLock.lock()
        let waiters = registrationWaiters
        registrationWaiters.removeAll()
        registrationInFlight = false
        registrationLock.unlock()

        DispatchQueue.main.async {
            for waiter in waiters {
                waiter()
            }
        }
    }
    
    func getProperties() -> Dictionary<String, String>? {
        DBHelper.shared.getPropertyFile()
    }
}
