# Cidaas iOS SDK — Integration Guide

Integrate the Cidaas iOS SDK into your app. Use **v3 builders** in `Cidaas/Classes/v3/` for browser auth, MFA, user accounts and device registration. **Core** covers configuration, token storage and TLS pinning. **V2** modules remain for embedded WebView login, native credentials and consent where no v3 wrapper exists.

[cidaas](https://www.cidaas.com) provides SSO (OAuth 2.0 / OpenID Connect), MFA, passwordless login, social login, native login, consent flows, user account management and device registration.

**Start here:** [Quick Start](#quick-start) → [Module API Guide v3](#module-api-guide-v3)

**Also covered:** token storage, async helpers, TLS pinning, DPoP and biometric proofs.

---

## Table of Contents

- [Quick Start](#quick-start)
- [SDK Module Map](#sdk-module-map)
- [Platform Requirements](#platform-requirements)
- [Next Steps](#next-steps)
- [Builder Pattern](#builder-pattern)
- [SDK Configuration](#sdk-configuration)
- [Module API Guide v3](#module-api-guide-v3)
- [Core APIs](#core-apis)
- [Embedded WebView Login](#embedded-webview-login)
- [Native APIs](#native-apis)
- [Consent](#consent)
- [Async/Await Helpers](#asyncawait-helpers)
- [Shared Models and Storage](#shared-models-and-storage)
- [Advanced Configuration](#advanced-configuration)
- [Error Handling](#error-handling)
- [Security Setup](#security-setup)
- [Troubleshooting](#troubleshooting)
- [Migrating to Cidaas V3](#migrating-to-cidaas-v3)
- [Getting Client Id and URLs](#getting-client-id-and-urls)
- [API Choice Guide](#api-choice-guide)

---

## Quick Start

Get **browser login** working with v3 `webAuth`. Follow the steps below in order. Detailed plist keys, portal settings and API reference live in linked sections — not repeated here.

### Step 1 — Create a project

In Xcode:

1. **File → New → Project** (⌘+Shift+N)
2. Select **iOS → App**, set **Language** to Swift
3. Choose SwiftUI or Storyboard and click **Create**

Pick a **Bundle Identifier** you can register in the Cidaas portal and in redirect URL settings.

### Step 2 — Add the Cidaas SDK

Add the **`Cidaas`** package with Swift Package Manager — see [Installation](#installation). Link the **`Cidaas`** library to your app target. CocoaPods isn't supported.

```swift
import Cidaas
```

### Step 3 — Configure your Cidaas tenant

In the Cidaas admin portal create or open an **App / Client**. Register allowed redirect and logout redirect URLs for your app. See [Getting Client Id and URLs](#getting-client-id-and-urls) for Client ID, Domain URL, scopes and grant types.

### Step 4 — Add app configuration

Add `Cidaas.plist` to your app target and register the redirect URL scheme in `Info.plist`. Full templates, key reference and URL scheme setup are in [SDK Configuration](#sdk-configuration).

### Step 5 — Initialize the SDK

Call at launch before any v3 API:

```swift
Cidaas.shared.readPropertyFile()
```

The SDK loads `Cidaas.plist` asynchronously. Wait until OAuth properties are available before calling `webAuth`. Programmatic config and runtime flags: [SDK Configuration](#sdk-configuration).

### Step 6 — Implement login and logout

Present login from a live view controller. The SDK uses `ASWebAuthenticationSession` and handles the OAuth redirect.

**Sign in:**

```swift
Cidaas.shared
    .webAuth(delegate: viewController)
    .extraParameters(["scopes": "openid profile email offline_access"])
    .signIn { result in
        switch result {
        case .success(result: let login):
            let token = login.data.access_token
            let sub = login.data.sub
            // Store token and sub securely in your app
        case .failure(error: let error):
            print("Login failed: \(error.errorMessage)")
        }
    }
```

**Sign out:**

```swift
Cidaas.shared
    .webAuth(delegate: viewController)
    .signOut(sub: userSub) { result in
        switch result {
        case .success:
            // Clear stored session
        case .failure(error: let error):
            print("Logout failed: \(error.errorMessage)")
        }
    }
```

Registration, social login and async `signIn()` — [Browser Authentication](#browser-authentication). Error handling — [Error Handling](#error-handling).

### Step 7 — Run your app

Build and run in Xcode (⌘+R). Tap your login action, complete sign-in in the system browser and confirm tokens arrive in the completion handler.

> You have working v3 browser login. Continue with [Next Steps](#next-steps) for MFA, user accounts and device registration.

---

## Platform Requirements

| Capability | Minimum iOS | Notes |
|------------|-------------|-------|
| SDK package | iOS 11+ | Deployment target in `Package.swift` |
| `async/await` v3 helpers | iOS 13+ | Browser auth, user accounts |
| Device registration | iOS 14+ | Physical device; App Attest or Firebase App Check |
| DPoP / biometric HTTP proofs | iOS 14+ | `Cidaas.shared.useDpop`, `useBiometric` |
| MFA builders | iOS 11+ | Completion-handler APIs only (no async MFA wrappers) |
| `Cidaas+AsyncAwait` extension | iOS 13+ | Convenience wrappers on `Cidaas.shared` |

---

## SDK Module Map

The SDK ships as one **`Cidaas`** Swift Package with three layers. Use **v3** for browser auth, MFA, user accounts and device registration.

| Layer | Path | Entry point | Use when |
|-------|------|-------------|----------|
| **v3** | `Classes/v3/` | `Cidaas.shared.webAuth`, `.users()`, `.mfa()`, `.device()` | **Default** — browser auth, MFA, password reset, account verification, user info, device registration |
| **Core** | `Classes/Core/` | `Cidaas.shared`, `CidaasView` | Config, token refresh, WebView login, pinning |
| **Native (V2)** | `Classes/V2/Native/` | `CidaasNative.shared` | Native login UI, registration fields, link/unlink, deduplication |
| **Consent (V2)** | `Classes/V2/Consent/` | `CidaasConsent.shared` | OAuth consent screens (no v3 wrapper) |

### v3 entry points

| Entry point | Returns | Purpose |
|-------------|---------|---------|
| `Cidaas.shared.webAuth(delegate:)` | `CidaasWebAuthBuilder` | Browser login, registration, social login and logout |
| `Cidaas.WebAuth` | Static helpers | Custom browser integrations |
| `Cidaas.users()` | `CidaasUsersBuilder` | User info, password reset and account verification |
| `Cidaas.mfa(_:)` | `CidaasMFABuilder` | MFA enrollment and authentication |
| `Cidaas.device()` | `CidaasDevice` | Device registration with attestation proofs |

### Core and V2 entry points (no v3 wrapper)

| Entry point | Purpose |
|-------------|---------|
| `Cidaas.shared` | Config, token refresh and session storage |
| `CidaasView` | Embedded `WKWebView` OAuth login |
| `CidaasNative.shared` | Native credentials login, registration, link/unlink |
| `CidaasConsent.shared` | Consent details, accept, continue |

v3 completion APIs return the SDK `Result<T>` type — see [Shared Models and Storage](#shared-models-and-storage).

### Installation

The SDK ships through **Swift Package Manager** only:

```text
https://github.com/Cidaas/cidaas-sdk-ios-v2
```

Select the **`Cidaas`** library product when adding the package.

---

## Next Steps

After browser login works, open the [Module API Guide v3](#module-api-guide-v3) for MFA, user accounts and device registration.

---

## Builder Pattern

v3 uses fluent builders. Chain configuration methods, then call a **terminal method** to run the flow.

### Browser auth

```
Cidaas.shared.webAuth(delegate:)
    → [optional: extraParameters / registration / social]
    → signIn() or signOut(sub:)
```

Optional steps change the hosted page or OAuth parameters. Skip them all to use **login** with no extra parameters.

**MFA**

```
Cidaas.mfa(.totp)
    → enrollment() | authentication()
    → branch methods (initiation, verification, pushAllow, …)
    → configurations(sub:) on the root builder
```

MFA builders cache `sub`, exchange ids and push selection between steps — see [MFA](#mfa).

**User accounts**

```
Cidaas.users()
    → passwordReset(.initiate | .validate | .accept)
    → accountVerification(.initiate | .validate)
    → fetchUserInfo(sub:) | fetchUserInfo(accessToken:)
```

**Device registration**

```
Cidaas.device().registerDevice(clientId:pushId:)
```

Single public method. Internally runs initiate → attestation → verify with DPoP and biometric proofs.

---

## SDK Configuration

Load configuration from `Cidaas.plist` or set it on `Cidaas.shared`. Use this section when completing [Quick Start — Step 4](#step-4-add-app-configuration).

### `Cidaas.plist`

Create `Cidaas.plist` in your app target:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DomainURL</key>
    <string>https://your-cidaas-domain</string>
    <key>ClientId</key>
    <string>your-client-id</string>
    <key>RedirectURL</key>
    <string>myapp://callback</string>
    <key>PostLogoutRedirectURL</key>
    <string>myapp://callback</string>
    <key>CidaasVersion</key>
    <string>3</string>
</dict>
</plist>
```

| Key | Required | Description |
|-----|----------|-------------|
| `DomainURL` | Yes | Base URL of your Cidaas tenant |
| `ClientId` | Yes | OAuth client id from the portal |
| `RedirectURL` | Yes | Callback URL after login |
| `PostLogoutRedirectURL` | Yes | Callback URL after browser logout |
| `CidaasVersion` | Recommended | Set to `3` for v3 response handling |

Drag the file into Xcode and check **Add to target**. Portal values come from [Getting Client Id and URLs](#getting-client-id-and-urls).

### URL scheme

For `RedirectURL` `myapp://callback`, register scheme `myapp` in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

The scheme, plist redirect URL and portal entry must match exactly. See [Security Setup](#security-setup) for production redirect guidance.

### Load from plist

```swift
Cidaas.shared.readPropertyFile()
```

`FileHelper` reads `Cidaas.plist` from the app bundle. Default filename: `"Cidaas"`. Override with `FileHelper.shared.filename`.

### Programmatic override

Use for multi-environment builds:

```swift
Cidaas.shared.setURL(
    domainURL: "https://your-cidaas-domain",
    clientId: "your-client-id",
    redirectURL: "myapp://callback",
    userDeviceId: ""   // optional; default empty
)
```

### Runtime flags

| Property | Default | Purpose |
|----------|---------|---------|
| `ENABLE_LOG` | `false` | SDK diagnostic logging |
| `ENABLE_PKCE` | `true` | PKCE for browser token exchange; disable only if your client uses a secret |
| `useDpop` | `false` | Add `DPoP` JWT header on SDK HTTP requests (iOS 14+) |
| `useBiometric` | `false` | Add `Biometric` JWT header; may prompt Face ID / Touch ID (iOS 14+) |
| `biometricProofLocalizedReason` | `"Verify your identity"` | Prompt text when `useBiometric` is `true` |

```swift
Cidaas.shared.ENABLE_LOG = true
Cidaas.shared.useDpop = true
Cidaas.shared.useBiometric = true
Cidaas.shared.biometricProofLocalizedReason = "Verify your identity to continue"
```

> Device registration always sends DPoP and biometric proofs on verify, regardless of `useDpop` / `useBiometric`.

---

## Module API Guide v3

### Browser Authentication

<details>
<summary><strong><code>CidaasWebAuthBuilder</code></strong></summary>

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

Sign-in and sign-out samples are in [Quick Start — Step 6](#step-6-implement-login-and-logout). Optional builder steps:

```swift
// Registration — use .registration() for sign-up only, not login
let login = try await Cidaas.shared.webAuth(delegate: self).registration().signIn()

// Social login
try await Cidaas.shared
    .webAuth(delegate: self)
    .social(provider: "google", requestId: "your-request-id")
    .signIn()
```

</details>

### User Accounts

<details>
<summary><strong><code>CidaasUsersBuilder</code></strong></summary>

### Purpose

Password reset, account verification (email or mobile) and OpenID Connect userinfo.

### Entry point

```swift
let users = Cidaas.users()
```

Requires OAuth properties from `readPropertyFile()` or `setURL(...)`.

### Methods

| Method | Required | Async (iOS 13+) | Returns |
|--------|----------|-----------------|---------|
| `passwordReset(_:completion:)` | `CidaasPasswordResetAction` | `passwordReset(_:)` | `CidaasPasswordResetOutcome` |
| `accountVerification(_:completion:)` | `CidaasAccountVerificationAction` | `accountVerification(_:)` | `CidaasAccountVerificationOutcome` |
| `fetchUserInfo(sub:completion:)` | non-empty `sub` | `fetchUserInfo(sub:)` | `UserInfoEntity` |
| `fetchUserInfo(accessToken:completion:)` | non-empty token | `fetchUserInfo(accessToken:)` | `UserInfoEntity` |

### Password reset flow

Three-step flow driven by enum cases:

```swift
// 1. Initiate
let initiate = InitiateResetPasswordEntity()
initiate.resetMedium = "email"
initiate.email = "user@example.com"
initiate.requestId = "your-request-id"
initiate.processingType = "CODE"

Cidaas.users().passwordReset(.initiate(initiate)) { result in
    guard case .success(result: .initiate(let response)) = result else { return }
    let resetRequestId = response.data.rprq

    // 2. Validate with code from email/SMS
    let validate = HandleResetPasswordEntity()
    validate.code = "123456"
    validate.resetRequestId = resetRequestId

    Cidaas.users().passwordReset(.validate(validate)) { validateResult in
        guard case .success(result: .validate(let vResponse)) = validateResult else { return }

        // 3. Accept new password
        let accept = ResetPasswordEntity()
        accept.password = "NewPassword1!"
        accept.confirmPassword = "NewPassword1!"
        accept.exchangeId = vResponse.data.exchangeId
        accept.resetRequestId = vResponse.data.resetRequestId

        Cidaas.users().passwordReset(.accept(accept)) { _ in }
    }
}
```

### Account verification flow

Two-step flow to verify an email or mobile number on the user profile. Obtain an OAuth `requestId` (same as password reset) before initiating.

**Initiate** requires `requestId`, `verificationMedium`, `processingType` and at least one of `email` or `mobile`. **Validate** requires `accvid` from the initiate response and the code delivered to the user.

```swift
// 1. Initiate — send verification code
var initiate = InitiateAccountVerificationEntity()
initiate.requestId = "your-request-id"
initiate.verificationMedium = "email"   // or "mobile"
initiate.processingType = "code"
initiate.email = "user@example.com"
initiate.mobile = "+92928893" // in case of `verificationMedium` is passed as "mobile"

Cidaas.users().accountVerification(.initiate(initiate)) { result in
    guard case .success(result: .initiate(let response)) = result else { return }
    let accvid = response.data.accvid

    // 2. Validate with code from email/SMS
    var verify = VerifyAccountEntity()
    verify.accvid = accvid
    verify.code = "123456"

    Cidaas.users().accountVerification(.validate(verify)) { validateResult in
        guard case .success(result: .validate(let vResponse)) = validateResult else { return }
        print(vResponse.success)
    }
}
```

Async variants are available on iOS 13+:

```swift
let outcome = try await Cidaas.users().accountVerification(.initiate(initiate))
guard case .initiate(let response) = outcome else { return }

var verify = VerifyAccountEntity()
verify.accvid = response.data.accvid
verify.code = "123456"
_ = try await Cidaas.users().accountVerification(.validate(verify))
```

### Fetch user info

```swift
// By subject (uses stored access token for sub)
let user = try await Cidaas.users().fetchUserInfo(sub: "user-sub-id")
print(user.email)

// By access token
let user = try await Cidaas.users().fetchUserInfo(accessToken: token)
```

</details>

### MFA

<details>
<summary><strong><code>CidaasMFABuilder</code></strong></summary>

### Purpose

MFA enrollment and step-up authentication through typed builders with cached session state between steps.

### Entry points

```swift
let mfa = Cidaas.mfa(.totp)   // or .push, .sms, .pattern, …

// Shorthand: initiation, then scan when required (pattern/push/touch/face)
Cidaas.mfaEnrollmentSetup(.sms, accessToken: token, sub: userSub) { result in … }
```

**Verification types** (`CidaasMFAVerificationType`):

`.pattern`, `.push`, `.touchId`, `.totp`, `.face`, `.email`, `.sms`, `.ivr`, `.backupCode`

### Root builder (`CidaasMFABuilder`)

| Method | Parameters | Returns |
|--------|------------|---------|
| `enrollment()` | — | `CidaasMFAEnrollmentBuilder` |
| `authentication()` | — | `CidaasMFAAuthenticationBuilder` |
| `configurations(sub:completion:)` | `sub` optional (uses enrollment or auth cache) | `Result<MFAListResponse>` |

Reuse the same `CidaasMFABuilder` instance across a multi-step flow. The builder caches `sub`, exchange ids and push selection between calls.

### Enrollment branch

| Method | Required | Defaults | Returns |
|--------|----------|----------|---------|
| `initiation(accessToken:sub:completion:)` | at least one of `accessToken` or `sub` | both `""` | `CidaasMFAEnrollmentInitiationResult` |
| `scanned(sub:exchangeId:completion:)` | `sub` + `exchangeId` (or cached from initiation) | nil | `CidaasMFAEnrollmentScannedResult` |
| `enrollmentSetup(accessToken:sub:completion:)` | same as initiation | both `""` | `CidaasMFAEnrollmentSetupResult` — runs `scanned` only for pattern/push/touch/face |
| `verification(…)` | `exchangeId` (or cached); type-specific pass code | see SDK | `EnrollResponse` |

**Scan step:** required for **PATTERN, PUSH, TOUCHID, FACE** only. SMS, email, IVR and TOTP use initiation only. Backup codes complete on initiation (no scan, no verify).

**Exchange id for verify:** use `CidaasMFAEnrollmentSetupResult.enrollmentExchangeId` after `enrollmentSetup`, or pass `exchangeId` explicitly. The SDK picks the initiation exchange for SMS/email/IVR/TOTP/backup and the scan exchange for pattern/push/touch/face.

`CidaasMFAEnrollmentInitiationResult`: `sub`, `setupExchangeId`, `statusId`, `totpSecret?`, `pushSelectedNumber?`

`CidaasMFAEnrollmentSetupResult`: `verificationType`, `initiation`, `scanned?`, `scanWasPerformed`, `enrollmentExchangeId`

**TOTP enrollment (step by step):**

```swift
let mfa = Cidaas.mfa(.totp)

mfa.enrollment().initiation(accessToken: token, sub: userSub) { initResult in
    switch initResult {
    case .success(result: let setup):
        // Show setup.totpSecret as QR code in your UI
        mfa.enrollment().verification(
            exchangeId: setup.setupExchangeId,
            otp: "123456"
        ) { verifyResult in
            print(verifyResult)
        }
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

**Pattern enrollment (combined setup):**

```swift
let mfa = Cidaas.mfa(.pattern)

mfa.enrollment().enrollmentSetup(accessToken: token, sub: userSub) { result in
    switch result {
    case .success(result: let setup):
        mfa.enrollment().verification(
            exchangeId: setup.enrollmentExchangeId,
            pattern: encodedPattern
        ) { verifyResult in
            print(verifyResult)
        }
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

**Pass code fields for `verification()`:**

| Type | Parameter |
|------|-----------|
| TOTP, SMS, EMAIL, IVR, BACKUP | `otp` |
| PATTERN | `pattern` (or `otp`) |
| PUSH | `pushNumber` (or cached value from initiation) |
| TOUCHID, FACE | empty pass code; SDK uses biometrics via `localizedReason` |

### Authentication branch

Endpoint: `POST /verification-srv/authentication/{method}/initiation`

| Method | Required params | Notes |
|--------|-----------------|-------|
| `initiation(requestId:usageType:sub:identifier:mediumId:completion:)` | `requestId`, `usageType` | See usage types below |
| `verification(…)` | cached or explicit `exchangeId`, `requestId`, `usageType`; type-specific pass code | Uses session cache from `initiation` |
| `pushAcknowledge(exchangeId:completion:)` | optional `exchangeId` (cached) | Call before `pushAllow` for pattern/push/touch/face |
| `pushAllow(exchangeId:completion:)` | optional `exchangeId` (cached) | Updates cached exchange and push number |
| `pushReject(exchangeId:reason:completion:)` | optional `exchangeId`; `reason` default `""` | Reject handoff |

**Usage types** (`UsageTypes` raw values):

| `usageType` | Pass | Do not pass |
|-------------|------|-------------|
| `INITIAL_AUTHENTICATION` | `identifier` (e.g. email), optional `mediumId` | `sub` |
| `MULTIFACTOR_AUTHENTICATION` | masked `sub` | `identifier` |

For **PATTERN, PUSH, TOUCHID, FACE** authentication call `pushAcknowledge` → `pushAllow` → `verification` as three separate steps. Do not verify with the initiation `exchange_id`.

**Initial authentication example:**

```swift
let auth = Cidaas.mfa(.sms).authentication()

auth.initiation(
    requestId: requestId,
    usageType: UsageTypes.INITIAL.rawValue,
    identifier: "user@example.com"
) { result in
    guard case .success(result: let initiation) = result else { return }
    auth.verification(exchangeId: initiation.exchangeId, otp: "123456") { verifyResult in
        print(verifyResult)
    }
}
```

**Step-up MFA example:**

```swift
let auth = Cidaas.mfa(.totp).authentication()

auth.initiation(
    requestId: requestId,
    usageType: UsageTypes.MFA.rawValue,
    sub: maskedSubFromChallenge
) { result in
    guard case .success = result else { return }
    auth.verification(otp: "123456") { verifyResult in
        print(verifyResult)
    }
}
```

### Configured MFA methods

`configurations(sub:completion:)` returns the user's configured MFA methods on this device (verification-srv configured list). Pass `sub` explicitly or rely on cache from an enrollment or authentication flow on the same builder.

```swift
Cidaas.mfa(.totp).configurations(sub: userSub) { result in
    switch result {
    case .success(result: let list):
        print(list.data.configured_list)
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

> MFA APIs use completion handlers only. Wrap with `withCheckedThrowingContinuation` for async in your app.

</details>

### Device Registration

<details>
<summary><strong><code>CidaasDevice</code></strong></summary>

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

</details>

---

## Core APIs

`Cidaas.shared` (`Core/Views/Cidaas.swift`) is the root singleton for configuration and token management. Browser auth, MFA, password reset, account verification and user info use v3 builders — see [Module API Guide v3](#module-api-guide-v3).

Configuration: see [SDK Configuration](#sdk-configuration).

### Token and session management

| Method | Required params | Returns | Notes |
|--------|-----------------|---------|-------|
| `getAccessToken(sub:callback:)` | user `sub` | `Result<LoginResponseEntity>` | Reads token stored by SDK for sub |
| `getAccessToken(refreshToken:callback:)` | refresh token | `Result<LoginResponseEntity>` | Token refresh |
| `getAccessToken(requestId:socialToken:provider:viewType:extraParams:callback:)` | social flow fields | `Result<LoginResponseEntity>` | Social token exchange |
| `setAccessToken(accessTokenEntity:callback:)` | `AccessTokenEntity` | `Result<LoginResponseEntity>` | Persist token in SDK storage |

**Refresh token example:**

```swift
Cidaas.shared.getAccessToken(refreshToken: storedRefreshToken) { result in
    switch result {
    case .success(result: let login):
        let newToken = login.data.access_token
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

### Device authentication check

Local biometric or passcode check. Not the HTTP `Biometric` proof header.

```swift
Cidaas.shared.askDeviceAuthentication(
    localizedReason: "Unlock your account",
    invalidateAuthenticationContext: false
) { response in
    // Inspect DeviceAuthenticationResponseEntity
}
```

---

## Embedded WebView Login

Use `CidaasView` when OAuth runs inside your app instead of the system browser. There is no v3 wrapper.

**Location:** `Core/Views/CidaasView.swift`

### Setup

1. Add `CidaasView` in your storyboard or in code
2. Set `loaderDelegate` for loading UI
3. Forward `WKNavigationDelegate` calls to the view
4. Call `loginWithEmbeddedBrowser`

### Key APIs

| API | Required | Default | Purpose |
|-----|----------|---------|---------|
| `loginWithEmbeddedBrowser(delegate:extraParams:callback:)` | `WKNavigationDelegate` | `extraParams` `[:]` | Start embedded OAuth login |
| `loaderDelegate` | Yes for loading UI | — | `CidaasLoaderDelegate` |
| `ENABLE_BACK_BUTTON` | No | from `DBHelper` | Show back button in WebView |
| `enableNativeFacebook` / `enableNativeGoogle` | No | `false` | Route social URLs to native SDKs |
| `logout(sub:post_logout_url:)` | sub | — | WebView logout by sub |
| `logout(accessToken:post_logout_url:)` | token | — | WebView logout by token |

### WKNavigationDelegate forwarding

Forward navigation events from your view controller:

```swift
@IBOutlet var cidaasView: CidaasView!

func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    cidaasView.webView(webView, didStartProvisionalNavigation: navigation)
}

func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    cidaasView.webView(webView, didFail: navigation, withError: error)
}

func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    cidaasView.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
}

func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    cidaasView.webView(webView, didFinish: navigation)
}
```

### Login example

```swift
cidaasView.loaderDelegate = self
cidaasView.loginWithEmbeddedBrowser(delegate: self) { result in
    switch result {
    case .success(result: let login):
        print(login.data.access_token)
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

### Native social delegates

When `enableNativeFacebook` or `enableNativeGoogle` is `true`:

- `CidaasView.facebookDelegate` — `login(viewType:requestId:callback:)` and `logout()`
- `CidaasView.googleDelegate` — `login(viewType:callback:)` and `logout()`

---

## Native APIs

`CidaasNative.shared` (`V2/Native/Views/Native.swift`) exposes REST APIs for native UI where your app renders login and registration screens. Password reset, account verification and user info use v3 `Cidaas.users()`.

### Authentication

| Method | Required params | Returns |
|--------|-----------------|---------|
| `loginWithCredentials(incomingData:callback:)` | `LoginEntity` (username, password, requestId, …) | `Result<LoginResponseEntity>` |
| `logout(sub:callback:)` | `sub` | `Result<Bool>` |
| `logout(access_token:callback:)` | access token | `Result<Bool>` |
| `getRequestId(extraParams:callback:)` | — | `Result<RequestIdResponseEntity>` |
| `getClientInfo(requestId:callback:)` | `requestId` | `Result<ClientInfoResponseEntity>` |
| `getTenantInfo(callback:)` | — | `Result<TenantInfoResponseEntity>` |
| `getEndpoints(callback:)` | — | `Result<EndpointsResponseEntity>` |

**Native credentials login:**

```swift
let login = LoginEntity()
login.username = "user@example.com"
login.password = "password"
login.username_type = "email"   // required
login.requestId = "your-request-id"

CidaasNative.shared.loginWithCredentials(incomingData: login) { result in
    switch result {
    case .success(result: let response):
        print(response.data.access_token)
    case .failure(error: let error):
        print(error.errorMessage)
    }
}
```

### Registration and profile

| Method | Required params | Returns |
|--------|-----------------|---------|
| `getRegistrationFields(acceptlanguage:requestId:callback:)` | locale, requestId | `Result<RegistrationFieldsResponseEntity>` |
| `registerUser(requestId:incomingData:callback:)` | requestId, `RegistrationEntity` | `Result<RegistrationResponseEntity>` |
| `updateUser(access_token:incomingData:callback:)` | token, `RegistrationEntity` | `Result<UpdateUserResponseEntity>` |
| `changePassword(access_token:incomingData:callback:)` | token, `ChangePasswordEntity` | `Result<ChangePasswordResponseEntity>` |

### Account linking

| Method | Required params | Returns |
|--------|-----------------|---------|
| `linkAccount(access_token:incomingData:callback:)` | token, `LinkAccountEntity` | `Result<LinkAccountResponseEntity>` |
| `getLinkedUsers(access_token:sub:callback:)` | token, sub | `Result<LinkedUserListResponseEntity>` |
| `unlinkAccount(access_token:identityId:callback:)` | token, identity id | `Result<LinkAccountResponseEntity>` |

### Deduplication

| Method | Required params | Returns |
|--------|-----------------|---------|
| `getDeduplicationDetails(track_id:callback:)` | track id | `Result<DeduplicationDetailsResponseEntity>` |
| `registerDeduplication(track_id:callback:)` | track id | `Result<RegistrationResponseEntity>` |
| `deduplicationLogin(incomingData:callback:)` | `LoginEntity` | `Result<LoginResponseEntity>` |

### User activity

| Method | Required params | Returns |
|--------|-----------------|---------|
| `getUserActivity(accessToken:incomingData:callback:)` | token, `UserActivityEntity` | `Result<UserActivityResponseEntity>` |

---

## Consent

`CidaasConsent.shared` (`V2/Consent/Views/Consent.swift`) handles OAuth consent during authorization. No v3 wrapper exists.

| Method | Required | Returns | Purpose |
|--------|----------|---------|---------|
| `getConsentDetails(incomingData:callback:)` | `ConsentDetailsRequestEntity` | `Result<ConsentDetailsResponseEntity>` | Fetch consent screen data |
| `acceptConsent(incomingData:callback:)` | `AcceptConsentEntity` | `Result<AcceptConsentResponseEntity>` | User accepts consent |
| `consentContinue(incomingData:callback:)` | `ConsentContinueEntity` | `Result<LoginResponseEntity>` | Complete OAuth after consent → tokens |

**Typical flow:**

```swift
// 1. Load consent details (consent_id, sub, requestId, track_id from authz redirect)
CidaasConsent.shared.getConsentDetails(incomingData: detailsRequest) { result in
    guard case .success(result: let details) = result else { return }
    // Render consent UI from details.data

    // 2. User accepts
    CidaasConsent.shared.acceptConsent(incomingData: acceptEntity) { acceptResult in
        guard case .success = acceptResult else { return }

        // 3. Continue OAuth
        CidaasConsent.shared.consentContinue(incomingData: continueEntity) { continueResult in
            switch continueResult {
            case .success(result: let login):
                print(login.data.access_token)
            case .failure(error: let error):
                print(error.errorMessage)
            }
        }
    }
}
```

Populate `ConsentDetailsRequestEntity`, `AcceptConsentEntity` and `ConsentContinueEntity` from authz redirect parameters.

---

## Async/Await Helpers

`Cidaas+AsyncAwait.swift` adds `@available(iOS 13.0, *)` async wrappers on `Cidaas.shared` for token refresh and native bootstrap helpers. Browser auth, user info, password reset and account verification use v3 builder async methods instead.

| Method | Returns | Wraps |
|--------|---------|-------|
| `getClientInfo(requestId:)` | `ClientInfoResponseDataEntity` | `CidaasNative.shared.getClientInfo` |
| `getRequestID()` | `String` | `CidaasNative.shared.getRequestId` |
| `getAccessToken(with refreshToken:)` | `AccessTokenEntity` | Token refresh |
| `getSocialLoginProviders()` | `[String]` | requestId + clientInfo |
| `logout(accessToken:)` | — | `CidaasNative.shared.logout(access_token:)` |

**Example:**

```swift
@available(iOS 13.0, *)
func bootstrapNativeFlow() async throws {
    let requestId = try await Cidaas.shared.getRequestID()
    let providers = try await Cidaas.shared.getSocialLoginProviders()
    print(requestId, providers)
}
```

For browser login use `Cidaas.shared.webAuth(delegate:).signIn()` async. For user info use `Cidaas.users().fetchUserInfo(...)`.

---

## Shared Models and Storage

### `Result<T>`

All callback-based SDK APIs return:

```swift
public enum Result<T> {
    case success(result: T)
    case failure(error: WebAuthError)
}
```

### `WebAuthError`

Inspect `errorCode`, `statusCode`, `errorMessage` and nested `error: ErrorResponseEntity` for API payloads.

### Token models

| Type | Key fields | Usage |
|------|------------|-------|
| `LoginResponseEntity` | `success`, `status`, `data: AccessTokenEntity` | Login callbacks |
| `AccessTokenEntity` | `access_token`, `refresh_token`, `id_token`, `sub`, `expires_in` | Token payload |
| `AccessTokenModel` | Same fields + `AccessTokenModel.shared` | SDK session storage |

### Device model

`DeviceInfoModel` — persisted via `DBHelper`:

| Field | Purpose |
|-------|---------|
| `deviceId` | SDK device identifier |
| `deviceMake`, `deviceModel`, `deviceVersion` | Device metadata |
| `pushNotificationId` | FCM/APNs token used in MFA and device flows |

```swift
let info = DBHelper.shared.getDeviceInfo()
DBHelper.shared.setFCM(fcmToken: pushToken)
```

### `DBHelper` (integrator-relevant)

| Method | Purpose |
|--------|---------|
| `getPropertyFile()` / `setPropertyFile(_:)` | OAuth config dictionary |
| `getAccessToken(key:)` / `setAccessToken(accessTokenModel:)` | Per-user token by sub key |
| `getDeviceInfo()` / `setDeviceInfo(_:)` | Device metadata |
| `getFCM()` / `setFCM(_:)` | Push token storage |
| `getEnableLog()` / `setEnableLog(_:)` | Logging flag |
| `getEnablePkce()` / `setEnablePkce(_:)` | PKCE flag |

---

## Advanced Configuration

### TLS public-key pinning

Pin SHA-256 SPKI hashes (Base64). No `.cer` files in the app bundle.

```swift
Cidaas.shared.setPublicKeyPinning(
    trustedPublicKeyHashes: ["YOUR_PRIMARY_SPKI_SHA256_BASE64"],
    pinnedHosts: ["your-tenant.cidaas.de"],
    validateHost: true,
    performDefaultValidation: true
)
```

| Parameter | Required | Default | Notes |
|-----------|----------|---------|-------|
| `trustedPublicKeyHashes` | No | `CidaasPublicKeyPinningConfiguration.defaultTrustedHashes` | Replace placeholder hashes before production |
| `pinnedHosts` | No | host from `DomainURL` in plist | Hostname only, no scheme |
| `validateHost` | No | `true` | Recommended in production |
| `performDefaultValidation` | No | `true` | System trust + pin check |

```swift
Cidaas.shared.clearPublicKeyPinning()   // disable pinning
```

Call `setPublicKeyPinning` after OAuth properties load.

### DPoP and biometric HTTP proofs

Enable `useDpop` and `useBiometric` on `Cidaas.shared` (see [SDK Configuration](#sdk-configuration)), then:

```swift
let user = try await Cidaas.users().fetchUserInfo(sub: sub)
```

Turn flags off when later calls should not prompt for biometrics.

### Custom authorization URL

Build or handle authorization URLs with `Cidaas.WebAuth.authorizationURL(for:extraParameters:)` and `Cidaas.WebAuth.handleRedirect(_:)` — see [Browser Authentication](#browser-authentication).

### Debug logging

Set `Cidaas.shared.ENABLE_LOG = true` — see [SDK Configuration](#sdk-configuration).

---

## Error Handling

### Result-based APIs

Completion handlers return `Result<T>` with `WebAuthError` on failure. Pattern matches [Quick Start — Step 6](#step-6-implement-login-and-logout):

```swift
func handleSDKError(_ error: WebAuthError) {
    print("Code: \(error.errorCode)")
    print("Status: \(error.statusCode)")
    print("Message: \(error.errorMessage)")
}
```

### Async APIs

Async methods throw `WebAuthError`:

```swift
do {
    let login = try await Cidaas.shared.webAuth(delegate: self).signIn()
} catch let error as WebAuthError {
    handleSDKError(error)
} catch {
    print(error.localizedDescription)
}
```

### Common error sources

| Situation | Typical error |
|-----------|---------------|
| Missing `Cidaas.plist` | `fileNotFoundException()` — code 10001 |
| Missing plist key | `propertyMissingException()` |
| User cancelled browser | `userCancelledException()` |
| Network timeout | `netWorkTimeoutException()` |
| MFA validation | `serviceFailureException` — status 417 |
| App Attest unavailable | `serviceFailureException` — status 400 |


---

## Security Setup

### Info.plist

| Key | When required |
|-----|---------------|
| `CFBundleURLTypes` | Always. Must match the `RedirectURL` scheme. |
| `NSFaceIDUsageDescription` | Device registration and `useBiometric` proofs |

Example:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Used to register this device securely with your account.</string>
```

### Redirect URLs

Match `RedirectURL` and `PostLogoutRedirectURL` in `Cidaas.plist` to the portal. Prefer HTTPS universal links in production.

### Token storage

- Store tokens in the Keychain, not UserDefaults
- Don't log tokens in production when `ENABLE_LOG` is on

### Device registration requirements

Requires iOS 14+, physical device and `NSFaceIDUsageDescription`. See [Device Registration](#device-registration). Simulator usually can't complete App Attest.

### TLS pinning

- Replace placeholder hashes in `CidaasPublicKeyPinningConfiguration` before release
- Keep a backup hash for certificate rotation

---

## Troubleshooting

<details>
<summary><strong>Common mistakes</strong></summary>

**`Cidaas` module not found**
- Add the `Cidaas` package under **Package Dependencies** and link it to your app target
- Clean build (⌘+Shift+K) and rebuild

**`file not found` / property errors**
- Add `Cidaas.plist` to the app target with all required keys
- Include `PostLogoutRedirectURL` when loading from plist
- Call `readPropertyFile()` before v3 APIs

**Browser never returns to app**
- Match redirect URL across plist, portal and `Info.plist` URL scheme
- Check scheme spelling (for example `myapp` vs `myApp`)

**`webAuth` delegate errors**
- Pass a live view controller. Don't use a deallocated presenter.

**Social login fails**
- `provider` and `requestId` must both be non-empty

**MFA step fails with 417**
- Provide cached `sub`, `exchangeId` or type-specific fields (`otp`, `pushNumber`, `pattern`, …)
- Reuse the same `CidaasMFABuilder` across enrollment or authentication steps
- For `INITIAL_AUTHENTICATION` pass `identifier` only; for `MULTIFACTOR_AUTHENTICATION` pass masked `sub` only
- For pattern/push/touch/face auth call `pushAcknowledge` and `pushAllow` before `verification`

**Device registration fails immediately**
- Use a physical device with App Attest support (not Simulator)
- Set non-empty `clientId` and `pushId`
- Add `NSFaceIDUsageDescription`
- Load `DomainURL` via `readPropertyFile()` or `setURL(...)`

**Firebase provider registration fails**
- Set `CidaasDevice.firebaseAppCheckTokenProvider` before `registerDevice`

</details>

---

## Migrating to Cidaas V3

<details>
<summary><strong>Migration checklist</strong></summary>

1. Cidaas **server** at least **3.97.0**
2. **cidaas-ios-sdk** at least **1.3.2**
3. Add to `Cidaas.plist`:

```xml
<key>CidaasVersion</key>
<string>3</string>
```

4. Replace legacy browser and MFA calls with v3 builders — see [API Choice Guide](#api-choice-guide).

</details>

---

## Getting Client Id and URLs

Create an **App / Client** in the Cidaas portal and configure:

- **Scopes** — e.g. `openid`, `profile`, `email`, `offline_access`
- **Grant types** — authorization code with PKCE for mobile
- **Allowed redirect URLs** and **logout redirect URLs** — must match [SDK Configuration](#sdk-configuration)
- **Roles** — as required by your app

Copy the **Client ID** and **Domain URL** into `Cidaas.plist`.

---

## API Choice Guide

| Use case | API |
|----------|-----|
| Browser login | `Cidaas.shared.webAuth(delegate:).signIn` |
| Browser registration | `.webAuth(delegate:).registration().signIn` |
| Social login (browser) | `.webAuth(delegate:).social(...).signIn` |
| Login inside app WebView | `CidaasView.loginWithEmbeddedBrowser` |
| Native username/password | `CidaasNative.shared.loginWithCredentials` |
| MFA enrollment / authentication / configured list | `Cidaas.mfa(.totp).enrollment()…` / `.authentication()…` / `.configurations(sub:)` |
| Password reset | `Cidaas.users().passwordReset(...)` |
| Account verification | `Cidaas.users().accountVerification(.initiate \| .validate)` |
| User info | `Cidaas.users().fetchUserInfo(...)` |
| Device registration | `Cidaas.device().registerDevice(...)` |
| OAuth consent | `CidaasConsent.shared` |
| Token refresh | `Cidaas.shared.getAccessToken(refreshToken:)` or `getAccessToken(with:)` async |
| Dynamic registration form | `CidaasNative.getRegistrationFields` + `registerUser` |
| Link / unlink identities | `CidaasNative.linkAccount` / `unlinkAccount` |
