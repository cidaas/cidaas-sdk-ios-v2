//
//  PasskeyCredentialHelper.swift
//  Cidaas
//
//  Bridges Cidaas FIDO2 `server_challenge` ↔ AuthenticationServices platform passkeys.
//
//  Availability:
//  - Class / extensions: iOS 15+ (platform passkeys).
//  - `#available(iOS 17.4)`: `excludedCredentials` on platform registration.
//  - `#available(iOS 16.0)`: preferImmediatelyAvailableCredentials (assert + exclude probe).
//  Nested checks are intentional — not redundant with the class gate.
//

import Foundation
import UIKit
import AuthenticationServices

@available(iOS 15.0, *)
public final class PasskeyCredentialHelper: NSObject {

    public static let shared = PasskeyCredentialHelper()

    private var pendingCompletion: ((Swift.Result<Fido2ClientResponse, Error>) -> Void)?
    private weak var presentationAnchor: UIWindow?
    private var fidoRequestId: String = ""
    private var authorizationController: ASAuthorizationController?
    private var excludeProbeOnNoLocalMatch: (() -> Void)?
    private var pendingEnrollmentRpId: String = ""
    private var pendingEnrollmentUserId: Data = Data()

    private override init() {
        super.init()
    }

    /// Creates a platform passkey from registration `server_challenge`.
    public func createCredential(
        serverChallenge: Fido2ServerChallenge,
        fidoRequestId: String,
        presenting viewController: UIViewController,
        completion: @escaping (Swift.Result<Fido2ClientResponse, Error>) -> Void
    ) {
        guard pendingCompletion == nil, excludeProbeOnNoLocalMatch == nil else {
            completion(.failure(passkeyError("Another passkey operation is in progress")))
            return
        }

        let rpId = serverChallenge.relyingPartyId
        guard !rpId.isEmpty else {
            completion(.failure(passkeyError("server_challenge.rp.id (or rpId) is missing")))
            return
        }
        guard let challengeData = Self.base64URLDecode(serverChallenge.challenge), !challengeData.isEmpty else {
            completion(.failure(passkeyError("server_challenge.challenge is missing or invalid base64url")))
            return
        }

        let user = serverChallenge.user
        let userName = (user?.name.isEmpty == false ? user!.name : user?.displayName) ?? ""
        guard !userName.isEmpty else {
            completion(.failure(passkeyError("server_challenge.user.name is missing")))
            return
        }
        let userIdData = Self.decodeUserId(user?.id ?? "")
        guard !userIdData.isEmpty else {
            completion(.failure(passkeyError("server_challenge.user.id is missing")))
            return
        }

        let serverExcludes = serverChallenge.excludeCredentials ?? []
        if serverExcludes.isEmpty {
            Self.clearLocalEnrollment(rpId: rpId, userId: userIdData)
            Self.clearAllLocalEnrollments(rpId: rpId)
        }

        let anchor = viewController.view.window ?? Self.keyWindow()
        guard let anchor else {
            completion(.failure(passkeyError("No UIWindow available to present passkey UI")))
            return
        }

        let excludedDescriptors = Self.platformDescriptors(from: serverExcludes)

        // iOS 17.4+: OS excludeCredentials.
        // iOS 16..<17.4: probe local passkeys.
        if !excludedDescriptors.isEmpty, #available(iOS 16.0, *), !Self.supportsRegistrationExcludedCredentials {
            startExcludeProbe(
                rpId: rpId,
                challengeData: challengeData,
                excludedDescriptors: excludedDescriptors,
                anchor: anchor,
                fidoRequestId: fidoRequestId,
                completion: completion
            ) { [weak self] in
                self?.performRegistration(
                    rpId: rpId,
                    challengeData: challengeData,
                    userName: userName,
                    userIdData: userIdData,
                    displayName: user?.displayName,
                    excludedDescriptors: [],
                    anchor: anchor,
                    fidoRequestId: fidoRequestId,
                    completion: completion
                )
            }
            return
        }

