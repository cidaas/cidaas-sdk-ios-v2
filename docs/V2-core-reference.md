# Core & Legacy API Reference

Part of the [Cidaas iOS SDK Integration Guide](../README.md). These modules live under `Classes/Core/` and `Classes/V2/`. Prefer [V3 builders](V3-api-guide.md#v3-api-guide) where a wrapper exists.

## Table of Contents

- [Core APIs](#core-apis)
- [Embedded WebView Login](#embedded-webview-login)
- [Native APIs](#native-apis)
- [Consent](#consent)
- [Async/Await Helpers](#asyncawait-helpers)
- [Shared Models and Storage](#shared-models-and-storage)
- [Advanced Configuration](#advanced-configuration)

---

## Core APIs

`Cidaas.shared` (`Core/Views/Cidaas.swift`) is the root singleton for configuration and token management. Browser auth, MFA, password reset, change/set password, account verification and user info use V3 builders — see [V3 API Guide](V3-api-guide.md#v3-api-guide).

Configuration: see [SDK Configuration](../README.md#sdk-configuration).

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

Use `CidaasView` when OAuth runs inside your app instead of the system browser. There is no V3 wrapper.

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

`CidaasNative.shared` (`V2/Native/Views/Native.swift`) exposes REST APIs for native UI where your app renders login and registration screens. Password reset, change/set password, account verification and user info use V3 `Cidaas.users()`.

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

`CidaasConsent.shared` (`V2/Consent/Views/Consent.swift`) handles OAuth consent during authorization. No V3 wrapper exists.

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

`Cidaas+AsyncAwait.swift` adds `@available(iOS 13.0, *)` async wrappers on `Cidaas.shared` for token refresh and native bootstrap helpers. Browser auth, user info, password reset, change/set password and account verification use V3 builder async methods instead.

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
| `getPropertyFile()` / `setPropertyFile(properties:key:)` | OAuth config dictionary |
| `getAccessToken(key:)` / `setAccessToken(accessTokenModel:)` | Per-user token by sub key |
| `getDeviceInfo()` / `setDeviceInfo(_:)` | Device metadata |
| `getFCM(key:)` / `setFCM(fcmToken:key:)` | Push token storage |
| `getEnableLog()` / `setEnableLog(_:)` | Logging flag |
| `getEnablePkce()` / `setEnablePkce(_:)` | PKCE flag |

---

## Advanced Configuration

### DPoP and biometric HTTP proofs

Enable `useDpop` and `useBiometric` on `Cidaas.shared` (see [SDK Configuration](../README.md#sdk-configuration)), then:

```swift
let user = try await Cidaas.users().fetchUserInfo(sub: sub)
```

Turn flags off when later calls should not prompt for biometrics.

### Custom authorization URL

Build or handle authorization URLs with `Cidaas.WebAuth.authorizationURL(for:extraParameters:)` and `Cidaas.WebAuth.handleRedirect(_:)` — see [Browser Authentication](V3-api-guide.md#browser-authentication).

### Debug logging

Set `Cidaas.shared.ENABLE_LOG = true` — see [SDK Configuration](../README.md#sdk-configuration).

---

