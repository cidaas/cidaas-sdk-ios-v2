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
    
    /// Generates `request_id` with required `cidaas_dr` Cookie.
    /// Registers first when needed (no platform attestation). Fails if registration fails.
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

        sharedService.getRequestId(
            extraParams: extraParams,
            properties: savedProp
        ) { response, error in
            self.sharedPresenter.getRequestId(response: response, errorResponse: error, callback: callback)
        }
    }

    /// `GET /authz-srv/authz` (query + cookies). After redirects:
    /// - `redirect_uri`+`code` → tokens
    /// - `track_id` → prelogin metadata; `mfa_required` → ``InitLoginResult/mfaRequired``
    /// - else `request_id` → ``InitLoginResult/loginRequired(requestId:)``
    public func initLogin(
        extraParams: Dictionary<String, String>,
        callback: @escaping (Result<InitLoginResult>) -> Void
    ) {
        ensureDeviceRegisteredForRequestId { [weak self] regResult in
            guard let self else { return }
            switch regResult {
            case .failure(error: let error):
                DispatchQueue.main.async {
                    callback(.failure(error: error))
                }
            case .success(result: _):
                self.performInitLogin(extraParams: extraParams, callback: callback)
            }
        }
    }

    private func performInitLogin(
        extraParams: Dictionary<String, String>,
        callback: @escaping (Result<InitLoginResult>) -> Void
    ) {
        guard let savedProp = getProperties() else {
            let error = WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "properties cannot be empty",
                statusCode: 417
            )
            DispatchQueue.main.async {
                callback(.failure(error: error))
            }
            return
        }

        sharedService.initLogin(extraParams: extraParams, properties: savedProp) { response, error in
            if let error {
                DispatchQueue.main.async {
                    callback(.failure(error: error))
                }
                return
            }
            let location = (response ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !location.isEmpty else {
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 302,
                    errorMessage: "initLogin returned empty Location",
                    statusCode: 302
                )
                DispatchQueue.main.async {
                    callback(.failure(error: err))
                }
                return
            }

            let redirectURI = (savedProp["RedirectURL"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            switch InitLoginLocationParser.parse(location: location, redirectURI: redirectURI) {
            case .authorizationCode(let code):
                AccessTokenController.shared.getAccessToken(code: code) { tokenResult in
                    switch tokenResult {
                    case .failure(error: let tokenError):
                     DispatchQueue.main.async {
                        callback(.failure(error: tokenError))
                     }
                    case .success(result: let login):
                     DispatchQueue.main.async {
                        callback(.success(result: .loggedIn(login)))
                     }
                    }
                }
            case .preloginTrack(let trackId, let requestId, let sub):
                PreloginMFARequiredResolver.fetch(
                    trackId: trackId,
                    requestId: requestId ?? "",
                    sub: sub ?? "",
                    properties: savedProp
                ) { result in
                    switch result {
                    case .failure(error: let error):
                        callback(.failure(error: error))
                    case .success(result: let mfa):
                        callback(.success(result: .mfaRequired(mfa)))
                    }
                }
            case .loginRequired(let requestId):
                DispatchQueue.main.async {
                    callback(.success(result: .loginRequired(requestId: requestId)))
                }
            case .unrecognized:
                let err = WebAuthError.shared.serviceFailureException(
                    errorCode: 400,
                    errorMessage: "initLogin Location neither redirect_uri+code, track_id, nor request_id: \(location)",
                    statusCode: 400
                )
                DispatchQueue.main.async {
                    callback(.failure(error: err))
                }
            }
        }
    }

    /// Registers when the flag is unset (no platform attestation).
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

        Cidaas.shared.device().registerDevice(
            clientId: clientId,
            includePlatformAttestation: false
        ) { result in
            // Strong capture so waiters are always drained if this interactor is released mid-flight.
            switch result {
            case .failure(error: let error):
                self.finishDeviceRegistration(.failure(error: error))
            case .success(result: _):
                self.finishDeviceRegistration(.success(result: true))
            }
        }
    }

    private func finishDeviceRegistration(_ result: Result<Bool>) {
        registrationLock.lock()
        let waiters = registrationWaiters
        registrationWaiters.removeAll()
        registrationInFlight = false
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
