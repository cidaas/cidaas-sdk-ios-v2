# V3 API Guide

Part of the [Cidaas iOS SDK Integration Guide](../README.md). Use V3 builders in `Cidaas/Classes/V3/` for browser auth, MFA, user accounts and device registration.

**Prerequisites:** Complete [Quick Start](../README.md#quick-start) and [SDK Configuration](../README.md#sdk-configuration) first.

## Table of Contents

- [Browser Authentication](#browser-authentication)
- [User Accounts](#user-accounts)
- [MFA](#mfa)
- [Device Registration](#device-registration)

---


All V3 builders assume OAuth properties are loaded (`Cidaas.plist` via `readPropertyFile()` or `setURL(...)`). The plist loads asynchronously — wait until properties are available before calling V3 APIs (see [SDK Configuration](../README.md#sdk-configuration)).

**Typical app setup** (from the demo app):

```swift
import Cidaas

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Cidaas.shared.readPropertyFile()
        return true
    }
}

/// Call before any V3 API. Retries until OAuth properties are in `DBHelper`.
func ensureCidaasConfigured(completion: @escaping (Result<Void, Error>) -> Void) {
    if DBHelper.shared.getPropertyFile() != nil {
        completion(.success(()))
        return
    }
    Cidaas.shared.readPropertyFile()
    pollForProperties(attemptsRemaining: 40, completion: completion)
}

private func pollForProperties(attemptsRemaining: Int, completion: @escaping (Result<Void, Error>) -> Void) {
    if DBHelper.shared.getPropertyFile() != nil {
        completion(.success(()))
        return
    }
    guard attemptsRemaining > 0 else {
        completion(.failure(NSError(domain: "app", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "OAuth properties not loaded. Check Cidaas.plist is in the app target."
        ])))
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        pollForProperties(attemptsRemaining: attemptsRemaining - 1, completion: completion)
    }
}
```

Flows that need an OAuth `requestId` (password reset, account verification, MFA authentication) fetch it first:

```swift
func fetchOAuthRequestId(completion: @escaping (Result<String, Error>) -> Void) {
    ensureCidaasConfigured { configured in
        guard case .success = configured else {
            completion(.failure(NSError(domain: "app", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "SDK not configured"
            ])))
            return
        }
        CidaasNative.shared.getRequestId(extraParams: [:]) { result in
            switch result {
            case .success(result: let entity):
                completion(.success(entity.data.requestId))
            case .failure(error: let error):
                completion(.failure(error))
            }
        }
    }
}
```

---

## Browser Authentication

Builder: `CidaasWebAuthBuilder`

### Purpose

Presents the hosted login, registration or social page in the system browser and exchanges the authorization code for tokens.

### Entry point

```swift
let builder = Cidaas.shared.webAuth(delegate: viewController)
```

| Parameter | Required | Default | Notes |
|-----------|----------|---------|-------|
| `delegate` | **Yes** | — | Live `UIViewController` for `ASWebAuthenticationSession`. The call fails if the delegate is deallocated before `signIn` or `signOut`. |

### Optional builder steps

Call zero or one flow selector and any number of `extraParameters` calls:

| Method | Required | Default | Returns |
|--------|----------|---------|---------|
| `extraParameters(_:)` | No | `[:]` | `Self` — OAuth query params (`scopes`, `prompt`, `ui_locales`, …) |
| `registration()` | No | login flow | `Self` — opens hosted **registration** page |
| `social(provider:requestId:)` | No | login flow | `Self` — both args must be non-empty when used |

### Terminal methods

| Method | Required params | Returns | Errors |
|--------|-----------------|---------|--------|
| `signIn(completion:)` | — | `Result<LoginResponseEntity>` | `WebAuthError` (cancelled, network, config, …) |
| `signIn()` async | — | `LoginResponseEntity` | throws `WebAuthError` (iOS 13+) |
| `signOut(sub:completion:)` | non-empty `sub` | `Result<Bool>` | `WebAuthError` if `sub` empty or delegate missing |
| `signOut(sub:)` async | non-empty `sub` | `Bool` | throws `WebAuthError` (iOS 13+) |

**Response:** `LoginResponseEntity.data` is an `AccessTokenEntity` with `access_token`, `refresh_token`, `id_token`, `sub` and `expires_in`.

### `Cidaas.WebAuth` static helpers

| Method | Purpose |
|--------|---------|
| `handleRedirect(_ url: URL)` | Forward OAuth callback when using a **custom** browser (not needed for standard login) |
| `authorizationURL(for:extraParameters:completion:)` | Build authorization URL without presenting browser |
| `authorizationURL(for:extraParameters:)` async | Same, async (iOS 13+) |

`BrowserAuthFlow`: `.login`, `.registration`, `.social`. For `.social`, pass `provider` and `requestId` in `extraParameters`.

### Examples

**Complete browser login**:

```swift
final class LoginViewController: UIViewController {

    private var accessToken: String = ""
    private var userSub: String = ""

    func signIn() {
        ensureCidaasConfigured { [weak self] configured in
            guard let self, case .success = configured else { return }
            Cidaas.shared
                .webAuth(delegate: self)
                .extraParameters(["scopes": "offline_access openid profile email"])
                .signIn { result in
                    switch result {
                    case .success(result: let login):
                        self.accessToken = login.data.access_token
                        self.userSub = login.data.sub
                        // Persist tokens securely (Keychain recommended)
                    case .failure(error: let error):
                        print("Login failed: \(error.errorMessage)")
                    }
                }
        }
    }

    func signOut() {
        guard !userSub.isEmpty else { return }
        Cidaas.shared
            .webAuth(delegate: self)
            .signOut(sub: userSub) { result in
                if case .success = result {
                    self.accessToken = ""
                    self.userSub = ""
                }
            }
    }
}
```

**Registration and social login:**

```swift
// Registration — hosted sign-up page (not login)
ensureCidaasConfigured { configured in
    guard case .success = configured else { return }
    Cidaas.shared
        .webAuth(delegate: viewController)
        .registration()
        .signIn { result in /* handle LoginResponseEntity */ }
}

// Social login — fetch requestId first, then:
fetchOAuthRequestId { requestIdResult in
    guard case .success(let requestId) = requestIdResult else { return }
    Cidaas.shared
        .webAuth(delegate: viewController)
        .social(provider: "google", requestId: requestId)
        .signIn { result in /* handle LoginResponseEntity */ }
}
```

**Async sign-in** (iOS 13+):

```swift
let login = try await Cidaas.shared
    .webAuth(delegate: viewController)
    .extraParameters(["scopes": "openid profile email offline_access"])
    .signIn()
let token = login.data.access_token
let sub = login.data.sub
```

Sign-in and sign-out in [Quick Start — Step 6](../README.md#step-6-implement-login-and-logout) use the same builder pattern.


---

## User Accounts

Builder: `CidaasUsersBuilder`

### Purpose

Password reset, change/set password (authenticated), account verification (email or mobile) and OpenID Connect userinfo.

### Entry point

```swift
let users = Cidaas.users()
```

Requires OAuth properties from `readPropertyFile()` or `setURL(...)`.

### Methods

| Method | Required | Async (iOS 13+) | Returns |
|--------|----------|-----------------|---------|
| `passwordReset(_:completion:)` | `CidaasPasswordResetAction` | `passwordReset(_:)` | `CidaasPasswordResetOutcome` |
| `changePassword(accessToken:_:completion:)` | non-empty token, `CidaasChangePasswordAction` | `changePassword(accessToken:_:)` | `CidaasChangePasswordOutcome` |
| `setPassword(accessToken:_:completion:)` | non-empty token, `CidaasSetPasswordAction` | `setPassword(accessToken:_:)` | `CidaasSetPasswordOutcome` |
| `accountVerification(_:completion:)` | `CidaasAccountVerificationAction` | `accountVerification(_:)` | `CidaasAccountVerificationOutcome` |
| `fetchUserInfo(sub:completion:)` | non-empty `sub` | `fetchUserInfo(sub:)` | `UserInfoEntity` |
| `fetchUserInfo(accessToken:completion:)` | non-empty token | `fetchUserInfo(accessToken:)` | `UserInfoEntity` |

### Password reset flow

Three-step unauthenticated flow. Fetch an OAuth `requestId` before initiating (see prerequisites above).

```swift
func passwordReset(email: String, otpCode: String, newPassword: String) {
    fetchOAuthRequestId { requestIdResult in
        guard case .success(let requestId) = requestIdResult else { return }

        // Step 1 — Initiate
        var initiate = InitiateResetPasswordEntity()
        initiate.requestId = requestId
        initiate.resetMedium = "email"
        initiate.email = email
        initiate.processingType = "code"   // tenant-specific; demo uses "code"

        Cidaas.users().passwordReset(.initiate(initiate)) { initiateResult in
            guard case .success(result: let outcome) = initiateResult,
                  case .initiate(let initResp) = outcome else { return }
            let resetRequestId = initResp.data.rprq

            // Step 2 — Validate OTP from email/SMS
            var validate = HandleResetPasswordEntity()
            validate.code = otpCode
            validate.resetRequestId = resetRequestId

            Cidaas.users().passwordReset(.validate(validate)) { validateResult in
                guard case .success(result: let valOutcome) = validateResult,
                      case .validate(let valResp) = valOutcome else { return }

                // Step 3 — Accept new password
                var accept = ResetPasswordEntity()
                accept.password = newPassword
                accept.confirmPassword = newPassword
                accept.exchangeId = valResp.data.exchangeId
                accept.resetRequestId = valResp.data.resetRequestId

                Cidaas.users().passwordReset(.accept(accept)) { acceptResult in
                    guard case .success(result: let acceptOutcome) = acceptResult,
                          case .accept(let acceptResp) = acceptOutcome else { return }
                    print(acceptResp.data.reseted)
                }
            }
        }
    }
}
```

### Change password flow

For a signed-in user with an access token (typically `profile` scope). Requires `old_password`, `new_password`, `confirm_password`, and at least one of `sub` or `identityId`. Optional `logout_option` controls session behaviour after the change.

```swift
func changePassword(
    accessToken: String,
    sub: String,
    oldPassword: String,
    newPassword: String
) {
    ensureCidaasConfigured { configured in
        guard case .success = configured else { return }
        var entity = ChangePasswordEntity()
        entity.sub = sub
        entity.old_password = oldPassword
        entity.new_password = newPassword
        entity.confirm_password = newPassword
        entity.logout_option = ""   // optional

        Cidaas.users().changePassword(accessToken: accessToken, .change(entity)) { result in
            switch result {
            case .success(result: let outcome):
                if case .change(let response) = outcome {
                    print(response.data.changed)
                }
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }
    }
}
```

### Set password flow

For a signed-in user who has no password yet. Requires matching `password` and `confirmPassword`.

```swift
func setPassword(accessToken: String, password: String, confirmPassword: String) {
    ensureCidaasConfigured { configured in
        guard case .success = configured else { return }
        var entity = SetPasswordEntity()
        entity.password = password
        entity.confirmPassword = confirmPassword

        Cidaas.users().setPassword(accessToken: accessToken, .set(entity)) { result in
            switch result {
            case .success(result: let outcome):
                if case .set(let response) = outcome {
                    print(response.data.saved)
                }
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }
    }
}
```

### Account verification flow

Two-step flow to verify an email or mobile number on the user profile. Fetch an OAuth `requestId` before initiating.

**Initiate** requires `requestId`, `verificationMedium`, `processingType` and at least one of `email` or `mobile`. **Validate** requires `accvid` from the initiate response and the code delivered to the user.

```swift
func verifyAccountEmail(email: String, otpCode: String) {
    fetchOAuthRequestId { requestIdResult in
        guard case .success(let requestId) = requestIdResult else { return }

        var initiate = InitiateAccountVerificationEntity()
        initiate.requestId = requestId
        initiate.verificationMedium = "email"
        initiate.processingType = "code"
        initiate.email = email

        Cidaas.users().accountVerification(.initiate(initiate)) { initiateResult in
            guard case .success(result: let outcome) = initiateResult,
                  case .initiate(let initResp) = outcome else { return }
            let accvid = initResp.data.accvid

            var verify = VerifyAccountEntity()
            verify.accvid = accvid
            verify.code = otpCode

            Cidaas.users().accountVerification(.validate(verify)) { validateResult in
                guard case .success(result: let valOutcome) = validateResult,
                      case .validate(let valResp) = valOutcome else { return }
                print(valResp.success)
            }
        }
    }
}
```

For mobile verification set `verificationMedium = "mobile"` and populate `mobile` instead of `email`.

### Fetch user info

```swift
func loadUserProfile(accessToken: String, sub: String) {
    ensureCidaasConfigured { configured in
        guard case .success = configured else { return }

        // Option A — by access token (explicit)
        Cidaas.users().fetchUserInfo(accessToken: accessToken) { result in
            switch result {
            case .success(result: let user):
                print(user.email, user.given_name, user.family_name)
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }

        // Option B — by sub (uses token stored by SDK for that sub)
        Cidaas.users().fetchUserInfo(sub: sub) { result in
            switch result {
            case .success(result: let user):
                print(user.sub, user.preferred_username)
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }
    }
}

// Async (iOS 13+)
let user = try await Cidaas.users().fetchUserInfo(accessToken: accessToken)
```


---

## MFA

Builder: `CidaasMFABuilder`

### Purpose

MFA enrollment and step-up authentication through typed builders. **Enrollment** requires passing values from each step's result to the next; **authentication** may reuse session state on the same builder (see Authentication branch).

### Entry points

```swift
let mfa = Cidaas.mfa(.totp)   // or .push, .sms, .pattern, …

// Shorthand: initiation, then scan when required (pattern/push/touch/face)
Cidaas.mfaEnrollmentSetup(.sms, accessToken: token, sub: userSub) { result in … }

// Device MFA management — not tied to a verification type
Cidaas.mfaSupport().pendingNotifications(incomingData: req) { … }
```

**Verification types** (`CidaasMFAVerificationType`):

`.pattern`, `.push`, `.touchId`, `.totp`, `.face`, `.email`, `.sms`, `.ivr`, `.backupCode`

### Root builder (`CidaasMFABuilder`)

| Method | Parameters | Returns |
|--------|------------|---------|
| `enrollment()` | — | `CidaasMFAEnrollmentBuilder` |
| `authentication()` | — | `CidaasMFAAuthenticationBuilder` |
| `support()` | — | `CidaasMFASupportBuilder`; set `DeleteRequest.verificationType` on delete requests |

Pass values from each enrollment step's result to the next call (`setupExchangeId` → `scanned`, then `enrollmentExchangeId` → `verification`). For PUSH enrollment, always pass `pushNumber` — the number the user selected from `pushRandomNumbers`.

### Enrollment branch

| Method | Required | Returns |
|--------|----------|---------|
| `initiation(accessToken:sub:completion:)` | at least one of `accessToken` or `sub` | `CidaasMFAEnrollmentInitiationResult` |
| `scanned(sub:exchangeId:completion:)` | `sub` + `exchangeId` from initiation | `CidaasMFAEnrollmentScannedResult` |
| `enrollmentSetup(accessToken:sub:completion:)` | same as initiation | `CidaasMFAEnrollmentSetupResult` — runs `scanned` only for pattern/push/touch/face |
| `verification(exchangeId:…)` | `exchangeId` + type-specific pass code | `EnrollResponse` |

**Scan step:** required for **PATTERN, PUSH, TOUCHID, FACE** only. SMS, email, IVR and TOTP use initiation only. Backup codes complete on initiation (no scan, no verify).

**Exchange id for verify:** use `CidaasMFAEnrollmentSetupResult.enrollmentExchangeId` after `enrollmentSetup`, or pass `exchangeId` explicitly. The SDK picks the initiation exchange for SMS/email/IVR/TOTP/backup and the scan exchange for pattern/push/touch/face.

`CidaasMFAEnrollmentInitiationResult`: `sub`, `setupExchangeId`, `statusId`, `totpSecret?`, `pushSelectedNumber?`

`CidaasMFAEnrollmentSetupResult`: `verificationType`, `initiation`, `scanned?`, `scanWasPerformed`, `enrollmentExchangeId`

### Enrollment patterns

Most verification types follow one of three patterns. Reuse the same builder instance across steps in a flow.

| Pattern | Types | Steps |
|---------|-------|-------|
| **OTP** | SMS, EMAIL, IVR, TOTP | `initiation` → `verification(otp:)` with `setupExchangeId` |
| **Scan + verify** | PATTERN, PUSH, TOUCHID, FACE | `enrollmentSetup` (or `initiation` + `scanned`) → `verification` with type-specific pass code |
| **Initiation only** | BACKUPCODE | `initiation` completes enrollment — no scan or verify |

**Pattern A — OTP enrollment** (SMS, email, IVR, TOTP):

```swift
let mfa = Cidaas.mfa(.sms)   // or .totp, .email, .ivr

mfa.enrollment().initiation(accessToken: accessToken, sub: userSub) { initResult in
    guard case .success(result: let setup) = initResult else { return }

    mfa.enrollment().verification(
        exchangeId: setup.setupExchangeId,
        otp: "123456"
    ) { verifyResult in
        switch verifyResult {
        case .success(result: let response):
            print(response.success)
        case .failure(error: let error):
            print(error.errorMessage)
        }
    }
}
```

**Pattern B — Scan-required enrollment** (pattern, push, touch ID, face):

```swift
let mfa = Cidaas.mfa(.pattern)   // or .push, .touchId, .face

mfa.enrollment().enrollmentSetup(accessToken: accessToken, sub: userSub) { setupResult in
    guard case .success(result: let setup) = setupResult else { return }

    // PUSH: pass pushNumber — user picks from setup.scanned?.pushRandomNumbers
    mfa.enrollment().verification(
        exchangeId: setup.enrollmentExchangeId,
        pattern: encodedPattern   // use pushNumber: for .push
    ) { verifyResult in
        print(verifyResult)
    }
}
```

**Pass code fields for `verification()`:**

| Type | Parameter |
|------|-----------|
| TOTP, SMS, EMAIL, IVR | `otp` |
| BACKUPCODE |  (enrollment completes on `initiation`; no `verification` step) |
| PATTERN | `pattern` — encoded pattern string (sent as `pass_code`; not a numeric TOTP/SMS OTP) |
| PUSH | `pushNumber` (required — user selection from `scanned.pushRandomNumbers`) |
| TOUCHID | empty pass code; SDK uses biometrics via `localizedReason` |
| FACE | empty pass code + optional `photo: UIImage` (face sample uploaded on verify) |

For **PATTERN** enrollment and authentication, the backend expects the **pattern encoding** in `pass_code` (compared against the value stored at enrollment). It does not run TOTP/SMS-style numeric OTP validation for PATTERN.

### Authentication branch

Endpoint: `POST /verification-srv/authentication/{method}/initiation`

| Method | Required params | Notes |
|--------|-----------------|-------|
| `initiation(requestId:usageType:sub:identifier:mediumId:completion:)` | `requestId`, `usageType` | See usage types below |
| `verification(…)` | cached or explicit `exchangeId`, `requestId`, `usageType`; type-specific pass code | Uses session cache from `initiation` |
| `pushAcknowledge(exchangeId:completion:)` | optional `exchangeId` (cached) | Call before `pushAllow` for pattern/push/touch/face |
| `pushAllow(exchangeId:completion:)` | optional `exchangeId` (cached) | Updates cached exchange id |
| `pushReject(exchangeId:reason:completion:)` | optional `exchangeId`; `reason` default `""` | Reject handoff |
| `cancelAuthentication(exchangeId:reason:completion:)` | `exchangeId`, non-empty `reason` | Cancel in-flight authentication |

**Usage types** (`UsageTypes` raw values):

| `usageType` | Pass | Do not pass |
|-------------|------|-------------|
| `INITIAL_AUTHENTICATION` | `identifier` (e.g. email), `mediumId` | `sub` |
| `MULTIFACTOR_AUTHENTICATION` | masked `sub` | `identifier` |

For **PATTERN, PUSH, TOUCHID, FACE** authentication call `pushAcknowledge` → `pushAllow` → `verification` as three separate steps. Do not verify with the initiation `exchange_id`.

**Pattern C — OTP authentication** (SMS, EMAIL, IVR, TOTP step-up):

```swift
let auth = Cidaas.mfa(.sms).authentication()

fetchOAuthRequestId { requestIdResult in
    guard case .success(let requestId) = requestIdResult else { return }

    auth.initiation(
        requestId: requestId,
        usageType: UsageTypes.INITIAL.rawValue,
        identifier: "user@example.com",
        mediumId: ""   // optional; from configured_list when required
    ) { initResult in
        guard case .success(result: let initiation) = initResult else { return }
        auth.verification(exchangeId: initiation.exchangeId, otp: "123456") { verifyResult in
            print(verifyResult)
        }
    }
}
```

**Pattern D — Step-up MFA** (logged-in user, masked sub from challenge):

```swift
let auth = Cidaas.mfa(.totp).authentication()

auth.initiation(
    requestId: requestId,
    usageType: UsageTypes.MFA.rawValue,
    sub: maskedSubFromChallenge
) { initResult in
    guard case .success = initResult else { return }
    // Session cache supplies exchangeId, requestId, usageType
    auth.verification(otp: "123456") { verifyResult in
        print(verifyResult)
    }
}
```

**Pattern E — Push/pattern/touch/face authentication** (acknowledge → allow → verify):

```swift
let auth = Cidaas.mfa(.push).authentication()

auth.initiation(requestId: requestId, usageType: UsageTypes.MFA.rawValue, sub: maskedSub) { initResult in
    guard case .success(result: let initiation) = initResult else { return }

    auth.pushAcknowledge(exchangeId: initiation.exchangeId) { ackResult in
        guard case .success = ackResult else { return }
        auth.pushAllow(exchangeId: nil) { allowResult in   // uses cached exchange id
            guard case .success = allowResult else { return }
            auth.verification(pushNumber: selectedPushNumber) { verifyResult in
                print(verifyResult)
            }
        }
    }
}
```

For **PATTERN** authentication use `verification(pattern: encodedPattern)` after allow — same encoded string as enrollment, not a numeric OTP.

**Cancel in-flight authentication:**

```swift
// Explicit exchange id
auth.cancelAuthentication(exchangeId: exchangeId, reason: "user_cancelled") { result in
    print(result)
}

// Or omit exchangeId after initiation on the same builder (uses session cache)
auth.cancelAuthentication(reason: "user_cancelled") { result in
    print(result)
}
```

### MFA support (`CidaasMFASupportBuilder`)

Device-bound MFA management APIs. Use `Cidaas.mfaSupport()` when no verification type is needed, or `Cidaas.mfa(.push).support()` for type-scoped calls.

Requires registered device context (`device_id`, `push_id`, `client_id`) on most requests — see [Device Registration](#device-registration).

#### Configured MFA methods

`configurations(sub:completion:)` returns MFA methods configured for the user on **this device**. Pass `sub` explicitly; the SDK fills `device_id` and `push_id`.

```swift
Cidaas.mfaSupport().configurations(sub: userSub) { result in
    switch result {
    case .success(result: let list):
        print(list.data.configured_list)
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

For a linked device or extra fields, use `deviceConfiguredList(incomingData:)` with a full `MFAListRequest`.

**Device context helper**:

```swift
struct MFADeviceContext {
    let clientId: String
    let deviceId: String
    let pushId: String

    static func current() -> MFADeviceContext? {
        guard let clientId = DBHelper.shared.getPropertyFile()?["ClientId"],
              !clientId.isEmpty else { return nil }
        let device = DBHelper.shared.getDeviceInfo()
        let pushId = device.pushNotificationId.isEmpty
            ? DBHelper.shared.getFCM()
            : device.pushNotificationId
        guard !device.deviceId.isEmpty, !pushId.isEmpty else { return nil }
        return MFADeviceContext(clientId: clientId, deviceId: device.deviceId, pushId: pushId)
    }
}
```

| Method | Purpose |
|--------|---------|
| `configurations(sub:completion:)` | MFA methods on this device |
| `pendingNotifications(incomingData:completion:)` | List pending push authentications for the device |
| `history(incomingData:completion:)` | MFA usage history for a verification type and time range |
| `timeline(incomingData:completion:)` | Timeline details for a `status_id` from authentication |
| `configuredDeviceList(incomingData:completion:)` | Devices linked to the user |
| `deviceConfiguredList(incomingData:completion:)` | MFA methods configured on this device (optionally for a linked device) |
| `updateFCMToken(incomingData:completion:)` | Update push token after FCM refresh |
| `delete(incomingData:completion:)` | Remove one MFA method (`DeleteRequest.verificationType`) |
| `deleteAll(incomingData:completion:)` | Remove all MFA methods for the user on this device |
| `deleteDevice(incomingData:completion:)` | Unlink a device from MFA |
| `passwordlessContinue(incomingData:completion:)` | Complete passwordless login after MFA approval |

**Pending push notifications** (complete example):

```swift
guard let ctx = MFADeviceContext.current() else { return }

let req = PendingNotificationRequest()
req.sub = userSub
req.client_id = ctx.clientId
req.device_id = ctx.deviceId
req.push_id = ctx.pushId

Cidaas.mfaSupport().pendingNotifications(incomingData: req) { result in
    switch result {
    case .success(result: let resp):
        for item in resp.data {
            print(item.exchange_id, item.verification_type)
        }
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

**Remove one MFA method:**

```swift
let req = DeleteRequest()
req.sub = userSub
req.client_id = ctx.clientId
req.device_id = ctx.deviceId
req.push_id = ctx.pushId
req.verificationType = CidaasMFAVerificationType.sms.rawValue

Cidaas.mfaSupport().delete(incomingData: req) { result in
    print(result)
}
```

> MFA APIs use completion handlers only. Wrap with `withCheckedThrowingContinuation` for async in your app.


---

## Device Registration

Builder: `CidaasDevice`

### Purpose

Registers the current device using server-directed attestation (Apple App Attest or Firebase App Check) plus DPoP and biometric proof headers.

**Requires:** iOS 14+, physical device, `NSFaceIDUsageDescription` in host app `Info.plist`.

### Entry point

```swift
let device = Cidaas.device()
```

### Methods

| Method | Required params | Returns | Errors |
|--------|-----------------|---------|--------|
| `registerDevice(clientId:pushId:completion:)` | non-empty `clientId`, `pushId` | `Result<DeviceRegistrationVerifyResult>` | App Attest unavailable, missing config, network |
| `registerDevice(clientId:pushId:)` async | same | `DeviceRegistrationVerifyResult` | throws `WebAuthError` or underlying error |

**Success response:** `DeviceRegistrationVerifyResult` with `deviceId`.

**Complete registration** (iOS 14+, physical device):

```swift
@available(iOS 14.0, *)
func registerDeviceForMFA(pushId: String) {
    ensureCidaasConfigured { configured in
        guard case .success = configured else { return }
        guard let clientId = DBHelper.shared.getPropertyFile()?["ClientId"],
              !clientId.isEmpty else { return }

        Cidaas.device().registerDevice(clientId: clientId, pushId: pushId) { result in
            switch result {
            case .success(result: let verify):
                print("Registered deviceId:", verify.deviceId)
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }
    }
}

// Async
let verify = try await Cidaas.device().registerDevice(clientId: clientId, pushId: pushId)
```

**Firebase App Check provider** — set before `registerDevice` when the server returns `provider: firebase`:

```swift
CidaasDevice.firebaseAppCheckTokenProvider = {
    try await AppCheck.appCheck().token(forcingRefresh: false).token
}
```

Add `NSFaceIDUsageDescription` to your app `Info.plist`. Simulator cannot complete Apple App Attest attestation.

---

