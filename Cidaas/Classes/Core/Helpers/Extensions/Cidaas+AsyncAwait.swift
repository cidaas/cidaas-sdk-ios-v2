import UIKit

@available(iOS 13.0, *)
public extension Cidaas {

    enum CidaasError: Error {
        case unknownLogoutError
    }

    private func handleAsyncCall<T>(_ operation: @escaping (@escaping (Result<T>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation {
                switch $0 {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getUserInfo(with accessToken: String) async throws -> UserInfoEntity {
        try await handleAsyncCall {
            Cidaas.shared.getUserInfo(accessToken: accessToken,
                                      callback: $0)
        }
    }

    func getClientInfo(requestId: String) async throws -> ClientInfoResponseDataEntity {
        try await handleAsyncCall {
            CidaasNative.shared.getClientInfo(requestId: requestId,
                                              callback: $0)
        }.data
    }

    func getRequestID() async throws -> String {
        try await handleAsyncCall {
            Cidaas.shared.publicAPI().requestId(extraParams: [:], completion: $0)
        }.data.requestId
    }

    func getAccessToken(with refreshToken: String) async throws -> AccessTokenEntity {
        try await handleAsyncCall {
            Cidaas.shared.getAccessToken(refreshToken: refreshToken, callback: $0)
        }.data
    }

    func getSocialLoginProviders() async throws -> [String] {
        let requestID = try await getRequestID()
        let clientInfo = try await getClientInfo(requestId: requestID)
        return clientInfo.login_providers
    }

    @discardableResult
    func loginWithBrowser(using parentViewController: UIViewController) async throws -> AccessTokenEntity {
        try await handleAsyncCall {
            Cidaas.shared.loginWithBrowser(delegate: parentViewController,
                                           callback: $0)
        }.data
    }

    @discardableResult
    func loginWithSocial(using parentViewController: UIViewController, provider: String, requestID: String) async throws -> AccessTokenEntity {
        try await handleAsyncCall {
            Cidaas.shared.loginWithSocial(provider: provider,
                                          requestId: requestID,
                                          delegate: parentViewController,
                                          callback: $0)
        }.data
    }

    @discardableResult
    func registerWithBrowser(using parentViewController: UIViewController) async throws -> AccessTokenEntity {
        try await handleAsyncCall {
            Cidaas.shared.registerWithBrowser(delegate: parentViewController,
                                              callback: $0)
        }.data
    }

    func logout(accessToken: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            CidaasNative.shared.logout(access_token: accessToken) {
                switch $0 {
                case .success(let result):
                    result ? continuation.resume() : continuation.resume(throwing: CidaasError.unknownLogoutError)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
