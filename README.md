![Logo](https://raw.githubusercontent.com/Cidaas/cidaas-sdk-ios-v2/master/logo.jpg)

# Cidaas iOS SDK

Native iOS SDK for [cidaas](https://www.cidaas.com). It adds OAuth 2.0 / OpenID Connect login, registration, verification and device registration to an iOS app.

The detailed guide is in the [iOS SDK documentation](https://dev-docs.cidaas.com/premium/mobile-sdks/ios/overview).

## What it covers

- Browser and social login and logout
- Native registration, account verification and password management
- Verification method enrolment and authentication
- Device registration, linked devices and push token update
- Access token read, refresh and user information

## Requirements

- iOS 11.0 or later (async helpers need iOS 13+; App Attest device registration needs iOS 14+ and a physical device)
- Swift 5
- Xcode with Swift Package Manager

## Installation

In Xcode, choose **File > Add Packages...** and enter:

```text
https://github.com/Cidaas/cidaas-sdk-ios-v2
```

Select the `Cidaas` library product.

## Configure

One tenant and one client: add `Cidaas.plist` to the app target, then load it at launch.

```xml
<dict>
    <key>DomainURL</key>
    <string>https://your-tenant.cidaas.de</string>
    <key>ClientId</key>
    <string>your-client-id</string>
    <key>RedirectURL</key>
    <string>yourapp://callback</string>
    <key>PostLogoutRedirectURL</key>
    <string>yourapp://callback</string>
</dict>
```

```swift
import Cidaas

Cidaas.shared.readPropertyFile()
```

`DomainURL`, `ClientId`, `RedirectURL` and `PostLogoutRedirectURL` are required for the plist path. Register the redirect URL as a custom scheme or universal link so the browser can return to the app.

Set these before the first login. `ENABLE_PKCE` defaults to `true`. Choose token storage before the first token write.

```swift
Cidaas.shared.ENABLE_LOG = false
Cidaas.shared.ENABLE_DPOP = false
Cidaas.shared.TOKEN_STORAGE = .userDefaults // or .keychain
```

## Multiple clients and tenants

`Cidaas.plist` is for one tenant and one client. Call `setURL` when the app uses more than one. The SDK uses one at a time and the previous login stays saved. Device registration is once per tenant.

```swift
Cidaas.shared.setURL(
    domainURL: "https://tenant-a.cidaas.de",
    clientId: "client-b",
    redirectURL: "appb://callback"
)
```

Set `ENABLE_DPOP` again after the switch when that client uses DPoP.

## Login

```swift
Cidaas.shared
    .webAuth(delegate: viewController)
    .extraParameters(["scopes": "openid profile email offline_access"])
    .signIn { result in
        switch result {
        case .success(result: let login):
            let token = login.data.access_token
        case .failure(error: let error):
            print(error.errorMessage)
        }
    }
```

## Support

Questions: [support.cidaas.com](https://support.cidaas.com) or [support@cidaas.de](mailto:support@cidaas.de).

## License

MIT. See [LICENSE](LICENSE).
