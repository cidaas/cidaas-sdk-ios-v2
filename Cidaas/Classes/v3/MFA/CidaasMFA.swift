//
//  CidaasMFA.swift
//  Cidaas
//

import Foundation
import UIKit

// MARK: - Entry points

extension Cidaas {

    public static func mfa(_ type: CidaasMFAVerificationType) -> CidaasMFABuilder {
        CidaasMFABuilder(verificationType: type.rawValue)
    }

    /// Enrollment setup: initiation, then scan only when required (pattern/push/touch/face).
    public static func mfaEnrollmentSetup(
        _ type: CidaasMFAVerificationType,
        accessToken: String = "",
        sub: String = "",
        completion: @escaping (Result<CidaasMFAEnrollmentSetupResult>) -> Void
    ) {
        mfa(type).enrollment().enrollmentSetup(accessToken: accessToken, sub: sub, completion: completion)
    }
}

// MARK: - Public types

public enum CidaasMFAVerificationType: String, CaseIterable {
    case pattern = "PATTERN"
    case push = "PUSH"
    case touchId = "TOUCHID"
    case totp = "TOTP"
    case face = "FACE"
    case email = "EMAIL"
    case sms = "SMS"
    case ivr = "IVR"
    case backupCode = "BACKUPCODE"
}

public struct CidaasMFAEnrollmentInitiationResult {
    public let sub: String
    public let setupExchangeId: String
    public let statusId: String
    public let totpSecret: String?
    public let pushSelectedNumber: String?
}

public struct CidaasMFAEnrollmentScannedResult {
    public let sub: String
    public let exchangeId: String
    public let statusId: String
    public let pushRandomNumbers: [String]
}

/// Result of enrollment setup. Use `enrollmentExchangeId` for `enrollment().verification()` when verify is required.
public struct CidaasMFAEnrollmentSetupResult {
    public let verificationType: String
    public let initiation: CidaasMFAEnrollmentInitiationResult
    /// Present only when a scan step ran (pattern, push, touch id, face).
    public let scanned: CidaasMFAEnrollmentScannedResult?

    public var scanWasPerformed: Bool { scanned != nil }

    /// Exchange id for enrollment verification (initiation id for SMS/email/IVR/TOTP/backup; scan id otherwise).
    public var enrollmentExchangeId: String {
        CidaasMFAEnrollmentBuilder.enrollmentVerificationExchangeId(
            verificationType: verificationType,
            setupExchangeId: initiation.setupExchangeId,
            scannedExchangeId: scanned?.exchangeId ?? ""
        )
    }
}

public struct CidaasMFAAuthenticationInitiationResult {
    public let sub: String
    public let maskedSub: String?
    public let exchangeId: String
    public let statusId: String
    public let pushSelectedNumber: String?
}

// MARK: - Session state

fileprivate final class CidaasMFAEnrollmentSession {
    var cachedSub: String?
    var cachedSetupExchangeId: String?
    var cachedExchangeIdAfterScanned: String?
    var cachedPushSelectedNumber: String?
}

fileprivate final class CidaasMFAAuthenticationSession {
    var cachedSub: String?
    var cachedExchangeId: String?
    var cachedPushSelected: String?
    var cachedRequestId: String?
    var cachedUsageType: String?

    func storeInitiation(
        sub: String,
        exchangeId: String,
        pushSelected: String?,
        requestId: String,
        usageType: String
    ) {
        cachedSub = sub
        cachedExchangeId = exchangeId
        cachedPushSelected = pushSelected
        cachedRequestId = requestId
        cachedUsageType = usageType
    }

    func updateExchangeId(_ exchangeId: String) {
        if !exchangeId.isEmpty { cachedExchangeId = exchangeId }
    }
}

// MARK: - Builder

public final class CidaasMFABuilder {

    private let verificationType: String
    fileprivate let enrollmentSession = CidaasMFAEnrollmentSession()
    fileprivate let authenticationSession = CidaasMFAAuthenticationSession()

    fileprivate init(verificationType: String) {
        self.verificationType = verificationType
    }

    public func enrollment() -> CidaasMFAEnrollmentBuilder {
        CidaasMFAEnrollmentBuilder(verificationType: verificationType, session: enrollmentSession)
    }

    public func authentication() -> CidaasMFAAuthenticationBuilder {
        CidaasMFAAuthenticationBuilder(verificationType: verificationType, session: authenticationSession)
    }

