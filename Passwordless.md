# Passwordless or Multifactor Authentication

cidaas provides numerous options to ensure safe and diverse mechanisms for login. It is a good practice to enable multiple factors during login, to ensure that user identities and accesses are not compromised. To improve convenience, cidaas offers passwordless mechanisms as well. Depending on the end user's comfort, you can offer any of the multi-factor authentication methods available in cidaas.    

## Table of Contents
<!--ts-->
* [Face](#face-recognition)
    <!--ts-->
    * [Configuration](#configure-face-recognition)
    * [Usage](#login-via-face-recognition)
    <!--te-->
* [Voice](#voice-recognition)
    <!--ts-->
    * [Configuration](#configure-voice-recognition)
    * [Usage](#login-via-voice-recognition)
    <!--te-->
* [Touch ID](#touchid-verification)
    <!--ts-->
    * [Configuration](#configure-touchid-verification)
    * [Usage](#login-via-touchid-verification)
    <!--te-->
* [Pattern](#pattern-recognition)
    <!--ts-->
    * [Configuration](#configure-pattern-recognition)
    * [Usage](#login-via-pattern-recognition)
    <!--te-->
* [Smart Push](#smartpush-notification)
    <!--ts-->
    * [Configuration](#configure-smartpush-notification)
    * [Usage](#login-via-smartpush-notification)
    <!--te-->
* [TOTP](#totp)
    <!--ts-->
    * [Configuration](#configure-totp)
    * [Usage](#login-via-totp)
    <!--te-->
* [Email](#email)
    <!--ts-->
    * [Configuration](#configure-email)
    * [Usage](#login-via-email)
    <!--te-->
* [SMS](#sms)
    <!--ts-->
    * [Configuration](#configure-sms)
    * [Usage](#login-via-sms)
    <!--te-->
* [IVR](#ivr)
    <!--ts-->
    * [Configuration](#configure-ivr)
    * [Usage](#login-via-ivr)
    <!--te-->
* [Backupcode](#backupcode)
    <!--ts-->
    * [Configuration](#configure-backupcode)
    * [Usage](#login-via-backupcode)
    <!--te--> 

### Verification 

For MFA verification, you need to initiate the verification's instance 

```swift
var verification = CidaasVerification.shared
```

#### Face Recognition

Biometrics plays an important role in the modern world. cidaas can register a user's face, extract unique features from it, and use that to identify when they present their face for identification.  To use Face Recognition as a passwordless login, you need to configure it first.

#### Configure Face Recognition

To configure Face Recognition, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.FACE.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"
configureRequest.attempt = 1

verification.configure(configureRequest: configureRequest, photo: photo) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via Face Recognition

Once you configure Face Recognition, you can login with Face Recognition for Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.FACE.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest, photo: photo) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### Voice Recognition

Biometric plays an important role in the modern world. cidaas can record your user's voice, extract unique features and use that to verify. To use Voice Recognition for passwordless login, you need to configure it first.

#### Configure Voice Recognition

To configure Voice Recognition, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.VOICE.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"
configureRequest.attempt = 1

verification.configure(configureRequest: configureRequest, voice: voice) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**


```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via Voice Recognition

Once you configure Voice Recognition, you can login with Voice Recognition as Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.VOICE.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest, voice: voice) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### TouchId Verification
You may want to allow users to use their touchId on their mobile devices or computer peripheral to be used for passwordless login.To use TouchId Verification for passwordless login, you need to configure it first.

#### Configure TouchId Verification

To configure TouchId Verification, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.TOUCHID.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.configure(configureRequest: configureRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**


```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via Touch Id Verification

Once you have configured Touch Id Verification, you can also login with Touch Id Verification for Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.TOUCHID.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### Pattern Recognition
If you want to offer a passwordless login after securing it with the secure pattern that user can define on their device, you can use this option.  To use Pattern Recognition for passwordless login, you need to configure it first.

#### Configure Pattern Recognition

To configure Pattern Recognition, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.PATTERN.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.configure(configureRequest: configureRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**


```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,   
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via Pattern Recognition

Once you have configured Pattern Recognition, you can also login with Pattern Recognition for Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.PATTERN.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

### SmartPush Notification
SmartPush notification can be used when you would like users to receive a number on their device and use that to authenticate instead of password. To use SmartPush Notification for passwordless login, you need to configure it first.

#### Configure SmartPush Notification

To configure SmartPush Notification, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.PUSH.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.configure(configureRequest: configureRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**


```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via SmartPush Notification

Once you configure SmartPush Notification, you can also login with SmartPush Notification for Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.PUSH.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```
#### TOTP
You can configure passwordless login with an OTP that has to be valid only for a fixed duration. To use TOTP for passwordless login, you need to configure TOTP physical verification first.

#### Configure TOTP

To configure TOTP verification, call **configure()**.

```swift
let configureRequest: ConfigureRequest = ConfigureRequest()
configureRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
configureRequest.verificationType = VerificationTypes.TOTP.rawValue
configureRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.configure(configureRequest: configureRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**


```swift
{
    "success": true,
    "status": 200,
    "data": {
        "enrolled": true,
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via TOTP

Once you configure TOTP, you can login with TOTP for Passwordless authentication. To login, call **login()**.

```swift
let loginRequest: LoginRequest = LoginRequest()
loginRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
loginRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
loginRequest.verificationType = VerificationTypes.TOTP.rawValue
loginRequest.request_id = "6kjasg-kjasdjasd-dwewer23f-adsfdsfsdf"

verification.login(loginRequest: loginRequest) {
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### Email

To setup a passwordless login, where user types only an Email, you need to configure your Email first and verify. By default, when you verify your Email during account verification, you are setup for passwordless login.

#### Configure Email

To receive a verification code via Email, call **setup()**.

```swift
let setupRequest:SetupRequest = SetupRequest()
setupRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
setupRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.setup(verificationType: VerificationTypes.EMAIL.rawValue, setupRequest: setupRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Enroll Email

Once you receive your verification code via Email, you need to verify that code. For that verification, call **enroll()**.

```swift
let enrollRequest:EnrollRequest = EnrollRequest()
enrollRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
enrollRequest.pass_code = "785234"

verification.enroll(verificationType: VerificationTypes.EMAIL.rawValue, enrollRequest: enrollRequest){
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the Email

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via Email

Once you have configured for Email login, you can also login with your Email for Passwordless authentication. To receive a verification code via Email, call **initiate()**.

```swift

let initiateRequest = InitiateRequest()
initiateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
initiateRequest.request_id = "6f7e672c-1e69-4108-92c4-3556f13eda74"
initiateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"

verification.initiate(verificationType: VerificationTypes.EMAIL.rawValue, initiateRequest: initiateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Verify Email

Once you receive your verification code via Email, you need to verify the code. For that verification, call **verify()**.

```swift
let authenticateRequest: AuthenticateRequest = AuthenticateRequest()
authenticateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
authenticateRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
authenticateRequest.request_id = "4jhgassdfgfweew-3453sdfsdfwf-3dfe4sdfsdf"
authenticateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
authenticateRequest.pass_code = "758456"

verification.verify(verificationType: VerificationTypes.EMAIL.rawValue, authenticateRequest: authenticateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the Email

**Response:**
```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### SMS

To use SMS as a passwordless login, you need to configure SMS physical verification first, and verify your mobile number. If you have already verified your mobile number using SMS during account verification, it is by default setup for passwordless login. 

#### Configure SMS

To receive a verification code via SMS, call **setup()**.

```swift
let setupRequest:SetupRequest = SetupRequest()
setupRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
setupRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.setup(verificationType: VerificationTypes.SMS.rawValue, setupRequest: setupRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Enroll SMS

Once you receive your verification code via SMS, you need to verify the code. For that verification, call **enroll()**.

```swift
let enrollRequest:EnrollRequest = EnrollRequest()
enrollRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
enrollRequest.pass_code = "785234"

verification.enroll(verificationType: VerificationTypes.SMS.rawValue, enrollRequest: enrollRequest){
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the SMS

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via SMS

Once you configure SMS, you can also login with SMS for Passwordless authentication. To receive a verification code via SMS, call **initiate()**.

```swift

let initiateRequest = InitiateRequest()
initiateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
initiateRequest.request_id = "6f7e672c-1e69-4108-92c4-3556f13eda74"
initiateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"

verification.initiate(verificationType: VerificationTypes.SMS.rawValue, initiateRequest: initiateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Verify SMS

Once you receive your verification code via SMS, you need to verify the code. For that verification, call **verify()**.

```swift
let authenticateRequest: AuthenticateRequest = AuthenticateRequest()
authenticateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
authenticateRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
authenticateRequest.request_id = "4jhgassdfgfweew-3453sdfsdfwf-3dfe4sdfsdf"
authenticateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
authenticateRequest.pass_code = "758456"

verification.verify(verificationType: VerificationTypes.SMS.rawValue, authenticateRequest: authenticateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the Email

**Response:**
```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### IVR

To use IVR as a passwordless login, you need to configure IVR physical verification first and verify your mobile number. If you have already verified your mobile number through account verification via IVR, it is already configured. 

#### Configure IVR

To receive a verification code via IVR, call **setup()**.

```swift
let setupRequest:SetupRequest = SetupRequest()
setupRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
setupRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.setup(verificationType: VerificationTypes.IVR.rawValue, setupRequest: setupRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Enroll IVR

Once you receive your verification code for IVR verification call, you need to verify the code. For that verification, call **enroll()**.

```swift
let enrollRequest:EnrollRequest = EnrollRequest()
enrollRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
enrollRequest.pass_code = "785234"

verification.enroll(verificationType: VerificationTypes.IVR.rawValue, enrollRequest: enrollRequest){
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the Email

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "sub": "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
    }
}
```

#### Login via IVR

Once you configure IVR, you can also login with IVR for Passwordless authentication. To receive a verification code via IVR verification call, call **initiate()**.

```swift

let initiateRequest = InitiateRequest()
initiateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
initiateRequest.request_id = "6f7e672c-1e69-4108-92c4-3556f13eda74"
initiateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"

verification.initiate(verificationType: VerificationTypes.IVR.rawValue, initiateRequest: initiateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Verify IVR

Once you receive your verification code via IVR, you need to verify the code. For that verification, call **verify()**.

```swift
let authenticateRequest: AuthenticateRequest = AuthenticateRequest()
authenticateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
authenticateRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
authenticateRequest.request_id = "4jhgassdfgfweew-3453sdfsdfwf-3dfe4sdfsdf"
authenticateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
authenticateRequest.pass_code = "758456"

verification.verify(verificationType: VerificationTypes.IVR.rawValue, authenticateRequest: authenticateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```
Here, **pass_code** is the key you would get from the Email

**Response:**
```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```

#### BackupCode

To use Backupcode for passwordless login, you need to configure Backupcode physical verification first.

#### Configure BackupCode

To configure or view the Backupcode, call **setup()**.

```swift
let setupRequest:SetupRequest = SetupRequest()
setupRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
setupRequest.access_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV"

verification.setup(verificationType: VerificationTypes.BACKUPCODE.rawValue, setupRequest: setupRequest) {
    switch $0 {
        case .success(let configureSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,    
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Login via Backupcode

Once you configure Backupcode, you can also login with Backupcode for Passwordless authentication. To login with Backupcode, call **initiate()**.

```swift

let initiateRequest = InitiateRequest()
initiateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
initiateRequest.request_id = "6f7e672c-1e69-4108-92c4-3556f13eda74"
initiateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"

verification.initiate(verificationType: VerificationTypes.BACKUPCODE.rawValue, initiateRequest: initiateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**

```json
{
    "success": true,
    "status": 200,
    "data": {
        "exchange_id": {
            "exchange_id": "jahsg87y833-nbvasda-nasa"
        }
    }
}
```

#### Verify Backupcode


```swift
let authenticateRequest: AuthenticateRequest = AuthenticateRequest()
authenticateRequest.sub = "7dfb2122-fa5e-4f7a-8494-dadac9b43f9d"
authenticateRequest.exchange_id = "jahsg87y833-nbvasda-nasa"
authenticateRequest.request_id = "4jhgassdfgfweew-3453sdfsdfwf-3dfe4sdfsdf"
authenticateRequest.usage_type = "PASSWORDLESS_AUTHENTICATION"
authenticateRequest.pass_code = "758456"

verification.verify(verificationType: VerificationTypes.BACKUPCODE.rawValue, authenticateRequest: authenticateRequest){
    switch $0 {
        case .success(let loginWithSuccess):
            // your success code here
        break
        case .failure(let error):
            // your failure code here
        break
    }
}
```

**Response:**
```json
{
    "success": true,
    "status": 200,
    "data": {
        "token_type": "Bearer",
        "expires_in": 86400,
        "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjUxNWYxMGE5LTV",
        "session_state": "CNT7TF6Og-cCNq4Y68",
        "viewtype": "login",
        "grant_type": "login"
    }
}
```