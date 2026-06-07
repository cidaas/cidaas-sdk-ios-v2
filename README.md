# Cidaas iOS SDK — Integration Guide

Integrate the Cidaas iOS SDK into your app. Use **V3 builders** in `Cidaas/Classes/V3/` for browser auth, MFA, user accounts and device registration. **Core** covers configuration and token storage. **V2** modules remain for embedded WebView login, native credentials and consent where no V3 wrapper exists.

[cidaas](https://www.cidaas.com) provides SSO (OAuth 2.0 / OpenID Connect), MFA, passwordless login, social login, native login, consent flows, user account management and device registration.

### Documentation map

| Goal | Start here |
|------|------------|
| First-time integration | [Quick Start](#quick-start) |
| Choose the right API | [API Choice Guide](#api-choice-guide) |
| V3 code examples (MFA, users, device) | [V3 API Guide](docs/V3-api-guide.md) |
| WebView, Native login, Core tokens | [Core & Legacy Reference](docs/V2-core-reference.md) |
| Fix a problem | [Troubleshooting](#troubleshooting) |
| Upgrade from legacy SDK | [Migrating to Cidaas V3](#migrating-to-cidaas-v3) |

---

## Table of Contents

### Getting started

- [Quick Start](#quick-start)
- [Platform Requirements](#platform-requirements)
- [Installation](#installation)
- [Getting Client Id and URLs](#getting-client-id-and-urls)
- [SDK Configuration](#sdk-configuration)

### Integration overview

- [API Choice Guide](#api-choice-guide)
- [SDK Module Map](#sdk-module-map)
- [Builder Pattern](#builder-pattern)

### API reference

- [V3 API Guide](#v3-api-guide) · [full guide](docs/V3-api-guide.md)
- [Core & Legacy APIs](#core-legacy-apis) · [full reference](docs/V2-core-reference.md)

### Operations

- [Error Handling](#error-handling)
- [Security Setup](#security-setup)
- [Troubleshooting](#troubleshooting)
- [Migrating to Cidaas V3](#migrating-to-cidaas-v3)

---

## Quick Start

Get **browser login** working with V3 `webAuth`. Follow the steps below in order. Detailed plist keys, portal settings and API reference live in linked sections — not repeated here.

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

Call at launch before any V3 API:

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

Registration, social login and async `signIn()` — [Browser Authentication](docs/V3-api-guide.md#browser-authentication). Error handling — [Error Handling](#error-handling).

### Step 7 — Run your app

Build and run in Xcode (⌘+R). Tap your login action, complete sign-in in the system browser and confirm tokens arrive in the completion handler.

> You have working V3 browser login. Next: [API Choice Guide](#api-choice-guide) · [V3 API Guide](docs/V3-api-guide.md) (MFA, user accounts, device registration)

---

## Platform Requirements

| Capability | Minimum iOS | Notes |
|------------|-------------|-------|
| SDK package | iOS 11+ | Deployment target in `Package.swift` |
| `async/await` V3 helpers | iOS 13+ | Browser auth, user accounts |
| Device registration | iOS 14+ | Physical device; App Attest or Firebase App Check |
| DPoP / biometric HTTP proofs | iOS 14+ | `Cidaas.shared.useDpop`, `useBiometric` |
| MFA builders | iOS 11+ | Completion-handler APIs only (no async MFA wrappers) |
| `Cidaas+AsyncAwait` extension | iOS 13+ | Convenience wrappers on `Cidaas.shared` |

---

## Installation

The SDK ships through **Swift Package Manager** only:

```text
https://github.com/Cidaas/cidaas-sdk-ios-v2
```

Select the **`Cidaas`** library product when adding the package.

---

## Getting Client Id and URLs

Create an **App / Client** in the Cidaas portal and configure:

- **Scopes** — e.g. `openid`, `profile`, `email`, `offline_access`
- **Grant types** — authorization code with PKCE for mobile
- **Allowed redirect URLs** and **logout redirect URLs** — must match [SDK Configuration](#sdk-configuration)
- **Roles** — as required by your app

Copy the **Client ID** and **Domain URL** into `Cidaas.plist`.

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
| `CidaasVersion` | Recommended | Set to `3` for V3 response handling |

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

## API Choice Guide

Use **V3 builders** for browser auth, MFA, user accounts and device registration. Use **Core / V2** modules only when no V3 wrapper exists — details in [V3 API Guide](docs/V3-api-guide.md) and [Core & Legacy Reference](docs/V2-core-reference.md).

### V3 builders

| Use case | API | Guide |
|----------|-----|-------|
| Browser login | `Cidaas.shared.webAuth(delegate:).signIn` | [Browser Auth](docs/V3-api-guide.md#browser-authentication) |
| Browser registration | `.webAuth(delegate:).registration().signIn` | [Browser Auth](docs/V3-api-guide.md#browser-authentication) |
| Social login (browser) | `.webAuth(delegate:).social(...).signIn` | [Browser Auth](docs/V3-api-guide.md#browser-authentication) |
| MFA enrollment / authentication | `Cidaas.mfa(.totp).enrollment()…` / `.authentication()…` | [MFA](docs/V3-api-guide.md#mfa) |
| MFA configured list / device support | `Cidaas.mfaSupport().configurations(sub:)` / `.pendingNotifications(…)` | [MFA support](docs/V3-api-guide.md#mfa-support-cidaasmfasupportbuilder) |
| Cancel MFA authentication | `Cidaas.mfa(.push).authentication().cancelAuthentication(exchangeId:reason:)` | [MFA](docs/V3-api-guide.md#mfa) |
| MFA device support (history, pending push, unlink) | `Cidaas.mfaSupport().pendingNotifications(…)` / `.history(…)` / `.delete(…)` | [MFA support](docs/V3-api-guide.md#mfa-support-cidaasmfasupportbuilder) |
| Password reset | `Cidaas.users().passwordReset(...)` | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| Change password (authenticated) | `Cidaas.users().changePassword(accessToken:, .change(...))` | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| Set password (authenticated) | `Cidaas.users().setPassword(accessToken:, .set(...))` | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| Account verification | `Cidaas.users().accountVerification(.initiate \| .validate)` | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| User info | `Cidaas.users().fetchUserInfo(...)` | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| Device registration | `Cidaas.device().registerDevice(...)` | [Device Registration](docs/V3-api-guide.md#device-registration) |

### Core and legacy modules

| Use case | API | Guide |
|----------|-----|-------|
| Login inside app WebView | `CidaasView.loginWithEmbeddedBrowser` | [Embedded WebView](docs/V2-core-reference.md#embedded-webview-login) |
| Native username/password | `CidaasNative.shared.loginWithCredentials` | [Native APIs](docs/V2-core-reference.md#native-apis) |
| OAuth consent | `CidaasConsent.shared` | [Consent](docs/V2-core-reference.md#consent) |
| Token refresh | `Cidaas.shared.getAccessToken(refreshToken:)` or `getAccessToken(with:)` async | [Core APIs](docs/V2-core-reference.md#core-apis) |
| Dynamic registration form | `CidaasNative.getRegistrationFields` + `registerUser` | [Native APIs](docs/V2-core-reference.md#native-apis) |
| Link / unlink identities | `CidaasNative.linkAccount` / `unlinkAccount` | [Native APIs](docs/V2-core-reference.md#native-apis) |

---

## SDK Module Map

The SDK ships as one **`Cidaas`** Swift Package with three layers. Use **V3** for browser auth, MFA, user accounts and device registration.

| Layer | Path | Entry point | Use when |
|-------|------|-------------|----------|
| **V3** | `Classes/V3/` | `Cidaas.shared.webAuth`, `.users()`, `.mfa()`, `.mfaSupport()`, `.device()` | **Default** — browser auth, MFA, password reset, change/set password, account verification, user info, device registration |
| **Core** | `Classes/Core/` | `Cidaas.shared`, `CidaasView` | Config, token refresh, WebView login |
| **Native (V2)** | `Classes/V2/Native/` | `CidaasNative.shared` | Native login UI, registration fields, deduplication |
| **Consent (V2)** | `Classes/V2/Consent/` | `CidaasConsent.shared` | OAuth consent screens (no V3 wrapper) |

### V3 entry points

| Entry point | Returns | Purpose |
|-------------|---------|---------|
| `Cidaas.shared.webAuth(delegate:)` | `CidaasWebAuthBuilder` | Browser login, registration, social login and logout |
| `Cidaas.WebAuth` | Static helpers | Custom browser integrations |
| `Cidaas.users()` | `CidaasUsersBuilder` | User info, password reset, change/set password and account verification |
| `Cidaas.mfa(_:)` | `CidaasMFABuilder` | MFA enrollment and authentication |
| `Cidaas.mfaSupport()` | `CidaasMFASupportBuilder` | MFA device management (configured list, history, pending push, unlink) — no verification type |
| `Cidaas.device()` | `CidaasDevice` | Device registration with attestation proofs |

### Core and V2 entry points (no V3 wrapper)

| Entry point | Purpose |
|-------------|---------|
| `Cidaas.shared` | Config, token refresh and session storage |
| `CidaasView` | Embedded `WKWebView` OAuth login |
| `CidaasNative.shared` | Native credentials login, registration, link/unlink |
| `CidaasConsent.shared` | Consent details, accept, continue |

V3 completion APIs return the SDK `Result<T>` type — see [Shared Models and Storage](docs/V2-core-reference.md#shared-models-and-storage).

---

## Builder Pattern

V3 uses fluent builders. **Complete examples:** [V3 API Guide](docs/V3-api-guide.md).

Chain configuration methods, then call a **terminal method** to run the flow.

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
    → enrollment() | authentication() | support()
    → branch methods (initiation, verification, …)

Cidaas.mfaSupport()
    → configurations(sub:), pendingNotifications, history, delete, updateFCMToken, …
```

MFA enrollment passes values explicitly between steps; authentication may cache state on the same builder — see [MFA](docs/V3-api-guide.md#mfa).

**User accounts**

```
Cidaas.users()
    → passwordReset(.initiate | .validate | .accept)
    → changePassword(accessToken:, .change)
    → setPassword(accessToken:, .set)
    → accountVerification(.initiate | .validate)
    → fetchUserInfo(sub:) | fetchUserInfo(accessToken:)
```

**Device registration**

```
Cidaas.device().registerDevice(clientId:pushId:)
```

Single public method. Internally runs initiate → attestation → verify with DPoP and biometric proofs.

---

## V3 API Guide

Full reference with prerequisites, method tables and **ready-to-use code examples** for every V3 builder.

**[Open the V3 API Guide →](docs/V3-api-guide.md)**

| Module | What it covers | Guide |
|--------|----------------|-------|
| Browser Authentication | Login, registration, social, logout | [Browser Auth](docs/V3-api-guide.md#browser-authentication) |
| User Accounts | Password reset, change/set password, account verification, userinfo | [User Accounts](docs/V3-api-guide.md#user-accounts) |
| MFA | Enrollment, authentication, support, cancel flows | [MFA](docs/V3-api-guide.md#mfa) |
| Device Registration | App Attest, Firebase App Check, push binding | [Device Registration](docs/V3-api-guide.md#device-registration) |

Shared setup helpers (`ensureCidaasConfigured`, `fetchOAuthRequestId`) and enrollment/authentication **patterns** (OTP, scan-required, push handoff) are documented once in the guide.

---

## Core & Legacy APIs

V3 builders cover most flows. Use these modules when you need embedded WebView login, native credentials UI, token refresh or OAuth consent.

**[Open the Core & Legacy reference →](docs/V2-core-reference.md)**

| Module | Path | Use when |
|--------|------|----------|
| Core | `Classes/Core/` | Token refresh, session storage |
| Embedded WebView | `CidaasView` | OAuth inside your app WebView |
| Native | `CidaasNative.shared` | Custom login/registration UI, `getRequestId` |
| Consent | `CidaasConsent.shared` | OAuth consent screens |

Also includes [Async/Await helpers](docs/V2-core-reference.md#asyncawait-helpers), [Shared Models & Storage](docs/V2-core-reference.md#shared-models-and-storage) and [Advanced Configuration](docs/V2-core-reference.md#advanced-configuration) (DPoP, custom auth URLs).

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

Requires iOS 14+, physical device and `NSFaceIDUsageDescription`. See [Device Registration](docs/V3-api-guide.md#device-registration). Simulator usually can't complete App Attest.

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
- Call `readPropertyFile()` before V3 APIs

**Browser never returns to app**
- Match redirect URL across plist, portal and `Info.plist` URL scheme
- Check scheme spelling (for example `myapp` vs `myApp`)

**`webAuth` delegate errors**
- Pass a live view controller. Don't use a deallocated presenter.

**Social login fails**
- `provider` and `requestId` must both be non-empty

**MFA step fails with 417**
- Pass required fields explicitly: enrollment needs `sub`, `exchangeId`, and type-specific pass code (`otp`, `pushNumber`, `pattern`, …)
- Use `CidaasMFAEnrollmentSetupResult.enrollmentExchangeId` for verify after `enrollmentSetup`
- For authentication, reuse the same `CidaasMFABuilder` across steps or pass cached values explicitly
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

4. Replace legacy browser and MFA calls with V3 builders — see [API Choice Guide](#api-choice-guide).

</details>

---