    /// Configured MFA methods for the user on this device.
    public func configurations(sub: String? = nil, completion: @escaping (Result<MFAListResponse>) -> Void) {
        let resolvedSub = sub ?? enrollmentSession.cachedSub ?? authenticationSession.cachedSub ?? ""
        guard !resolvedSub.isEmpty else {
            MFA.fail("sub is required", completion: completion)
            return
        }
        let req = MFAListRequest()
        req.sub = resolvedSub
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()
        VerificationViewController.shared.getConfiguredList(incomingData: req) { result in
            MFA.onMain { completion(result) }
        }
    }
}

// MARK: - Enrollment

public final class CidaasMFAEnrollmentBuilder {

    private let verificationType: String
    private let session: CidaasMFAEnrollmentSession

    fileprivate init(verificationType: String, session: CidaasMFAEnrollmentSession) {
        self.verificationType = verificationType
        self.session = session
    }

    public func initiation(
        accessToken: String = "",
        sub: String = "",
        completion: @escaping (Result<CidaasMFAEnrollmentInitiationResult>) -> Void
    ) {
        guard !accessToken.isEmpty || !sub.isEmpty else {
            MFA.fail("accessToken or sub is required", completion: completion)
            return
        }
        let req = SetupRequest()
        req.access_token = accessToken
        req.sub = sub
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()

        VerificationViewController.shared.setup(verificationType: verificationType, incomingData: req) { [self] result in
            switch result {
            case .failure(let error):
                MFA.onMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let setupExchangeId = resp.data.exchange_id.exchange_id
                let pushSelected = resp.data.push_selected_number
                let totpSecret = resp.data.totp_secret.isEmpty ? nil : resp.data.totp_secret
                session.cachedSub = resp.data.sub
                session.cachedSetupExchangeId = setupExchangeId
                session.cachedPushSelectedNumber = pushSelected.isEmpty ? nil : pushSelected
                session.cachedExchangeIdAfterScanned = nil
                let value = CidaasMFAEnrollmentInitiationResult(
                    sub: resp.data.sub,
                    setupExchangeId: setupExchangeId,
                    statusId: resp.data.status_id,
                    totpSecret: totpSecret,
                    pushSelectedNumber: pushSelected.isEmpty ? nil : pushSelected
                )
                MFA.onMain { completion(.success(result: value)) }
            }
        }
    }

    public func scanned(
        sub: String? = nil,
        exchangeId: String? = nil,
        completion: @escaping (Result<CidaasMFAEnrollmentScannedResult>) -> Void
    ) {
        let resolvedSub = sub ?? session.cachedSub ?? ""
        let resolvedExchange = exchangeId ?? session.cachedSetupExchangeId ?? ""
        guard !resolvedSub.isEmpty, !resolvedExchange.isEmpty else {
            MFA.fail(
                "sub and exchangeId are required (call initiation first or pass explicitly)",
                completion: completion
            )
            return
        }
        let req = ScannedRequest()
        req.sub = resolvedSub
        req.exchange_id = resolvedExchange
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()

        VerificationViewController.shared.scanned(verificationType: verificationType, incomingData: req) { [self] result in
            switch result {
            case .failure(let error):
                MFA.onMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let scannedExchangeId = resp.data.exchange_id.exchange_id
                session.cachedExchangeIdAfterScanned = scannedExchangeId
                let value = CidaasMFAEnrollmentScannedResult(
                    sub: resp.data.sub,
                    exchangeId: scannedExchangeId,
                    statusId: resp.data.status_id,
                    pushRandomNumbers: resp.data.push_random_numbers
                )
                MFA.onMain { completion(.success(result: value)) }
            }
        }
    }

