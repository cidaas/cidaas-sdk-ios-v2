# Cidaas iOS SDK v3 Module Guide

This document covers only `Cidaas/Classes/v3/` and is intended for app developers integrating the v3 API surface.

## Quick Start

### 1) Install and import

Use Swift Package Manager and add the `Cidaas` package to your app target, then:

```swift
import Cidaas
```

### 2) Add required config

Add `Cidaas.plist` to your app bundle with at least:

```xml
<key>DomainURL</key>
<string>https://your-cidaas-domain</string>
<key>ClientId</key>
<string>your-client-id</string>
<key>RedirectURL</key>
<string>your-app://callback</string>
```

### 3) Platform and availability

- Package deployment target: iOS 11+
- `async/await` convenience APIs: iOS 13+
- Device registration API (`Cidaas.device()`): iOS 14+

---

## Module Overview

v3 exposes these public entry points:

- `Cidaas.shared.webAuth(delegate:)` -> `CidaasWebAuthBuilder`
- `Cidaas.WebAuth` static helpers (`handleRedirect`, `authorizationURL`)
- `Cidaas.users()` -> `CidaasUsersBuilder`
- `Cidaas.mfa(_:)` -> `CidaasMFABuilder`
- `Cidaas.device()` -> `CidaasDevice`

---

## Builder Pattern in v3

### BrowserAuth builder flow

1. Create builder with presenter: `Cidaas.shared.webAuth(delegate:)`
2. Optional configuration:
   - `extraParameters(_:)`
   - `registration()`
   - `social(provider:requestId:)`
3. Execute terminal method:
   - `signIn(...)`
   - `signOut(sub:...)`

### MFA builder flow

1. Create root builder: `Cidaas.mfa(.totp)` (or `.push`, `.pattern`, etc.)
2. Choose branch:
   - `enrollment()`
   - `authentication()`
   - `support()`
3. Execute branch methods.

The MFA builders cache intermediate values (`sub`, `exchangeId`, etc.) to reduce parameter repetition across a flow.

### Users builder flow

`Cidaas.users()` is a facade-style builder:
- password reset actions
- account verification actions
- user info fetch methods

### Device API flow

`Cidaas.device().registerDevice(...)` is a single high-level flow that internally performs:
- initiation request
- App Attest proof creation
- verification request

---

## Public API Reference

## Browser Authentication (`CidaasWebAuthBuilder`)

### Entry point

```swift
let webAuth = Cidaas.shared.webAuth(delegate: self)
```

- **Required**: `delegate` (`UIViewController`) used to present system browser auth UI.
- **Failure**: if the delegate is deallocated before execution, completion returns failure.

### Configuration methods

`extraParameters(_ params: [String: String]) -> Self`
- **Optional**
- Default: empty dictionary
- Applies to login and registration URL construction.

`registration() -> Self`
- **Optional**
- Default mode is login if neither `registration()` nor `social(...)` is called.

`social(provider: String, requestId: String) -> Self`
- **Optional**
- Both parameters must be non-empty.

### Terminal methods

`signIn(completion:)`
- Returns `Result<LoginResponseEntity>`
- Uses configured mode (login, registration, or social)

`signIn() async throws -> LoginResponseEntity` (iOS 13+)

`signOut(sub:completion:)`
- **Required**: non-empty `sub`
- Returns `Result<Bool>`

`signOut(sub:) async throws -> Bool` (iOS 13+)

### Static helpers (`Cidaas.WebAuth`)

`handleRedirect(_ url: URL)`
- Pass callback URL from app/scene delegate when needed.

`authorizationURL(for:extraParameters:completion:)`
`authorizationURL(for:extraParameters:) async throws -> URL` (iOS 13+)
- Useful when you need URL preview or custom browser handling.
- For `.social`, `extraParameters["provider"]` and `extraParameters["requestId"]` are required.

### Completion-handler example

```swift
Cidaas.shared
    .webAuth(delegate: self)
    .extraParameters(["prompt": "login", "ui_locales": "en"])
    .signIn { result in
        switch result {
        case .success(result: let login):
            print("Access token: \(login.access_token)")
        case .failure(error: let error):
            print("Login failed: \(error.localizedDescription)")
        }
    }
```

### Async/await example

```swift
@available(iOS 13.0, *)
func performLogin() async {
    do {
        let login = try await Cidaas.shared
            .webAuth(delegate: self)
            .registration()
            .signIn()
        print("Login success: \(login.access_token)")
    } catch {
        print("Login failed: \(error.localizedDescription)")
    }
}
```