        performRegistration(
            rpId: rpId,
            challengeData: challengeData,
            userName: userName,
            userIdData: userIdData,
            displayName: user?.displayName,
            excludedDescriptors: excludedDescriptors,
            anchor: anchor,
            fidoRequestId: fidoRequestId,
            completion: completion
        )
    }

    /// Asserts an existing platform passkey from login `server_challenge`.
    public func assertCredential(
        serverChallenge: Fido2ServerChallenge,
        fidoRequestId: String,
        presenting viewController: UIViewController,
        completion: @escaping (Swift.Result<Fido2ClientResponse, Error>) -> Void
    ) {
        guard pendingCompletion == nil, excludeProbeOnNoLocalMatch == nil else {
            completion(.failure(passkeyError("Another passkey operation is in progress")))
            return
        }

        let rpId = serverChallenge.relyingPartyId
        guard !rpId.isEmpty else {
            completion(.failure(passkeyError("server_challenge.rp.id (or rpId) is missing")))
            return
        }
        guard let challengeData = Self.base64URLDecode(serverChallenge.challenge), !challengeData.isEmpty else {
            completion(.failure(passkeyError("server_challenge.challenge is missing or invalid base64url")))
            return
        }

        let anchor = viewController.view.window ?? Self.keyWindow()
        guard let anchor else {
            completion(.failure(passkeyError("No UIWindow available to present passkey UI")))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        if let allowed = serverChallenge.allowCredentials, !allowed.isEmpty {
            let descriptors = allowed.compactMap { descriptor -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? in
                guard let data = Self.decodeAllowCredentialID(descriptor.id), !data.isEmpty else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
            }
            if !descriptors.isEmpty {
                request.allowedCredentials = descriptors
            }
        }

        self.fidoRequestId = fidoRequestId
        self.pendingCompletion = completion
        self.presentationAnchor = anchor
        self.pendingEnrollmentRpId = rpId
        if let user = serverChallenge.user {
            self.pendingEnrollmentUserId = Self.decodeUserId(user.id.isEmpty ? user.name : user.id)
        } else {
            self.pendingEnrollmentUserId = Data()
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.authorizationController = controller
        if #available(iOS 16.0, *) {
            controller.performRequests(options: .preferImmediatelyAvailableCredentials)
        } else {
            controller.performRequests()
        }
    }

    // MARK: - Registration / exclude probe
    private static var supportsRegistrationExcludedCredentials: Bool {
        if #available(iOS 17.4, *) { return true }
        return false
    }

    private func performRegistration(
        rpId: String,
        challengeData: Data,
        userName: String,
        userIdData: Data,
        displayName: String?,
        excludedDescriptors: [ASAuthorizationPlatformPublicKeyCredentialDescriptor],
        anchor: UIWindow,
        fidoRequestId: String,
        completion: @escaping (Swift.Result<Fido2ClientResponse, Error>) -> Void
    ) {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: userName,
            userID: userIdData
        )
        if let displayName, !displayName.isEmpty {
            request.displayName = displayName
        }
        if #available(iOS 17.4, *), !excludedDescriptors.isEmpty {
            request.excludedCredentials = excludedDescriptors
        }

        self.fidoRequestId = fidoRequestId
        self.pendingCompletion = completion
        self.presentationAnchor = anchor
        self.excludeProbeOnNoLocalMatch = nil
        self.pendingEnrollmentRpId = rpId
        self.pendingEnrollmentUserId = userIdData

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.authorizationController = controller
        controller.performRequests()
    }

    /// iOS 16..<17.4: silent assert against exclude list. Local match → already enrolled.
    @available(iOS 16.0, *)
    private func startExcludeProbe(
        rpId: String,
        challengeData: Data,
        excludedDescriptors: [ASAuthorizationPlatformPublicKeyCredentialDescriptor],
        anchor: UIWindow,
        fidoRequestId: String,
        completion: @escaping (Swift.Result<Fido2ClientResponse, Error>) -> Void,
        onNoLocalMatch: @escaping () -> Void
    ) {
        self.fidoRequestId = fidoRequestId
        self.pendingCompletion = completion
        self.presentationAnchor = anchor
        self.excludeProbeOnNoLocalMatch = onNoLocalMatch

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        request.allowedCredentials = excludedDescriptors

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.authorizationController = controller
        controller.performRequests(options: .preferImmediatelyAvailableCredentials)
    }

    private static func platformDescriptors(
        from list: [Fido2CredentialDescriptor]?
    ) -> [ASAuthorizationPlatformPublicKeyCredentialDescriptor] {
        guard let list, !list.isEmpty else { return [] }
        return list.compactMap { descriptor in
            // Prefer unwrap path — some tenants may surface double-encoded ids.
            guard let data = decodeAllowCredentialID(descriptor.id) ?? base64URLDecode(descriptor.id),
                  !data.isEmpty else { return nil }
            return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
        }
    }

    // MARK: - Local enrolment memory (iOS < 17.4)

    private static let localEnrollmentDefaultsKey = "cidaas.fido2.localEnrollments"

    private static func localEnrollmentStorageKey(rpId: String, userId: Data) -> String {
        "\(rpId)|\(base64URLEncode(userId))"
    }

    static func hasLocalEnrollment(rpId: String, userId: Data) -> Bool {
        !localEnrollmentCredentialIds(rpId: rpId, userId: userId).isEmpty
    }

    public static func hasAnyLocalEnrollment(rpId: String) -> Bool {
        let prefix = "\(rpId)|"
        let map = UserDefaults.standard.dictionary(forKey: localEnrollmentDefaultsKey) as? [String: [String]] ?? [:]
        return map.contains { key, ids in key.hasPrefix(prefix) && !ids.isEmpty }
    }

    public static func enrollmentBlockedReason(serverChallenge: Fido2ServerChallenge) -> String? {
        let rpId = serverChallenge.relyingPartyId
        guard !rpId.isEmpty else { return nil }

        let serverExcludes = serverChallenge.excludeCredentials ?? []
        let userId = decodeUserId(serverChallenge.user?.id ?? "")

        // Server has no enrolled creds → allow create; drop stale UserDefaults from prior enrol.
        if serverExcludes.isEmpty {
            if !userId.isEmpty {
                clearLocalEnrollment(rpId: rpId, userId: userId)
            }
            clearAllLocalEnrollments(rpId: rpId)
            return nil
        }

        if !userId.isEmpty, hasLocalEnrollment(rpId: rpId, userId: userId) {
            return "FIDO2 / passkey already enrolled on this device."
        }
        return nil
    }

    static func localEnrollmentCredentialIds(rpId: String, userId: Data) -> [Data] {
        let key = localEnrollmentStorageKey(rpId: rpId, userId: userId)
        let map = UserDefaults.standard.dictionary(forKey: localEnrollmentDefaultsKey) as? [String: [String]] ?? [:]
        return (map[key] ?? []).compactMap { base64URLDecode($0) }.filter { !$0.isEmpty }
    }

    static func rememberLocalEnrollment(rpId: String, userId: Data, credentialId: Data) {
        guard !rpId.isEmpty, !userId.isEmpty, !credentialId.isEmpty else { return }
        let key = localEnrollmentStorageKey(rpId: rpId, userId: userId)
        var map = UserDefaults.standard.dictionary(forKey: localEnrollmentDefaultsKey) as? [String: [String]] ?? [:]
        var ids = Set(map[key] ?? [])
        ids.insert(base64URLEncode(credentialId))
        map[key] = Array(ids)
        UserDefaults.standard.set(map, forKey: localEnrollmentDefaultsKey)
    }

    /// Clears SDK-remembered FIDO enrolments for an RP/user (e.g. after server-side delete).
    public static func clearLocalEnrollment(rpId: String, userId: Data) {
        let key = localEnrollmentStorageKey(rpId: rpId, userId: userId)
        var map = UserDefaults.standard.dictionary(forKey: localEnrollmentDefaultsKey) as? [String: [String]] ?? [:]
        map.removeValue(forKey: key)
        UserDefaults.standard.set(map, forKey: localEnrollmentDefaultsKey)
    }

    /// Clears all remembered enrolments for an RP (user id may be unknown before initiate).
    public static func clearAllLocalEnrollments(rpId: String) {
        guard !rpId.isEmpty else { return }
        let prefix = "\(rpId)|"
        var map = UserDefaults.standard.dictionary(forKey: localEnrollmentDefaultsKey) as? [String: [String]] ?? [:]
        map = map.filter { !$0.key.hasPrefix(prefix) }
        UserDefaults.standard.set(map, forKey: localEnrollmentDefaultsKey)
    }

    // MARK: - Encoding helpers

    public static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func base64URLDecode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad > 0 {
            s.append(String(repeating: "=", count: 4 - pad))
        }
        return Data(base64Encoded: s)
    }

    public static func decodeAllowCredentialID(_ string: String) -> Data? {
        guard let once = base64URLDecode(string), !once.isEmpty else { return nil }
        if let asText = String(data: once, encoding: .utf8),
           !asText.isEmpty,
           asText.unicodeScalars.allSatisfy({ Self.isBase64URLScalar($0) }),
           let twice = base64URLDecode(asText),
           !twice.isEmpty {
            return twice
        }
        return once
    }

    private static func isBase64URLScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "A"..."Z", "a"..."z", "0"..."9", "-", "_":
            return true
        default:
            return false
        }
    }

    /// User id may be base64url or a plain UTF-8 string from the server.
    private static func decodeUserId(_ value: String) -> Data {
        if let decoded = base64URLDecode(value), !decoded.isEmpty {
            return decoded
        }
        return Data(value.utf8)
    }

    private static func assertionUserHandle(_ assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion) -> Data? {
        let userID = (assertion as ASAuthorizationPublicKeyCredentialAssertion).userID
        guard let userID, !userID.isEmpty else { return nil }
        return userID
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func passkeyError(_ message: String) -> WebAuthError {
        WebAuthError.shared.serviceFailureException(
            errorCode: WebAuthErrorCode.PROPERT_MISSING.rawValue,
            errorMessage: message,
            statusCode: 417
        )
    }

    private func alreadyEnrolledError() -> WebAuthError {
        passkeyError(
            "FIDO2 / passkey already enrolled on this device."
        )
    }

    private func finish(_ result: Swift.Result<Fido2ClientResponse, Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        presentationAnchor = nil
        authorizationController = nil
        excludeProbeOnNoLocalMatch = nil
        fidoRequestId = ""
        pendingEnrollmentRpId = ""
        pendingEnrollmentUserId = Data()
        DispatchQueue.main.async {
            completion?(result)
        }
    }

    private func clientResponse(
        credentialID: Data,
        clientDataJSON: Data,
        attestationObject: Data? = nil,
        authenticatorData: Data? = nil,
        signature: Data? = nil,
        userHandle: Data? = nil
    ) -> Fido2ClientResponse {
        let id = Self.base64URLEncode(credentialID)
        let credential = Fido2PublicKeyCredential()
        credential.id = id
        credential.rawId = id
        credential.type = "public-key"
        credential.authenticatorAttachment = "platform"
        credential.response.clientDataJSON = Self.base64URLEncode(clientDataJSON)
        if let attestationObject {
            credential.response.attestationObject = Self.base64URLEncode(attestationObject)
        }
        if let authenticatorData {
            credential.response.authenticatorData = Self.base64URLEncode(authenticatorData)
        }
        if let signature {
            credential.response.signature = Self.base64URLEncode(signature)
        }
        if let userHandle {
            credential.response.userHandle = Self.base64URLEncode(userHandle)
        }

        let wrapper = Fido2ClientResponse()
        wrapper.fidoRequestId = fidoRequestId
        wrapper.client_response = credential
        return wrapper
    }
}

