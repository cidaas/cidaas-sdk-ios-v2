# Cidaas iOS SDK — Integration Guide

This guide covers the **v3 API surface** (`Cidaas/Classes/v3/`) and walks you through integrating the SDK into an iOS app from Xcode, step by step.

[cidaas](https://www.cidaas.com) is a Cloud Identity & Access Management platform with SSO (OAuth 2.0 / OpenID Connect), MFA, passwordless login, social login and device registration.

## Table of Contents

- [Get Started](#get-started)
- [Platform Requirements](#platform-requirements)
- [Next Steps](#next-steps)
- [Troubleshooting and Advanced](#troubleshooting-and-advanced)
- [Module Overview](#module-overview)
- [Builder Pattern in v3](#builder-pattern-in-v3)
- [Module API Guide](#module-api-guide)
- [Configuration Flow](#configuration-flow)
- [Error Handling](#error-handling)
- [Security Setup Notes](#security-setup-notes)
- [Migrating to Cidaas V3](#migrating-to-cidaas-v3)
- [Getting Client Id and URLs](#getting-client-id-and-urls)

---

<a id="get-started"></a>

## Get Started

### Step 1 — Create a new project

**In Xcode:**

1. **File → New → Project** (or **⌘+Shift+N**)
2. Select **iOS → App**
3. Configure your project:
   - **Product Name**: e.g. `Cidaas-Sample`
   - **Interface**: SwiftUI or Storyboard (either works)
   - **Language**: Swift
4. Choose a location and click **Create**

> Use a unique **Bundle Identifier** (e.g. `com.example.cidaas-sample`). You will register this in your Cidaas tenant and in your redirect URL configuration.

---

### Step 2 — Add the Cidaas SDK

Add the SDK with Swift Package Manager.

**In Xcode:**

1. **File → Add Package Dependencies** (or **⌘+Shift+K**)
2. Enter the package URL:

   ```text
   https://github.com/Cidaas/cidaas-sdk-ios-v2
   ```

3. Select your dependency rule → **Add Package**
4. Select your app target → **Add Package**

Import the SDK in your Swift files:

```swift
import Cidaas
```

---

### Step 3 — Configure your Cidaas tenant

Register a native/mobile app in your Cidaas admin portal and note the values you need for the SDK.

1. Open your **Cidaas admin portal** and create or select an **App / Client** for your mobile app.
2. Note your **Client ID** and **Domain URL** (e.g. `https://your-tenant.cidaas.de`).
3. Add **Allowed Redirect URLs** that match your app. For a custom URL scheme:

   ```text
   YOUR_URL_SCHEME://callback
   ```

   Example: if your redirect is `myapp://callback`, register exactly that URL in the portal.

4. Add **Allowed Logout Redirect URLs** (often the same value as your login redirect):

   ```text
   YOUR_URL_SCHEME://callback
   ```

5. Save your app/client configuration.

> See [Getting Client Id and URLs](#getting-client-id-and-urls) for scope, grant types and other portal settings.

---

### Step 4 — Configure app credentials

Create `Cidaas.plist` in your project directory:

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
| `RedirectURL` | Yes | Custom URL scheme callback after login |
| `PostLogoutRedirectURL` | Yes | Callback after browser logout |
| `CidaasVersion` | Recommended | Set to `3` for v3 API behaviour |

Drag `Cidaas.plist` into Xcode and ensure **Add to target** is checked for your app target.

<details>
<summary><strong>Programmatic configuration (alternative)</strong></summary>

Instead of relying on the plist alone, you can set credentials in code (useful for environment-specific builds):

```swift
Cidaas.shared.setURL(
    domainURL: "https://your-cidaas-domain",
    clientId: "your-client-id",
    redirectURL: "myapp://callback"
)
```

You still need matching redirect URLs registered in your Cidaas tenant.

</details>

---

### Step 5 — Register the URL scheme

The redirect URL in `Cidaas.plist` must match a URL scheme registered in your app.

Add `CFBundleURLTypes` to your app’s `Info.plist`. If your redirect is `myapp://callback`, register the `myapp` scheme:

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

Use [custom URL schemes](https://developer.apple.com/documentation/uikit/core_app/communicating_with_other_apps_using_custom_urls) or [Universal Links](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html) to return control from the browser to your app.

> **Note:** Register the same custom scheme URL in your Cidaas app’s redirect URL settings.

---

### Step 6 — Initialize the SDK

Load `Cidaas.plist` into the SDK before calling any v3 APIs. Call this early in your app lifecycle (e.g. in `AppDelegate`, `@main` app init or before the first login):

```swift
Cidaas.shared.readPropertyFile()
```

The SDK reads the plist asynchronously and stores OAuth properties internally. Ensure `DBHelper.shared.getPropertyFile()` is populated before starting browser auth (retry briefly after `readPropertyFile()` if needed).

You can also use the shared instance directly:

```swift
let cidaas = Cidaas.shared
```

---

### Step 7 — Create the authentication service

Create `AuthenticationService.swift` in your project and wire login/logout using the v3 browser auth builder.

```swift
import Foundation
import UIKit
import Cidaas

@MainActor
final class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var userSub: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private weak var presenter: UIViewController?

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func login() {
        guard let presenter else {
            errorMessage = "No view controller available to present browser login."
            return
        }

        isLoading = true
        errorMessage = nil

        Cidaas.shared
            .webAuth(delegate: presenter)
            .extraParameters(["scopes": "openid profile email offline_access"])
            .signIn { [weak self] result in
                Task { @MainActor in
                    self?.isLoading = false
                    switch result {
                    case .success(result: let login):
                        self?.isAuthenticated = true
                        self?.accessToken = login.data.access_token
                        self?.userSub = login.data.sub
                    case .failure(error: let error):
                        self?.errorMessage = "Login failed: \(error.localizedDescription)"
                    }
                }
            }
    }

    func logout() {
        guard let presenter, let sub = userSub, !sub.isEmpty else {
            errorMessage = "User sub is required for logout."
            return
        }

        isLoading = true
        errorMessage = nil

        Cidaas.shared
            .webAuth(delegate: presenter)
            .signOut(sub: sub) { [weak self] result in
                Task { @MainActor in
                    self?.isLoading = false
                    switch result {
                    case .success:
                        self?.isAuthenticated = false
                        self?.accessToken = nil
                        self?.userSub = nil
                    case .failure(error: let error):
                        self?.errorMessage = "Logout failed: \(error.localizedDescription)"
                    }
                }
            }
    }
}
```

**Async/await variant (iOS 13+):**

```swift
@available(iOS 13.0, *)
func performLogin(from presenter: UIViewController) async {
    isLoading = true
    defer { isLoading = false }

    do {
        let login = try await Cidaas.shared
            .webAuth(delegate: presenter)
            .extraParameters(["scopes": "openid profile email offline_access"])
            .signIn()
        isAuthenticated = true
        accessToken = login.data.access_token
        userSub = login.data.sub
    } catch {
        errorMessage = "Login failed: \(error.localizedDescription)"
    }
}
```

**Registration and social login** use the same builder. Add `.registration()` or `.social(...)` only when you need those flows — not for a standard login:

```swift
// Registration (sign-up flow)
Cidaas.shared.webAuth(delegate: presenter).registration().signIn { ... }

// Social login
Cidaas.shared
    .webAuth(delegate: presenter)
    .social(provider: "google", requestId: "your-request-id")
    .signIn { ... }
```

---

### Step 8 — Run your app

Press **⌘+R** in Xcode.

1. Ensure `Cidaas.plist` is in the app target and `readPropertyFile()` has been called.
2. Tap **Log In** → accept the system browser permission alert (if shown).
3. Complete login in the browser.
4. Your app receives tokens via the builder completion handler.

---

<a id="platform-requirements"></a>

## Platform Requirements

| Capability | Minimum iOS |
|------------|-------------|
| SDK package | iOS 11+ |
| `async/await` convenience APIs | iOS 13+ |
| Device registration (`Cidaas.device()`) | iOS 14+ (physical device, App Attest) |

---

<a id="next-steps"></a>

## Next Steps

You now have browser login and logout working with the Cidaas iOS SDK v3 API.

Continue with the sections below for MFA, user accounts, device registration, error handling and advanced topics.

---

<a id="troubleshooting-and-advanced"></a>

## Troubleshooting and Advanced

<details>
<summary><strong>Common issues & solutions</strong></summary>

### Build errors: `Cidaas` module not found

1. Verify the package appears under **Package Dependencies**
2. Clean build folder (**⌘+Shift+K**) and rebuild (**⌘+R**)
3. Restart Xcode if the module is still not found

### `file not found` / property errors

- `Cidaas.plist` is missing from the app target or required keys are absent
- Call `Cidaas.shared.readPropertyFile()` before v3 API calls
- Ensure `PostLogoutRedirectURL` is present when using plist-based configuration

### Browser opens but never returns to the app

1. Redirect URL in `Cidaas.plist` must match your Cidaas portal registration exactly
2. URL scheme in `Info.plist` must match the scheme part of `RedirectURL` (e.g. `myapp` for `myapp://callback`)
3. Bundle identifier and redirect URLs must be consistent across Xcode and the portal

### WebAuth delegate errors

- Pass a live `UIViewController` to `webAuth(delegate:)` and keep it alive until sign-in/sign-out completes

### Social login fails

- `social(provider:requestId:)` requires non-empty `provider` and `requestId`

</details>

<details>
<summary><strong>Production deployment</strong></summary>

### App Store preparation

- Configure Universal Links for smoother redirect UX
- Test on multiple iOS versions and device sizes
- Add `NSFaceIDUsageDescription` if using device registration or biometric proofs
- Handle network failures gracefully in your UI

### Security best practices

- Do not log access tokens or refresh tokens in production
- Keep redirect URLs scoped to your app’s URL scheme or verified universal links
- Use certificate/public-key pinning only when your security policy requires it (`Cidaas.shared.setPublicKeyPinning(...)`)

</details>

---

<a id="module-overview"></a>

## Module Overview

<details>
<summary><strong>v3 public entry points</strong></summary>

- `Cidaas.shared.webAuth(delegate:)` → `CidaasWebAuthBuilder`
- `Cidaas.WebAuth` static helpers (`handleRedirect`, `authorizationURL`)
- `Cidaas.users()` → `CidaasUsersBuilder`
- `Cidaas.mfa(_:)` → `CidaasMFABuilder`
- `Cidaas.device()` → `CidaasDevice`

</details>

---

<a id="builder-pattern-in-v3"></a>

## Builder Pattern in v3

<details>
<summary><strong>BrowserAuth builder flow</strong></summary>

1. Create builder with presenter: `Cidaas.shared.webAuth(delegate:)`
2. Optional builder steps (call only when needed):
   - `extraParameters(_:)` — add OAuth query parameters
   - `registration()` — switch from login to registration
   - `social(provider:requestId:)` — switch to social login
3. Execute terminal method:
   - `signIn(...)` — start sign-in (login, registration or social, depending on step 2)
   - `signOut(sub:...)` — start sign-out

</details>

<details>
<summary><strong>MFA builder flow</strong></summary>

1. Create root builder: `Cidaas.mfa(.totp)` (or `.push`, `.pattern`, etc.)
2. Choose branch:
   - `enrollment()`
   - `authentication()`
   - `support()`
3. Execute branch methods.

The MFA builders cache intermediate values (`sub`, `exchangeId`, etc.) to reduce parameter repetition across a flow.

</details>

<details>
<summary><strong>Users builder flow</strong></summary>

`Cidaas.users()` is a facade-style builder:

- password reset actions
- account verification actions
- user info fetch methods

</details>

<details>
<summary><strong>Device API flow</strong></summary>

`Cidaas.device().registerDevice(...)` is a single high-level flow that internally performs:

- initiation request
- App Attest proof creation
- verification request

</details>

---

<a id="module-api-guide"></a>

## Module API Guide

<details>
<summary><strong>Browser Authentication (<code>CidaasWebAuthBuilder</code>)</strong></summary>

### Entry point

```swift
let webAuth = Cidaas.shared.webAuth(delegate: self)
```

- **Required:** `delegate` (`UIViewController`) used to present system browser auth UI.
- **Failure:** if the delegate is deallocated before execution, completion returns failure.

### Configuration methods

These are **optional builder steps** — you can chain them between `webAuth(delegate:)` and `signIn(...)`. You do not need to call any of them for a standard login. If you skip them all, the SDK starts a **login** flow with no extra OAuth parameters.

`extraParameters(_ params: [String: String]) -> Self`
- Not required — omit to use an empty dictionary (default)
- Adds OAuth query parameters to the authorization URL (e.g. `scopes`, `prompt`, `ui_locales`)

`registration() -> Self`
- Not required — omit to use **login** mode (default)
- Call this to open the hosted **registration** page instead of login

`social(provider: String, requestId: String) -> Self`
- Not required — omit unless you are doing social login
- When called, both `provider` and `requestId` must be non-empty

### Terminal methods

`signIn(completion:)` — returns `Result<LoginResponseEntity>`

`signIn() async throws -> LoginResponseEntity` (iOS 13+)

`signOut(sub:completion:)` — **required:** non-empty `sub`; returns `Result<Bool>`

`signOut(sub:) async throws -> Bool` (iOS 13+)

### Static helpers (`Cidaas.WebAuth`)

`handleRedirect(_ url: URL)` — forward OAuth callback URLs when using a custom browser integration (not needed for standard `ASWebAuthenticationSession` login).

`authorizationURL(for:extraParameters:completion:)`  
`authorizationURL(for:extraParameters:) async throws -> URL` (iOS 13+)

- Useful when you need URL preview or custom browser handling.
- For `.social`, `extraParameters["provider"]` and `extraParameters["requestId"]` are required.

### Completion-handler example (login)

```swift
Cidaas.shared
    .webAuth(delegate: self)
    .extraParameters(["prompt": "login", "ui_locales": "en"])
    .signIn { result in
        switch result {
        case .success(result: let login):
            print("Access token: \(login.data.access_token)")
        case .failure(error: let error):
            print("Login failed: \(error.localizedDescription)")
        }
    }
```

### Async/await example (login)

```swift
@available(iOS 13.0, *)
func performLogin() async {
    do {
        let login = try await Cidaas.shared
            .webAuth(delegate: self)
            .extraParameters(["scopes": "openid profile email offline_access"])
            .signIn()
        print("Login success: \(login.data.access_token)")
    } catch {
        print("Login failed: \(error.localizedDescription)")
    }
}
```

### Async/await example (registration)

Add `.registration()` only when you want the hosted sign-up flow — not for a normal login:

```swift
@available(iOS 13.0, *)
func performRegistration() async {
    do {
        let login = try await Cidaas.shared
            .webAuth(delegate: self)
            .registration()
            .signIn()
        print("Registration success: \(login.data.access_token)")
    } catch {
        print("Registration failed: \(error.localizedDescription)")
    }
}
```

</details>

<details>
<summary><strong>User Accounts (<code>CidaasUsersBuilder</code>)</strong></summary>

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

`fetchUserInfo(sub:completion:)` / `fetchUserInfo(sub:) async throws` (iOS 13+)

`fetchUserInfo(accessToken:completion:)` / `fetchUserInfo(accessToken:) async throws` (iOS 13+)

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

</details>

<details>
<summary><strong>MFA (<code>CidaasMFABuilder</code>)</strong></summary>

### Entry point

```swift
let mfa = Cidaas.mfa(.totp)
```

Verification types:
- `.pattern`, `.push`, `.touchId`, `.totp`, `.face`, `.email`, `.sms`, `.ivr`, `.backupCode`

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

`verification(exchangeId: String? = nil, otp: String? = nil, pattern: String? = nil, pushNumber: String? = nil, photo: UIImage = UIImage(), attempt: Int = 0, localizedReason: String = "Authenticate", completion: ...)`
- `exchangeId` required (directly or via cache).
- `pushNumber` required for PUSH.
- `otp/pattern` required for most non-biometric types.

### Authentication builder methods

`initiation(sub:requestId:usageType:completion:)` — all parameters required and non-empty.

`verification(...)` — uses cached values where possible.

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

</details>

<details>
<summary><strong>Device Registration (<code>CidaasDevice</code>)</strong></summary>

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

</details>

---

<a id="configuration-flow"></a>

## Configuration Flow (Recommended Order)

1. Ensure `Cidaas.plist` exists in the app bundle (or call `setURL(...)`).
2. Call `Cidaas.shared.readPropertyFile()` and wait until OAuth properties are loaded.
3. For browser auth, always pass a live `UIViewController`.
4. For device registration:
   - run on iOS 14+ physical device
   - include `NSFaceIDUsageDescription`
   - ensure push token is available and non-empty

---

<a id="error-handling"></a>

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

<a id="security-setup-notes"></a>

## Security Setup Notes

### Browser and redirect

- Redirect URI in `Cidaas.plist` must match your tenant app registration.
- The SDK handles the OAuth redirect automatically for standard browser login via `ASWebAuthenticationSession`.

### Device registration

- Requires App Attest support (iOS 14+ and supported device/environment).
- Uses DPoP + biometric proof headers internally for verification step.
- Host app must provide `NSFaceIDUsageDescription`.

---

<a id="migrating-to-cidaas-v3"></a>

## Migrating to Cidaas V3

<details>
<summary><strong>Migration checklist</strong></summary>

Cidaas V3 adjusts response handling on some service calls. To migrate:

1. Ensure your Cidaas **server instance** is at least **3.97.0** (check the service portal; contact support if an upgrade is needed).
2. Use **cidaas-ios-sdk** version **1.3.2** or later.
3. Add `CidaasVersion` to `Cidaas.plist`:

```xml
<key>CidaasVersion</key>
<string>3</string>
```

Example full plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DomainURL</key>
    <string>Your Domain URL</string>
    <key>RedirectURL</key>
    <string>Your redirect url</string>
    <key>ClientId</key>
    <string>Your client id</string>
    <key>PostLogoutRedirectURL</key>
    <string>Your redirect url</string>
    <key>CidaasVersion</key>
    <string>3</string>
</dict>
</plist>
```

</details>

---

<a id="getting-client-id-and-urls"></a>

## Getting Client Id and URLs

When integrating your business app, you typically create an **App / Client** in the Cidaas portal and configure:

- **Scopes** (e.g. `openid`, `profile`, `email`, `offline_access`)
- **Roles** and **grant types**
- **Redirect URLs** and **logout redirect URLs**

The portal generates the **Client ID** and accepts the **redirect URLs** you register. Copy those values into `Cidaas.plist` and your Xcode URL scheme configuration.

---

This documentation intentionally covers only `Cidaas/Classes/v3/`. For legacy V2 flows (embedded WebView, native UI, verification) see the linked guides in the repository history or `README.old.md`.