---

## User Accounts (`CidaasUsersBuilder`)

### Entry point

```swift
let users = Cidaas.users()
```

### Password reset

`passwordReset(_:completion:)`
`passwordReset(_:) async throws` (iOS 13+)

Input enum:
- `.initiate(InitiateResetPasswordEntity)`
- `.validate(HandleResetPasswordEntity)`
- `.accept(ResetPasswordEntity)`

Output enum:
- `CidaasPasswordResetOutcome.initiate(...)`
- `CidaasPasswordResetOutcome.validate(...)`
- `CidaasPasswordResetOutcome.accept(...)`

### Account verification

`accountVerification(_:completion:)`
`accountVerification(_:) async throws` (iOS 13+)

Input enum:
- `.initiate(InitiateAccountVerificationEntity)`
- `.validate(VerifyAccountEntity)`

Output enum:
- `CidaasAccountVerificationOutcome.initiate(...)`
- `CidaasAccountVerificationOutcome.validate(...)`

### User info

`fetchUserInfo(sub:completion:)`
`fetchUserInfo(sub:) async throws` (iOS 13+)

`fetchUserInfo(accessToken:completion:)`
`fetchUserInfo(accessToken:) async throws` (iOS 13+)

### Example

```swift
Cidaas.users().fetchUserInfo(sub: "user-sub") { result in
    switch result {
    case .success(result: let userInfo):
        print("Email: \(userInfo.email)")
    case .failure(error: let error):
        print("UserInfo failed: \(error.localizedDescription)")
    }
}
```

---

## MFA (`CidaasMFABuilder`)

### Entry point

```swift
let mfa = Cidaas.mfa(.totp)
```

Verification types:
- `.pattern`, `.push`, `.touchId`, `.totp`, `.face`, `.voice`, `.email`, `.sms`, `.ivr`, `.backupCode`

### Root builder methods

`enrollment() -> CidaasMFAEnrollmentBuilder`

`authentication() -> CidaasMFAAuthenticationBuilder`

`support() -> CidaasMFASupportBuilder`

`configurations(sub: String? = nil, completion: ...)`
- `sub` optional; if omitted, builder uses cached `sub` from previous initiation call.
- Fails if neither explicit nor cached `sub` is available.

### Enrollment builder methods

`initiation(accessToken: String = "", sub: String = "", completion: ...)`
- At least one of `accessToken` or `sub` must be non-empty.
- Caches returned identifiers for subsequent calls.

`scanned(sub: String? = nil, exchangeId: String? = nil, completion: ...)`
- Uses cached values if omitted.

`verification(exchangeId: String? = nil, otp: String? = nil, pattern: String? = nil, pushNumber: String? = nil, photo: UIImage = UIImage(), voice: Data = Data(), attempt: Int = 0, localizedReason: String = "Authenticate", completion: ...)`
- `exchangeId` required (directly or via cache).
- `pushNumber` required for PUSH.
- `otp/pattern` required for most non-biometric types.

### Authentication builder methods

`initiation(sub:requestId:usageType:completion:)`
- All parameters required and non-empty.

`verification(exchangeId: String? = nil, otp: String? = nil, pattern: String? = nil, pushNumber: String? = nil, requestId: String? = nil, usageType: String? = nil, photo: UIImage = UIImage(), voice: Data = Data(), attempt: Int = 0, localizedReason: String = "Authenticate", completion: ...)`
- Uses cached values where possible.

`pushAcknowledge(exchangeId:completion:)`

`pushAllow(exchangeId:completion:)`

`pushReject(exchangeId:reason: String = "", completion:)`

### Support builder methods

Includes:
- `deleteAll`, `delete`
- `pendingNotifications`, `history`
- `updateFCM(pushId:)`, `updateFCMToken(...)`
- `passwordlessContinue(...)`
- `timeline(...)`
- `configuredDeviceList(...)`
- `deleteDevice(...)`
- `deviceConfiguredList(...)`
- `cancelQr(...)`

### Builder flow example (TOTP enrollment)

```swift
let mfa = Cidaas.mfa(.totp)

mfa.enrollment().initiation(accessToken: token, sub: userSub) { initResult in
    switch initResult {
    case .success(result: let setup):
        // Use setup.totpSecret to show QR / setup in authenticator app.
        mfa.enrollment().verification(
            exchangeId: setup.setupExchangeId,
            otp: "123456"
        ) { verifyResult in
            print(verifyResult)
        }
    case .failure(error: let error):
        print("MFA initiation failed: \(error.localizedDescription)")
    }
}
```

