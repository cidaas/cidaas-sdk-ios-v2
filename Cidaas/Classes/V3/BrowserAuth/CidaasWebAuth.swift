//
//  CidaasWebAuth.swift
//  Cidaas
//

import Foundation
import UIKit

/// Which hosted page to use when building an authorization URL.
public enum BrowserAuthFlow: String {
    case login = "login"
    case registration = "register"
    case social = "social"
}

extension Cidaas {

    public enum WebAuth {

        public static func handleRedirect(_ url: URL) {
            Cidaas.shared.handleToken(url: url)
        }

        public static func authorizationURL(
            for flow: BrowserAuthFlow,
            extraParameters: [String: String] = [:],
            usePar: Bool = false,
            completion: @escaping (Result<URL>) -> Void
        ) {
            BrowserAuthPerform.authorizationURL(
                for: flow,
                extraParameters: extraParameters,
                usePar: usePar,
                completion: completion
            )
        }

        @available(iOS 13.0, *)
        public static func authorizationURL(
            for flow: BrowserAuthFlow,
            extraParameters: [String: String] = [:],
            usePar: Bool = false
        ) async throws -> URL {
            try await withCheckedThrowingContinuation { continuation in
                BrowserAuthPerform.authorizationURL(
                    for: flow,
                    extraParameters: extraParameters,
                    usePar: usePar
                ) { result in
                    continuation.resume(with: result.cidaasURLToSwiftResult())
                }
            }
        }
    }
}

enum BrowserAuthPerform {

    static func withPropertyFile<T>(
        completion: @escaping (Result<T>) -> Void,
        work: ([String: String]) -> Void
    ) {
        guard let props = DBHelper.shared.getPropertyFile() else {
            logMissingPropertyFile()
            let error = WebAuthError.shared.fileNotFoundException()
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        work(props)
    }

    static func logMissingPropertyFile() {
        let message = "Read properties file failure : Error Code -  10001, Error Message -  File not found, Status Code - 404"
        logw(message, cname: "cidaas-sdk-error-log")
    }

    static func startLogin(
        presentingFrom viewController: UIViewController,
        extraParameters: [String: String],
        usePar: Bool,
        completion: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        withPropertyFile(completion: completion) { props in
            var props = props
            props["ViewType"] = BrowserAuthFlow.login.rawValue
            Cidaas.shared.browserCallback = completion
            startBrowserLogin(
                presentingFrom: viewController,
                extraParameters: extraParameters,
                properties: props,
                usePar: usePar,
                completion: completion
            )
        }
    }

    static func startRegistration(
        presentingFrom viewController: UIViewController,
        extraParameters: [String: String],
        usePar: Bool,
        completion: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        withPropertyFile(completion: completion) { props in
            var props = props
            props["ViewType"] = BrowserAuthFlow.registration.rawValue
            Cidaas.shared.browserCallback = completion
            startBrowserLogin(
                presentingFrom: viewController,
                extraParameters: extraParameters,
                properties: props,
                usePar: usePar,
                completion: completion
            )
        }
    }

    private static func startBrowserLogin(
        presentingFrom viewController: UIViewController,
        extraParameters: [String: String],
        properties: [String: String],
        usePar: Bool,
        completion: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        guard usePar else {
            LoginController.shared.loginWithBrowser(
                delegate: viewController,
                extraParams: extraParameters,
                properties: properties,
                callback: completion
            )
            return
        }

        resolveParAuthorizationURL(
            extraParameters: extraParameters,
            properties: properties
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error: error))
            case .success(let url):
                LoginController.shared.loginWithBrowser(
                    loginURL: url,
                    delegate: viewController,
                    properties: properties,
                    callback: completion
                )
            }
        }
    }

    static func startSocialLogin(
        provider: String,
        requestId: String,
        presentingFrom viewController: UIViewController,
        completion: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        withPropertyFile(completion: completion) { props in
            Cidaas.shared.browserCallback = completion
            LoginController.shared.loginWithSocial(
                provider: provider,
                requestId: requestId,
                delegate: viewController,
                properties: props,
                callback: completion
            )
        }
    }

    static func startLogout(
        presentingFrom viewController: UIViewController,
        sub: String,
        completion: @escaping (Result<Bool>) -> Void
    ) {
        withPropertyFile(completion: completion) { props in
            Cidaas.shared.browserCallback = nil
            Cidaas.shared.browserLogoutCallback = completion
            LogoutWithBrowserController.shared.logoutWithBrowser(
                delegate: viewController,
                sub: sub,
                properties: props,
                callback: completion
            )
        }
    }

    static func startLogout(
        presentingFrom viewController: UIViewController,
        accessToken: String,
        completion: @escaping (Result<Bool>) -> Void
    ) {
        withPropertyFile(completion: completion) { props in
            Cidaas.shared.browserCallback = nil
            Cidaas.shared.browserLogoutCallback = completion
            LogoutWithBrowserController.shared.logoutWithBrowser(
                delegate: viewController,
                accessToken: accessToken,
                properties: props,
                callback: completion
            )
        }
    }

    static func authorizationURL(
        for flow: BrowserAuthFlow,
        extraParameters: [String: String],
        usePar: Bool,
        completion: @escaping (Result<URL>) -> Void
    ) {
        guard var props = DBHelper.shared.getPropertyFile() else {
            logMissingPropertyFile()
            let error = WebAuthError.shared.fileNotFoundException()
            DispatchQueue.main.async {
                completion(.failure(error: error))
            }
            return
        }
        switch flow {
        case .social:
            guard let provider = extraParameters["provider"], !provider.isEmpty,
                  let requestId = extraParameters["requestId"], !requestId.isEmpty
            else {
                let error = WebAuthError.shared.propertyMissingException()
                error.errorMessage = "authorizationURL(for: .social) requires extraParameters [\"provider\"] and [\"requestId\"]"
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
                return
            }
            let url = LoginController.shared.constructSocialURL(
                provider: provider,
                requestId: requestId,
                properties: props
            )
            DispatchQueue.main.async {
                completion(.success(result: url))
            }
        case .login, .registration:
            props["ViewType"] = flow.rawValue
            guard usePar else {
                let url = LoginController.shared.constructURL(extraParams: extraParameters, properties: props)
                DispatchQueue.main.async {
                    completion(.success(result: url))
                }
                return
            }
            resolveParAuthorizationURL(
                extraParameters: extraParameters,
                properties: props,
                completion: completion
            )
        }
    }

    private static func resolveParAuthorizationURL(
        extraParameters: [String: String],
        properties: [String: String],
        completion: @escaping (Result<URL>) -> Void
    ) {
        let bodyParams = LoginController.shared.authorizationParameters(
            extraParams: extraParameters,
            properties: properties
        )
        ParServiceWorker.shared.pushAuthorizationRequest(
            bodyParams: bodyParams,
            properties: properties
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error: error))
            case .success(let par):
                let url = LoginController.shared.constructParAuthorizationURL(
                    requestURI: par.request_uri,
                    properties: properties
                )
                completion(.success(result: url))
            }
        }
    }
}

extension Result where T == URL {
    fileprivate func cidaasURLToSwiftResult() -> Swift.Result<URL, Error> {
        switch self {
        case .success(let result):
            return .success(result)
        case .failure(let error):
            return .failure(error)
        }
    }
}
