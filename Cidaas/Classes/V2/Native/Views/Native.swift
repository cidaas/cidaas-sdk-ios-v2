//
//  Native.swift
//  Cidaas
//
//  Created by Ganesh on 13/05/20.
//

import Foundation

public class CidaasNative {
    public static var shared: CidaasNative = CidaasNative()
    var sharedAccountVerificationViewController: AccountVerificationViewController
    var sharedTenantViewController: TenantViewController
    var sharedClientViewController: ClientViewController
    var sharedAuthzViewController: AuthzViewController
    var sharedSettingsViewController: SettingsViewController
    var sharedUserActivityViewController: UserActivityViewController
    var sharedDeduplicationViewController: DeduplicationViewController
    var sharedResetPasswordViewController: ResetPasswordViewController
    var sharedRegistrationViewController: RegistrationViewController
    var sharedChangePasswordViewController: ChangePasswordViewController
    var sharedSetPasswordViewController: SetPasswordViewController
    var sharedLinkUnlinkViewController: LinkUnlinkViewController
    var sharedLoginViewController: LoginViewController
    var sharedLogoutController: LogoutController
    var enablePkce : Bool = true
    var propertyFileRead: Bool = false
    
    public init() {
        sharedAccountVerificationViewController = AccountVerificationViewController.shared
        sharedTenantViewController = TenantViewController.shared
        sharedClientViewController = ClientViewController.shared
        sharedAuthzViewController = AuthzViewController.shared
        sharedSettingsViewController = SettingsViewController.shared
        sharedUserActivityViewController = UserActivityViewController.shared
        sharedDeduplicationViewController = DeduplicationViewController.shared
        sharedResetPasswordViewController = ResetPasswordViewController.shared
        sharedRegistrationViewController = RegistrationViewController.shared
        sharedChangePasswordViewController = ChangePasswordViewController.shared
        sharedSetPasswordViewController = SetPasswordViewController.shared
        sharedLinkUnlinkViewController = LinkUnlinkViewController.shared
        sharedLoginViewController = LoginViewController.shared
        sharedLogoutController = LogoutController.shared
        readPropertyFile();
    }
    
    // login with credentials service
    public func loginWithCredentials(incomingData : LoginEntity, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        sharedLoginViewController.loginWithCredentials(incomingData: incomingData, callback: callback)
    }

    public func loginAfterRegister(trackId: String, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        sharedLoginViewController.loginAfterRegister(trackId: trackId, callback: callback)
    }
    
    // logout service
    public func logout(sub : String, callback: @escaping(Result<Bool>) -> Void){
        print("logout process")
        sharedLogoutController.logout(sub : sub, callback: callback)
    }
    
    public func logout(access_token : String, callback: @escaping(Result<Bool>) -> Void){
        print("logout process")
        sharedLogoutController.logout(access_token : access_token, callback: callback)
    }
    
    // Account verification
    public func initiateAccountVerification(accountVerificationEntity : InitiateAccountVerificationEntity, callback: @escaping (Result<InitiateAccountVerificationResponseEntity>) -> Void) {
        sharedAccountVerificationViewController.initiateAccountVerification(accountVerificationEntity: accountVerificationEntity, callback: callback)
    }
    public func verifyAccount(accountVerificationEntity : VerifyAccountEntity, callback: @escaping (Result<VerifyAccountResponseEntity>) -> Void) {
        sharedAccountVerificationViewController.verifyAccount(accountVerificationEntity: accountVerificationEntity, callback: callback)
    }
    public func getAccountVerificationList(sub: String, callback: @escaping (Result<AccountVerificationListResponseEntity>) -> Void) {
        sharedAccountVerificationViewController.getAccountVerificationList(sub: sub, callback: callback)
    }
    
    // Tenant Info
    public func getTenantInfo(callback: @escaping(Result<TenantInfoResponseEntity>) -> Void) {
        sharedTenantViewController.getTenantInfo(callback: callback)
    }
    
    // Client Info
    public func getClientInfo(requestId: String, callback: @escaping(Result<ClientInfoResponseEntity>) -> Void) {
        sharedClientViewController.getClientInfo(requestId: requestId, callback: callback)
    }
    
    // Get Request Id
    public func getRequestId(extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping(Result<RequestIdResponseEntity>) -> Void) {
        sharedAuthzViewController.getRequestId(extraParams: extraParams, callback: callback)
    }
    
    // Get Endpoints
    public func getEndpoints(callback: @escaping(Result<EndpointsResponseEntity>) -> Void) {
        sharedSettingsViewController.getEndpoints(callback: callback)
    }
    
    // Get User Activity
    public func getUserActivity(accessToken : String, incomingData: UserActivityEntity, callback: @escaping(Result<UserActivityResponseEntity>) -> Void) {
        sharedUserActivityViewController.getUserActivity(accessToken: accessToken, incomingData: incomingData, callback: callback)
    }
    
    // Get Deduplication details
    public func getDeduplicationDetails(track_id: String, callback: @escaping(Result<DeduplicationDetailsResponseEntity>) -> Void) {
        sharedDeduplicationViewController.getDeduplicationDetails(track_id: track_id, callback: callback)
    }
    
    // Register Deduplication
    public func registerDeduplication(track_id: String, callback: @escaping(Result<RegistrationResponseEntity>) -> Void) {
        sharedDeduplicationViewController.registerDeduplication(track_id: track_id, callback: callback)
    }
    
    // Deduplication Login
    public func deduplicationLogin(incomingData : LoginEntity, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        sharedDeduplicationViewController.deduplicationLogin(incomingData: incomingData, callback: callback)
    }
    