---

## Device Registration (`CidaasDevice`)

### Entry point

```swift
let device = Cidaas.device()
```

### Public methods

`registerDevice(clientId:pushId:completion:)` (iOS 14+)

`registerDevice(clientId:pushId:) async throws -> DeviceRegistrationVerifyResult` (iOS 14+)

Parameters:
- `clientId` (**required**, non-empty)
- `pushId` (**required**, non-empty FCM token mapped by your integration)

Return:
- `DeviceRegistrationVerifyResult` with `deviceId`

Failures can occur for:
- missing/invalid input
- missing `DomainURL` in SDK properties
- unsupported App Attest environment
- network/service failures
- malformed service responses

### Minimal setup example (completion)

```swift
Cidaas.device().registerDevice(clientId: "your-client-id", pushId: pushToken) { result in
    switch result {
    case .success(result: let value):
        print("Registered deviceId: \(value.deviceId)")
    case .failure(error: let error):
        print("Device registration failed: \(error.localizedDescription)")
    }
}
```

### Async example

```swift
@available(iOS 14.0, *)
func registerDevice(pushToken: String) async {
    do {
        let result = try await Cidaas.device().registerDevice(
            clientId: "your-client-id",
            pushId: pushToken
        )
        print("Registered deviceId: \(result.deviceId)")
    } catch {
        print("Device registration failed: \(error.localizedDescription)")
    }
}
```

---

## Configuration Flow (Recommended Order)

1. Ensure `Cidaas.plist` exists in app bundle.
2. Load/initialize SDK properties before calling v3 APIs.
3. For browser auth, always pass a live `UIViewController`.
4. For device registration:
   - run on iOS 14+ physical device
   - include `NSFaceIDUsageDescription`
   - ensure push token is available and non-empty

---

## Error Handling

All completion APIs return `Result<T>` (SDK result type). A robust pattern is:

```swift
func handle(_ error: Error) {
    if let webAuth = error as? WebAuthError {
        print("SDK error code: \(webAuth.errorCode)")
        print("SDK status: \(webAuth.statusCode)")
        print("SDK message: \(webAuth.errorMessage)")
    } else {
        print("Error: \(error.localizedDescription)")
    }
}
```

For async APIs, use `do/try/catch` and re-use the same typed error handling.

---

## Security Setup Notes

### Browser and redirect

- Redirect URI in `Cidaas.plist` must match your tenant app registration.
- Call `Cidaas.WebAuth.handleRedirect(_:)` from app/scene URL handler when your integration path requires it.

### Device registration

- Requires App Attest support (iOS 14+ and supported device/environment).
- Uses DPoP + biometric proof headers internally for verification step.
- Host app must provide `NSFaceIDUsageDescription`.

---

## Troubleshooting / Common Mistakes

- **`file not found` / property errors**: `Cidaas.plist` missing from target or missing keys.
- **WebAuth `delegate` missing**: presenter view controller was deallocated before call.
- **Social URL/sign-in fails**: missing `provider` or `requestId`.
- **MFA validation failures**: missing required flow fields (`sub`, `exchangeId`, `requestId`, etc.).
- **Device registration fails early**:
  - running on unsupported App Attest environment
  - empty `clientId`/`pushId`
  - `DomainURL` not configured

---

## Suggested Swift Doc Comments (`///`) for Public APIs

Add/keep Apple-style comments on public entry points and terminal methods. Example style:

```swift
/// Creates a builder for hosted browser authentication flows.
/// - Parameter delegate: The view controller used to present browser authentication UI.
/// - Returns: A configured ``CidaasWebAuthBuilder``.
public func webAuth(delegate: UIViewController) -> CidaasWebAuthBuilder
```

```swift
/// Registers the current device using App Attest and proof headers.
/// - Parameters:
///   - clientId: OAuth client id from your Cidaas configuration.
///   - pushId: Push token associated with the device.
///   - completion: Returns the registered device id on success.
public func registerDevice(
    clientId: String,
    pushId: String,
    completion: @escaping (Result<DeviceRegistrationVerifyResult>) -> Void
)
```

This documentation intentionally covers only `Cidaas/Classes/v3/`.