    /// Initiation, then scan when required. Session is cached for `verification()`.
    public func enrollmentSetup(
        accessToken: String = "",
        sub: String = "",
        completion: @escaping (Result<CidaasMFAEnrollmentSetupResult>) -> Void
    ) {
        initiation(accessToken: accessToken, sub: sub) { initResult in
            switch initResult {
            case .failure(let error):
                completion(.failure(error: error))
            case .success(let initiation):
                guard Self.requiresScan(verificationType: self.verificationType) else {
                    let value = CidaasMFAEnrollmentSetupResult(
                        verificationType: self.verificationType,
                        initiation: initiation,
                        scanned: nil
                    )
                    MFA.onMain { completion(.success(result: value)) }
                    return
                }
                self.scanned(sub: initiation.sub, exchangeId: initiation.setupExchangeId) { scanResult in
                    switch scanResult {
                    case .failure(let error):
                        completion(.failure(error: error))
                    case .success(let scanned):
                        let value = CidaasMFAEnrollmentSetupResult(
                            verificationType: self.verificationType,
                            initiation: initiation,
                            scanned: scanned
                        )
                        MFA.onMain { completion(.success(result: value)) }
                    }
                }
            }
        }
    }

    public func verification(
        exchangeId: String? = nil,
        otp: String? = nil,
        pattern: String? = nil,
        pushNumber: String? = nil,
        photo: UIImage = UIImage(),
        attempt: Int = 0,
        localizedReason: String = "Authenticate",
        completion: @escaping (Result<EnrollResponse>) -> Void
    ) {
        let resolvedExchange = resolvedEnrollmentExchangeId(explicit: exchangeId)
        guard !resolvedExchange.isEmpty else {
            MFA.fail("exchangeId is required", completion: completion)
            return
        }
        guard let passCode = MFAPassCode.resolve(
            verificationType: verificationType,
            otp: otp,
            pattern: pattern,
            pushNumber: pushNumber,
            cachedPushNumber: session.cachedPushSelectedNumber
        ) else {
            MFA.fail(MFAPassCode.validationMessage(for: verificationType), completion: completion)
            return
        }

        let enroll = EnrollRequest()
        enroll.exchange_id = resolvedExchange
        enroll.pass_code = passCode
        enroll.attempt = attempt
        enroll.localizedReason = localizedReason
        enroll.device_id = MFA.deviceId()
        enroll.push_id = MFA.pushId()

        VerificationViewController.shared.enroll(
            verificationType: verificationType,
            photo: photo,
            voice: Data(),
            incomingData: enroll
        ) { result in
            MFA.onMain { completion(result) }
        }
    }

    fileprivate static func requiresScan(verificationType: String) -> Bool {
        switch verificationType {
        case VerificationTypes.PATTERN.rawValue,
             VerificationTypes.PUSH.rawValue,
             VerificationTypes.TOUCH.rawValue,
             VerificationTypes.FACE.rawValue:
            return true
        default:
            return false
        }
    }

    fileprivate static func enrollmentVerificationExchangeId(
        verificationType: String,
        setupExchangeId: String,
        scannedExchangeId: String
    ) -> String {
        requiresScan(verificationType: verificationType) ? scannedExchangeId : setupExchangeId
    }

    private func resolvedEnrollmentExchangeId(explicit: String?) -> String {
        if let explicit, !explicit.isEmpty { return explicit }
        return Self.enrollmentVerificationExchangeId(
            verificationType: verificationType,
            setupExchangeId: session.cachedSetupExchangeId ?? "",
            scannedExchangeId: session.cachedExchangeIdAfterScanned ?? ""
        )
    }
}

// MARK: - Authentication

public final class CidaasMFAAuthenticationBuilder {

    private let verificationType: String
    private let session: CidaasMFAAuthenticationSession

    fileprivate init(verificationType: String, session: CidaasMFAAuthenticationSession) {
        self.verificationType = verificationType
        self.session = session
    }