    // Initiate reset password
    public func initiateResetPassword(incomingData : InitiateResetPasswordEntity, callback: @escaping(Result<InitiateResetPasswordResponseEntity>) -> Void) {
        sharedResetPasswordViewController.initiateResetPassword(incomingData: incomingData, callback: callback)
    }
    
    // Handle reset password
    public func handleResetPassword(incomingData : HandleResetPasswordEntity, callback: @escaping(Result<HandleResetPasswordResponseEntity>) -> Void) {
        sharedResetPasswordViewController.handleResetPassword(incomingData: incomingData, callback: callback)
    }
    
    // reset password
    public func resetPassword(incomingData : ResetPasswordEntity, callback: @escaping(Result<ResetPasswordResponseEntity>) -> Void) {
        sharedResetPasswordViewController.resetPassword(incomingData: incomingData, callback: callback)
    }
    
    // Get registration fields
    public func getRegistrationFields(acceptlanguage: String, requestId: String, callback: @escaping(Result<RegistrationFieldsResponseEntity>) -> Void) {
        sharedRegistrationViewController.getRegistrationFields(acceptlanguage: acceptlanguage, requestId: requestId, callback: callback)
    }
    
    // Register user
    public func registerUser(requestId: String, incomingData: RegistrationEntity, callback: @escaping(Result<RegistrationResponseEntity>) -> Void) {
        sharedRegistrationViewController.registerUser(requestId: requestId, incomingData: incomingData, callback: callback)
    }
    
    // update user service
    public func updateUser(access_token: String, incomingData: RegistrationEntity, callback: @escaping(Result<UpdateUserResponseEntity>) -> Void) {
        sharedRegistrationViewController.updateUser(access_token: access_token, incomingData: incomingData, callback: callback)
    }
    
    // Change password
    public func changePassword(access_token: String, incomingData : ChangePasswordEntity, callback: @escaping(Result<ChangePasswordResponseEntity>) -> Void) {
        sharedChangePasswordViewController.changePassword(access_token: access_token, incomingData: incomingData, callback: callback)
    }

    // Set password (first-time / profile)
    public func setPassword(access_token: String, incomingData: SetPasswordEntity, callback: @escaping (Result<SetPasswordResponseEntity>) -> Void) {
        sharedSetPasswordViewController.setPassword(access_token: access_token, incomingData: incomingData, callback: callback)
    }
    
    // link user
    public func linkAccount(access_token: String, incomingData : LinkAccountEntity, callback: @escaping(Result<LinkAccountResponseEntity>) -> Void) {
        sharedLinkUnlinkViewController.linkAccount(access_token: access_token, incomingData: incomingData, callback: callback)
    }
    
    // get linked users
    public func getLinkedUsers(access_token: String, sub: String, callback: @escaping(Result<LinkedUserListResponseEntity>) -> Void) {
        sharedLinkUnlinkViewController.getLinkedUsers(access_token: access_token, sub: sub, callback: callback)
    }
    
    // unlink user
    public func unlinkAccount(access_token: String, identityId: String, callback: @escaping(Result<LinkAccountResponseEntity>) -> Void) {
        sharedLinkUnlinkViewController.unlinkAccount(access_token: access_token, identityId: identityId, callback: callback)
    }
    
    // read property file
       public func readPropertyFile() {
           FileHelper.shared.readProperties {
               switch $0 {
               case .failure(let error):
                   // log error
                   let loggerMessage = "Read properties file failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                   logw(loggerMessage, cname: "cidaas-sdk-error-log")
                   
                   return
               case .success(let properties):
                   // log success
                   let loggerMessage = "Read properties file success : " + "Properties Count - " + String(describing: properties.count)
                   logw(loggerMessage, cname: "cidaas-sdk-success-log")
                   
                   
                   self.saveProperties(properties: properties) {
                       switch $0 {
                       case .failure (let error):
                           // log error
                           let loggerMessage = "Saving properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                           logw(loggerMessage, cname: "cidaas-sdk-error-log")
                           return
                       case .success(let response):
                           // log success
                           let loggerMessage = "Saved Property status : \(response)"
                           logw(loggerMessage, cname: "cidaas-sdk-success-log")
                           self.propertyFileRead = true
                           break
                       }
                   }
               }
           }
       }
    func saveProperties(properties: Dictionary<String, String>, callback:@escaping (Result<Bool>) -> Void) {
        var savedProperties = properties
        
        if self.enablePkce == false {
            // client secret null check
            if properties["ClientSecret"] == "" || properties["ClientSecret"] == nil {
                let error = WebAuthError.shared.propertyMissingException()
                // log error
                let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                logw(loggerMessage, cname: "cidaas-sdk-error-log")
                
                DispatchQueue.main.async {
                    callback(Result.failure(error: error))
                }
                return
            }
            else {
                savedProperties["ClientSecret"] = properties["ClientSecret"]
            }
        }
            
        else {
            // create challenge and verifier
            let generator : OAuthChallengeGenerator = OAuthChallengeGenerator()
            savedProperties["Verifier"] = generator.verifier
            savedProperties["Challenge"] = generator.challenge()
            savedProperties["Method"] = generator.method
        }
        savedProperties["AuthorizationURL"] = (properties["DomainURL"]!) + "/authz-srv/authz"
        savedProperties["TokenURL"] = (properties["DomainURL"]!) + "/token-srv/token"
        savedProperties["GrantType"] = "authorization_code"
        savedProperties["ResponseType"] = "code"
        savedProperties["UserInfoURL"] = (properties["DomainURL"]!) + "/users-srv/userinfo"
        savedProperties["CidaasVersion"] = (properties["CidaasVersion"]!)
        

        // save local
        DBHelper.shared.setPropertyFile(properties: savedProperties)
        
        DispatchQueue.main.async {
            callback(Result.success(result: true))
        }
    }
}