@available(iOS 15.0, *)
extension PasskeyCredentialHelper: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if excludeProbeOnNoLocalMatch != nil {
            finish(.failure(alreadyEnrolledError()))
            return
        }

        if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            guard let attestationObject = registration.rawAttestationObject else {
                finish(.failure(passkeyError("Passkey registration missing attestationObject")))
                return
            }
            if !pendingEnrollmentRpId.isEmpty, !pendingEnrollmentUserId.isEmpty {
                Self.rememberLocalEnrollment(
                    rpId: pendingEnrollmentRpId,
                    userId: pendingEnrollmentUserId,
                    credentialId: registration.credentialID
                )
            }
            let response = clientResponse(
                credentialID: registration.credentialID,
                clientDataJSON: registration.rawClientDataJSON,
                attestationObject: attestationObject
            )
            finish(.success(response))
            return
        }

        if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let userId = Self.assertionUserHandle(assertion) ?? pendingEnrollmentUserId
            if !pendingEnrollmentRpId.isEmpty, !userId.isEmpty {
                Self.rememberLocalEnrollment(
                    rpId: pendingEnrollmentRpId,
                    userId: userId,
                    credentialId: assertion.credentialID
                )
            }
            let response = clientResponse(
                credentialID: assertion.credentialID,
                clientDataJSON: assertion.rawClientDataJSON,
                authenticatorData: assertion.rawAuthenticatorData,
                signature: assertion.signature,
                userHandle: Self.assertionUserHandle(assertion)
            )
            finish(.success(response))
            return
        }

        finish(.failure(passkeyError("Unexpected passkey credential type")))
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let nsError = error as NSError

        if let continueRegistration = excludeProbeOnNoLocalMatch {
            let isCancel = nsError.domain == ASAuthorizationError.errorDomain
                && nsError.code == ASAuthorizationError.canceled.rawValue
            let noLocalCredential = nsError.domain == ASAuthorizationError.errorDomain
                && (nsError.code == ASAuthorizationError.failed.rawValue
                    || nsError.code == ASAuthorizationError.unknown.rawValue
                    || nsError.code == ASAuthorizationError.notHandled.rawValue)

            if isCancel {
                finish(.failure(WebAuthError.shared.serviceFailureException(
                    errorCode: WebAuthErrorCode.USER_CANCELLED_LOGIN.rawValue,
                    errorMessage: "Passkey cancelled by user",
                    statusCode: 417
                )))
                return
            }
            if noLocalCredential {
                excludeProbeOnNoLocalMatch = nil
                authorizationController = nil
                pendingCompletion = nil
                continueRegistration()
                return
            }
            finish(.failure(passkeyError(
                "Passkey excludeCredentials probe failed — \(nsError.localizedDescription)"
            )))
            return
        }

        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            finish(.failure(WebAuthError.shared.serviceFailureException(
                errorCode: WebAuthErrorCode.USER_CANCELLED_LOGIN.rawValue,
                errorMessage: "Passkey cancelled by user",
                statusCode: 417
            )))
            return
        }

        // iOS 18+: registration matched excludedCredentials.
        if nsError.domain == ASAuthorizationError.errorDomain, nsError.code == 1006 {
            finish(.failure(alreadyEnrolledError()))
            return
        }

        var message = nsError.localizedDescription
        if message.isEmpty || message == "(null)" {
            message = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                ?? "Passkey authorization failed (ASAuthorizationError \(nsError.code))"
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            let detail = underlying.localizedDescription
            if !detail.isEmpty, detail != "(null)" {
                message += " — \(detail)"
            }
        }
        if nsError.domain == ASAuthorizationError.errorDomain, nsError.code == 1004 {
            message += " Hint: host https://<rp.id>/.well-known/apple-app-site-association with webcredentials.apps containing <TeamID>.<BundleID>, and add Associated Domains entitlement webcredentials:<rp.id>. Current AASA must not be a placeholder."
        } else if message.lowercased().contains("not associated")
            || message.lowercased().contains("associated domain")
            || message.lowercased().contains("webcredentials") {
            message += " — ensure Associated Domains includes webcredentials:<rp.id> and AASA is hosted on the RP."
        }
        finish(.failure(WebAuthError.shared.serviceFailureException(
            errorCode: WebAuthErrorCode.PROPERT_MISSING.rawValue,
            errorMessage: message,
            statusCode: 417
        )))
    }
}

@available(iOS 15.0, *)
extension PasskeyCredentialHelper: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let presentationAnchor {
            return presentationAnchor
        }
        if let key = Self.keyWindow() {
            return key
        }
        assertionFailure("Passkey presentation anchor missing")
        return ASPresentationAnchor()
    }
}