    /// `POST verification-srv/authentication/{method}/initiation`
    /// - `INITIAL_AUTHENTICATION`: pass `identifier` (e.g. email); do not pass `sub`.
    /// - `MULTIFACTOR_AUTHENTICATION`: pass masked `sub` only (not the logged-in user's real sub).
    public func initiation(
        requestId: String,
        usageType: String,
        sub: String = "",
        identifier: String = "",
        mediumId: String = "",
        completion: @escaping (Result<CidaasMFAAuthenticationInitiationResult>) -> Void
    ) {
        if let message = Self.validateInitiation(
            usageType: usageType,
            sub: sub,
            identifier: identifier,
            requestId: requestId
        ) {
            MFA.fail(message, completion: completion)
            return
        }

        let req = InitiateRequest()
        req.sub = sub
        req.identifier = identifier
        if !mediumId.isEmpty { req.medium_id = mediumId }
        req.request_id = requestId
        req.usage_type = usageType
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()

        VerificationViewController.shared.initiate(verificationType: verificationType, incomingData: req) { [self] result in
            switch result {
            case .failure(let error):
                MFA.onMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let pushSelected = resp.data.push_selected_number
                let exchangeId = resp.data.exchange_id.exchange_id
                let cachedSub = Self.cachedAuthSubAfterInitiate(
                    usageType: usageType,
                    requestSub: sub,
                    responseSub: resp.data.sub,
                    responseMaskedSub: resp.data.maskedSub
                )
                session.storeInitiation(
                    sub: cachedSub,
                    exchangeId: exchangeId,
                    pushSelected: pushSelected.isEmpty ? nil : pushSelected,
                    requestId: requestId,
                    usageType: usageType
                )
                let value = CidaasMFAAuthenticationInitiationResult(
                    sub: usageType == UsageTypes.MFA.rawValue ? sub : cachedSub,
                    maskedSub: nil,
                    exchangeId: exchangeId,
                    statusId: resp.data.status_id,
                    pushSelectedNumber: pushSelected.isEmpty ? nil : pushSelected
                )
                MFA.onMain { completion(.success(result: value)) }
            }
        }
    }

    public func verification(
        exchangeId: String? = nil,
        otp: String? = nil,
        pattern: String? = nil,
        pushNumber: String? = nil,
        requestId: String? = nil,
        usageType: String? = nil,
        photo: UIImage = UIImage(),
        attempt: Int = 0,
        localizedReason: String = "Authenticate",
        completion: @escaping (Result<AuthenticateResponse>) -> Void
    ) {
        let resolvedExchange = exchangeId ?? session.cachedExchangeId ?? ""
        let resolvedSub = session.cachedSub ?? ""
        let resolvedRequestId = requestId ?? session.cachedRequestId ?? ""
        let resolvedUsageType = usageType ?? session.cachedUsageType ?? ""
        guard !resolvedExchange.isEmpty,
              !resolvedSub.isEmpty,
              !resolvedRequestId.isEmpty,
              !resolvedUsageType.isEmpty else {
            MFA.fail("exchangeId, sub, requestId, and usageType are required", completion: completion)
            return
        }
        guard let passCode = MFAPassCode.resolve(
            verificationType: verificationType,
            otp: otp,
            pattern: pattern,
            pushNumber: pushNumber,
            cachedPushNumber: session.cachedPushSelected
        ) else {
            MFA.fail(MFAPassCode.validationMessage(for: verificationType), completion: completion)
            return
        }

        let auth = AuthenticateRequest()
        auth.sub = resolvedSub
        auth.exchange_id = resolvedExchange
        auth.request_id = resolvedRequestId
        auth.usage_type = resolvedUsageType
        auth.pass_code = passCode
        auth.attempt = attempt
        auth.localizedReason = localizedReason
        auth.device_id = MFA.deviceId()
        auth.push_id = MFA.pushId()

        VerificationViewController.shared.authenticate(
            verificationType: verificationType,
            photo: photo,
            voice: Data(),
            incomingData: auth
        ) { result in
            MFA.onMain { completion(result) }
        }
    }

    public func pushAcknowledge(
        exchangeId: String? = nil,
        completion: @escaping (Result<PushAcknowledgeResponse>) -> Void
    ) {
        guard let resolved = resolvedPushExchangeId(exchangeId) else {
            MFA.fail("exchangeId is required", completion: completion)
            return
        }
        let req = PushAcknowledgeRequest()
        req.exchange_id = resolved
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()
        VerificationViewController.shared.pushAcknowledge(verificationType: verificationType, incomingData: req) { [self] result in
            switch result {
            case .failure:
                MFA.onMain { completion(result) }
            case .success(let response):
                session.updateExchangeId(response.data.exchange_id.exchange_id)
                MFA.onMain { completion(.success(result: response)) }
            }
        }
    }

    public func pushAllow(
        exchangeId: String? = nil,
        completion: @escaping (Result<PushAllowResponse>) -> Void
    ) {
        guard let resolved = resolvedPushExchangeId(exchangeId) else {
            MFA.fail("exchangeId is required", completion: completion)
            return
        }
        let req = PushAllowRequest()
        req.exchange_id = resolved
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()
        VerificationViewController.shared.pushAllow(verificationType: verificationType, incomingData: req) { [self] result in
            switch result {
            case .failure:
                MFA.onMain { completion(result) }
            case .success(let response):
                session.updateExchangeId(response.data.exchange_id.exchange_id)
                if let number = response.data.push_random_numbers.first, !number.isEmpty {
                    session.cachedPushSelected = number
                }
                MFA.onMain { completion(.success(result: response)) }
            }
        }
    }

