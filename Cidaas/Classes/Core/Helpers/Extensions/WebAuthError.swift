//
//  WebAuthError.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

public class WebAuthError : Error, LocalizedError, CustomStringConvertible, OauthExceptionDelegate {
    
    // shared Instance
    public static var shared : WebAuthError = WebAuthError()
    
    // local variables
    public var errorCode : Any = ""
    public var statusCode : Int = HttpStatusCode.DEFAULT.rawValue
    public var errorMessage : String = StringsHelper.shared.DEFAULT
    public var error: ErrorResponseEntity = ErrorResponseEntity()

    /// Prefer `errorMessage` so hosts/demos using `localizedDescription`.
    public var errorDescription: String? {
        let trimmed = errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var description: String {
        errorDescription ?? "WebAuthError(statusCode: \(statusCode))"
    }
    
    // file not found exception
    public func fileNotFoundException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.FILE_NOT_FOUND.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.FILE_NOT_FOUND
        WebAuthError.shared.statusCode = HttpStatusCode.NOT_FOUND.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // no content in file exception
    public func noContentInFileException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.NO_CONTENT_IN_FILE.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.NO_CONTENT_IN_FILE
        WebAuthError.shared.statusCode = HttpStatusCode.NO_CONTENT.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // notification timeout exception
    public func notificationTimeoutException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.NOTIFICATION_TIMEOUT.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.NOTIFICATION_TIMEOUT
        WebAuthError.shared.statusCode = HttpStatusCode.EXPECTATION_FAILED.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        WebAuthError.shared.error.error.code = String(WebAuthErrorCode.NOTIFICATION_TIMEOUT.rawValue ?? 0)
        return WebAuthError.shared
    }
    
    // property missing exception
    public func propertyMissingException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.PROPERT_MISSING.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.PROPERTY_MISSING
        WebAuthError.shared.statusCode = HttpStatusCode.EXPECTATION_FAILED.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // conversion exception
    public func conversionException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.CONVERSION_EXCEPTION.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.CONVERSION_EXCEPTION
        WebAuthError.shared.statusCode = HttpStatusCode.INTERNAL_SERVER_ERROR.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // service failure exception
    public func serviceFailureException(errorCode : Any, errorMessage : String, statusCode : Int, error: ErrorResponseEntity = ErrorResponseEntity()) -> WebAuthError {
        WebAuthError.shared.errorCode = (errorCode as? String) ?? String(describing: errorCode)
        WebAuthError.shared.errorMessage = errorMessage
        WebAuthError.shared.statusCode = statusCode
        WebAuthError.shared.error = error
        return WebAuthError.shared
    }
    
    // login url missing exception
    public func netWorkTimeoutException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.NETWORK_TIMEOUT.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.NETWORK_TIMEOUT
        WebAuthError.shared.statusCode = HttpStatusCode.GATEWAY_TIMEOUT.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        WebAuthError.shared.error.error.code = String(WebAuthErrorCode.NETWORK_TIMEOUT.rawValue ?? 0)
        return WebAuthError.shared
    }
    
    // login url missing exception
    public func loginURLMissingException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.EMPTY_LOGIN_URL.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.EMPTY_LOGIN_URL
        WebAuthError.shared.statusCode = HttpStatusCode.EXPECTATION_FAILED.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // redirect url missing exception
    public func redirectURLMissingException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.EMPTY_REDIRECT_URL.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.EMPTY_REDIRECT_URL
        WebAuthError.shared.statusCode = HttpStatusCode.EXPECTATION_FAILED.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // delegate missing exception
    public func delegateMissingException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.EMPTY_DELEGATE.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.EMPTY_DELEGATE
        WebAuthError.shared.statusCode = HttpStatusCode.EXPECTATION_FAILED.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // user cancelled exception
    public func userCancelledException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.USER_CANCELLED_LOGIN.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.USER_CANCELLED_LOGIN
        WebAuthError.shared.statusCode = HttpStatusCode.CANCEL_REQUEST.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // logoutWithBrowser failure exception
    public func logoutWithBrowserFailureException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.LOGOUT_WITH_BROWSER_FAILURE.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.LOGOUT_WITH_BROWSER_FAILURE
        WebAuthError.shared.statusCode = HttpStatusCode.GATEWAY_TIMEOUT.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // code not found exception
    public func codeNotFoundException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.CODE_NOT_FOUND.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.CODE_NOT_FOUND
        WebAuthError.shared.statusCode = HttpStatusCode.NO_CONTENT.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // empty callback exception
    public func emptyCallbackException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.EMPTY_CALLBACK.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.EMPTY_CALLBACK
        WebAuthError.shared.statusCode = HttpStatusCode.BAD_REQUEST.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
    
    // no user found exception
    public func noUserFoundException() -> WebAuthError {
        WebAuthError.shared.errorCode = String(WebAuthErrorCode.NO_USER_FOUND.rawValue ?? 0)
        WebAuthError.shared.errorMessage = StringsHelper.shared.NO_USER_FOUND
        WebAuthError.shared.statusCode = HttpStatusCode.NOT_FOUND.rawValue
        WebAuthError.shared.error = ErrorResponseEntity()
        return WebAuthError.shared
    }
}
