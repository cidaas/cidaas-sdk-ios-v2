//
//  CidaasMFA.swift
//  Cidaas
//

import Foundation
import UIKit

extension Cidaas {

    public static func mfa(_ type: CidaasMFAVerificationType) -> CidaasMFABuilder {
        CidaasMFABuilder(verificationType: type.rawValue)
    }
}

public enum CidaasMFAVerificationType: String, CaseIterable {
    case pattern = "PATTERN"
    case push = "PUSH"
    case touchId = "TOUCHID"
    case totp = "TOTP"
    case face = "FACE"
    case voice = "VOICE"
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

public struct CidaasMFAAuthenticationInitiationResult {
    public let sub: String
    public let exchangeId: String
    public let statusId: String
    public let pushSelectedNumber: String?
}

fileprivate enum CidaasMFAWire {
    static func dispatchMain(_ block: @escaping () -> Void) {
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
}

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
}

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

    public func support() -> CidaasMFASupportBuilder {
        CidaasMFASupportBuilder(verificationType: verificationType)
    }

    public func configurations(sub: String? = nil, completion: @escaping (Result<MFAListResponse>) -> Void) {
        let resolvedSub = sub ?? enrollmentSession.cachedSub ?? authenticationSession.cachedSub ?? ""
        if resolvedSub.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("sub is required")))
            }
            return
        }
        let req = MFAListRequest()
        req.sub = resolvedSub
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()
        VerificationViewController.shared.getConfiguredList(incomingData: req) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }
}

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
        if accessToken.isEmpty && sub.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("accessToken or sub is required")))
            }
            return
        }
        let req = SetupRequest()
        req.access_token = accessToken
        req.sub = sub
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()

        VerificationViewController.shared.setup(verificationType: verificationType, incomingData: req) { result in
            switch result {
            case .failure(let error):
                CidaasMFAWire.dispatchMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let setupEx = resp.data.exchange_id.exchange_id
                let pushSel = resp.data.push_selected_number
                let totpSecret = resp.data.totp_secret.isEmpty ? nil : resp.data.totp_secret
                self.session.cachedSub = resp.data.sub
                self.session.cachedSetupExchangeId = setupEx
                self.session.cachedPushSelectedNumber = pushSel.isEmpty ? nil : pushSel
                self.session.cachedExchangeIdAfterScanned = nil
                let value = CidaasMFAEnrollmentInitiationResult(
                    sub: resp.data.sub,
                    setupExchangeId: setupEx,
                    statusId: resp.data.status_id,
                    totpSecret: totpSecret,
                    pushSelectedNumber: pushSel.isEmpty ? nil : pushSel
                )
                CidaasMFAWire.dispatchMain { completion(.success(result: value)) }
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
        if resolvedSub.isEmpty || resolvedExchange.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("sub and exchangeId are required (call initiation first or pass explicitly)")))
            }
            return
        }
        let req = ScannedRequest()
        req.sub = resolvedSub
        req.exchange_id = resolvedExchange
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()

        VerificationViewController.shared.scanned(verificationType: verificationType, incomingData: req) { result in
            switch result {
            case .failure(let error):
                CidaasMFAWire.dispatchMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let exId = resp.data.exchange_id.exchange_id
                self.session.cachedExchangeIdAfterScanned = exId
                let value = CidaasMFAEnrollmentScannedResult(
                    sub: resp.data.sub,
                    exchangeId: exId,
                    statusId: resp.data.status_id,
                    pushRandomNumbers: resp.data.push_random_numbers
                )
                CidaasMFAWire.dispatchMain { completion(.success(result: value)) }
            }
        }
    }

    public func verification(
        exchangeId: String? = nil,
        otp: String? = nil,
        pattern: String? = nil,
        pushNumber: String? = nil,
        photo: UIImage = UIImage(),
        voice: Data = Data(),
        attempt: Int = 0,
        localizedReason: String = "Authenticate",
        completion: @escaping (Result<EnrollResponse>) -> Void
    ) {
        let resolvedExchange = exchangeId ?? session.cachedExchangeIdAfterScanned ?? session.cachedSetupExchangeId ?? ""
        if resolvedExchange.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("exchangeId is required")))
            }
            return
        }
        let enroll = EnrollRequest()
        enroll.exchange_id = resolvedExchange
        enroll.attempt = attempt
        enroll.localizedReason = localizedReason
        enroll.device_id = CidaasMFAWire.deviceId()
        enroll.push_id = CidaasMFAWire.pushId()

        switch verificationType {
        case VerificationTypes.PUSH.rawValue:
            let code = pushNumber ?? session.cachedPushSelectedNumber ?? ""
            if code.isEmpty {
                CidaasMFAWire.dispatchMain {
                    completion(.failure(error: CidaasMFAWire.validationError("pushNumber is required for PUSH")))
                }
                return
            }
            enroll.pass_code = code
        case VerificationTypes.TOUCH.rawValue:
            enroll.pass_code = otp ?? pattern ?? ""
        default:
            let code = otp ?? pattern ?? ""
            if code.isEmpty && verificationType != VerificationTypes.FACE.rawValue && verificationType != VerificationTypes.VOICE.rawValue {
                CidaasMFAWire.dispatchMain {
                    completion(.failure(error: CidaasMFAWire.validationError("otp or pattern is required")))
                }
                return
            }
            enroll.pass_code = code
        }

        VerificationViewController.shared.enroll(
            verificationType: verificationType,
            photo: photo,
            voice: voice,
            incomingData: enroll
        ) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }
}