    public func pushReject(
        exchangeId: String? = nil,
        reason: String = "",
        completion: @escaping (Result<PushRejectResponse>) -> Void
    ) {
        guard let resolved = resolvedPushExchangeId(exchangeId) else {
            MFA.fail("exchangeId is required", completion: completion)
            return
        }
        let req = PushRejectRequest()
        req.exchange_id = resolved
        req.reason = reason
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()
        VerificationViewController.shared.pushReject(verificationType: verificationType, incomingData: req) { result in
            MFA.onMain { completion(result) }
        }
    }

    fileprivate static func validateInitiation(
        usageType: String,
        sub: String,
        identifier: String,
        requestId: String
    ) -> String? {
        if requestId.isEmpty { return "requestId is required" }
        if usageType.isEmpty { return "usageType is required" }
        if !identifier.isEmpty && usageType != UsageTypes.INITIAL.rawValue {
            return "identifier is only allowed for INITIAL_AUTHENTICATION"
        }
        switch usageType {
        case UsageTypes.INITIAL.rawValue:
            if identifier.isEmpty { return "identifier is required for INITIAL_AUTHENTICATION" }
            if !sub.isEmpty { return "sub must not be sent for INITIAL_AUTHENTICATION; use identifier" }
        case UsageTypes.MFA.rawValue:
            if sub.isEmpty { return "masked sub is required for MULTIFACTOR_AUTHENTICATION" }
        default:
            if sub.isEmpty && identifier.isEmpty { return "sub or identifier is required" }
        }
        return nil
    }

    /// MFA: cache masked `sub` from the initiate request only. INITIAL: use response `sub` or `q` for verify.
    fileprivate static func cachedAuthSubAfterInitiate(
        usageType: String,
        requestSub: String,
        responseSub: String,
        responseMaskedSub: String
    ) -> String {
        if usageType == UsageTypes.MFA.rawValue {
            return requestSub
        }
        if !responseSub.isEmpty { return responseSub }
        return responseMaskedSub
    }

    private func resolvedPushExchangeId(_ explicit: String?) -> String? {
        let value = explicit ?? session.cachedExchangeId ?? ""
        return value.isEmpty ? nil : value
    }
}

// MARK: - Private helpers

private enum MFA {
    static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    static func pushId() -> String {
        let device = DBHelper.shared.getDeviceInfo()
        return device.pushNotificationId.isEmpty ? DBHelper.shared.getFCM() : device.pushNotificationId
    }

    static func deviceId() -> String {
        DBHelper.shared.getDeviceInfo().deviceId
    }

    static func validationError(_ message: String) -> WebAuthError {
        WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: message, statusCode: 417)
    }

    static func fail<T>(_ message: String, completion: @escaping (Result<T>) -> Void) {
        onMain { completion(.failure(error: validationError(message))) }
    }
}

private enum MFAPassCode {
    /// Resolves `pass_code` for verification requests.
    static func resolve(
        verificationType: String,
        otp: String?,
        pattern: String?,
        pushNumber: String?,
        cachedPushNumber: String?
    ) -> String? {
        switch verificationType {
        case VerificationTypes.PUSH.rawValue:
            let code = pushNumber ?? cachedPushNumber ?? ""
            return code.isEmpty ? nil : code
        case VerificationTypes.PATTERN.rawValue:
            let code = pattern ?? otp ?? ""
            return code.isEmpty ? nil : code
        case VerificationTypes.TOUCH.rawValue, VerificationTypes.FACE.rawValue:
            return ""
        default:
            let code = otp ?? pattern ?? ""
            return code.isEmpty ? nil : code
        }
    }

    static func validationMessage(for verificationType: String) -> String {
        switch verificationType {
        case VerificationTypes.PUSH.rawValue:
            return "pushNumber is required for PUSH"
        case VerificationTypes.PATTERN.rawValue:
            return "pattern encoding is required for PATTERN"
        default:
            return "otp or pattern is required"
        }
    }
}