public final class CidaasMFAAuthenticationBuilder {

    private let verificationType: String
    private let session: CidaasMFAAuthenticationSession

    fileprivate init(verificationType: String, session: CidaasMFAAuthenticationSession) {
        self.verificationType = verificationType
        self.session = session
    }

    public func initiation(
        sub: String,
        requestId: String,
        usageType: String,
        completion: @escaping (Result<CidaasMFAAuthenticationInitiationResult>) -> Void
    ) {
        if sub.isEmpty || requestId.isEmpty || usageType.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("sub, requestId, and usageType are required")))
            }
            return
        }
        let req = InitiateRequest()
        req.sub = sub
        req.request_id = requestId
        req.usage_type = usageType
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()

        VerificationViewController.shared.initiate(verificationType: verificationType, incomingData: req) { result in
            switch result {
            case .failure(let error):
                CidaasMFAWire.dispatchMain { completion(.failure(error: error)) }
            case .success(result: let resp):
                let pushSel = resp.data.push_selected_number
                let exId = resp.data.exchange_id.exchange_id
                self.session.cachedSub = resp.data.sub
                self.session.cachedExchangeId = exId
                self.session.cachedPushSelected = pushSel.isEmpty ? nil : pushSel
                self.session.cachedRequestId = requestId
                self.session.cachedUsageType = usageType
                let value = CidaasMFAAuthenticationInitiationResult(
                    sub: resp.data.sub,
                    exchangeId: exId,
                    statusId: resp.data.status_id,
                    pushSelectedNumber: pushSel.isEmpty ? nil : pushSel
                )
                CidaasMFAWire.dispatchMain { completion(.success(result: value)) }
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
        voice: Data = Data(),
        attempt: Int = 0,
        localizedReason: String = "Authenticate",
        completion: @escaping (Result<AuthenticateResponse>) -> Void
    ) {
        let resolvedExchange = exchangeId ?? session.cachedExchangeId ?? ""
        let resolvedSub = session.cachedSub ?? ""
        let reqId = requestId ?? session.cachedRequestId ?? ""
        let useType = usageType ?? session.cachedUsageType ?? ""
        if resolvedExchange.isEmpty || resolvedSub.isEmpty || reqId.isEmpty || useType.isEmpty {
            CidaasMFAWire.dispatchMain {
                completion(.failure(error: CidaasMFAWire.validationError("exchangeId, sub, requestId, and usageType are required")))
            }
            return
        }

        let auth = AuthenticateRequest()
        auth.sub = resolvedSub
        auth.exchange_id = resolvedExchange
        auth.request_id = reqId
        auth.usage_type = useType
        auth.attempt = attempt
        auth.localizedReason = localizedReason
        auth.device_id = CidaasMFAWire.deviceId()
        auth.push_id = CidaasMFAWire.pushId()

        switch verificationType {
        case VerificationTypes.PUSH.rawValue:
            let code = pushNumber ?? session.cachedPushSelected ?? ""
            if code.isEmpty {
                CidaasMFAWire.dispatchMain {
                    completion(.failure(error: CidaasMFAWire.validationError("pushNumber is required for PUSH")))
                }
                return
            }
            auth.pass_code = code
        case VerificationTypes.TOUCH.rawValue:
            auth.pass_code = otp ?? pattern ?? ""
        default:
            let code = otp ?? pattern ?? ""
            if code.isEmpty && verificationType != VerificationTypes.FACE.rawValue && verificationType != VerificationTypes.VOICE.rawValue {
                CidaasMFAWire.dispatchMain {
                    completion(.failure(error: CidaasMFAWire.validationError("otp or pattern is required")))
                }
                return
            }
            auth.pass_code = code
        }

        VerificationViewController.shared.authenticate(
            verificationType: verificationType,
            photo: photo,
            voice: voice,
            incomingData: auth
        ) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func pushAcknowledge(
        exchangeId: String,
        completion: @escaping (Result<PushAcknowledgeResponse>) -> Void
    ) {
        let req = PushAcknowledgeRequest()
        req.exchange_id = exchangeId
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()
        VerificationViewController.shared.pushAcknowledge(verificationType: verificationType, incomingData: req) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func pushAllow(
        exchangeId: String,
        completion: @escaping (Result<PushAllowResponse>) -> Void
    ) {
        let req = PushAllowRequest()
        req.exchange_id = exchangeId
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()
        VerificationViewController.shared.pushAllow(verificationType: verificationType, incomingData: req) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func pushReject(
        exchangeId: String,
        reason: String = "",
        completion: @escaping (Result<PushRejectResponse>) -> Void
    ) {
        let req = PushRejectRequest()
        req.exchange_id = exchangeId
        req.reason = reason
        req.device_id = CidaasMFAWire.deviceId()
        req.push_id = CidaasMFAWire.pushId()
        VerificationViewController.shared.pushReject(verificationType: verificationType, incomingData: req) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }
}

public final class CidaasMFASupportBuilder {

    private let verificationType: String

    fileprivate init(verificationType: String) {
        self.verificationType = verificationType
    }

    public func deleteAll(incomingData: DeleteRequest, completion: @escaping (Result<DeleteResponse>) -> Void) {
        VerificationViewController.shared.deleteAll(incomingData: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func delete(incomingData: DeleteRequest, completion: @escaping (Result<DeleteResponse>) -> Void) {
        VerificationViewController.shared.delete(incomingData: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func pendingNotifications(
        incomingData: PendingNotificationRequest,
        completion: @escaping (Result<PendingNotificationResponse>) -> Void
    ) {
        VerificationViewController.shared.getPendingNotificationList(incomingData: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func history(
        incomingData: MFAHistoryRequest,
        completion: @escaping (Result<MFAHistoryResponse>) -> Void
    ) {
        VerificationViewController.shared.getMFAHistoryList(incomingData: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func updateFCM(pushId: String) {
        VerificationViewController.shared.updateFCM(push_id: pushId)
    }

    public func updateFCMToken(
        incomingData: UpdateFCMRequest,
        completion: @escaping (Result<UpdateFCMResponse>) -> Void
    ) {
        VerificationViewController.shared.updateFCMToken(updateFCMRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func passwordlessContinue(
        incomingData: PasswordlessRequest,
        completion: @escaping (Result<AuthzCodeResponse>) -> Void
    ) {
        VerificationInteractor.shared.passwordlessContinue(incomingData: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func timeline(
        incomingData: TimeLineRequest,
        completion: @escaping (Result<TimeLineDetailsResponse>) -> Void
    ) {
        VerificationViewController.shared.getTimeLineDetails(timeLineRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func configuredDeviceList(
        incomingData: MFAConfiguredDeviceListRequest,
        completion: @escaping (Result<MFAConfiguredDeviceListResponse>) -> Void
    ) {
        VerificationViewController.shared.getMFAConfiguredDeviceList(mfaConfiguredDeviceListRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func deleteDevice(
        incomingData: DeleteDeviceRequest,
        completion: @escaping (Result<DeleteResponse>) -> Void
    ) {
        VerificationViewController.shared.deleteDevice(deleteRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func deviceConfiguredList(
        incomingData: MFAListRequest,
        completion: @escaping (Result<MFAListResponse>) -> Void
    ) {
        VerificationViewController.shared.getDeviceConfiguredList(mfaListRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }

    public func cancelQr(
        incomingData: CancelQrRequest,
        completion: @escaping (Result<CancelQrResponse>) -> Void
    ) {
        VerificationViewController.shared.cancelQr(verificationType: verificationType, cancelQrRequest: incomingData) { result in
            CidaasMFAWire.dispatchMain { completion(result) }
        }
    }
}
