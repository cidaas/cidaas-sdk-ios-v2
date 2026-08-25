//
//  ParServiceWorker.swift
//  Cidaas
//

import Foundation
import Alamofire

/// POST `/authz-srv/par` → `request_uri`.
public class ParServiceWorker {

    public static var shared = ParServiceWorker()

    private let session: SessionManager
    private let parPath = "/authz-srv/par"

    public init(session: SessionManager = .shared) {
        self.session = session
    }

    /// Form-urlencoded PAR. Sends `DPoP` when `ENABLE_DPOP` is on.
    public func pushAuthorizationRequest(
        bodyParams: [String: String],
        properties: [String: String],
        callback: @escaping (Result<ParResponseEntity>) -> Void
    ) {
        var baseURL = (properties["DomainURL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        while baseURL.hasSuffix("/") {
            baseURL.removeLast()
        }
        guard !baseURL.isEmpty else {
            finish(.failure(error: WebAuthError.shared.propertyMissingException()), callback)
            return
        }

        var params = bodyParams
        let secret = (properties["ClientSecret"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !secret.isEmpty, params["client_secret"] == nil {
            params["client_secret"] = secret
        }

        var headers: [String: String] = [:]
        let deviceId = SDKDeviceIdResolver.resolve()
        if !deviceId.isEmpty {
            headers["Cookie"] = "cidaas_dr=\(deviceId)"
        }

        session.startSession(
            url: baseURL + parPath,
            method: .post,
            parameters: params,
            encoding: URLEncoding.httpBody,
            extraheaders: headers
        ) { response, error in
            if let error {
                self.finish(.failure(error: error), callback)
                return
            }
            guard let response, let data = response.data(using: .utf8) else {
                self.finish(.failure(error: self.jsonParseError()), callback)
                return
            }
            do {
                let entity = try JSONDecoder().decode(ParResponseEntity.self, from: data)
                guard !entity.request_uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.finish(.failure(error: WebAuthError.shared.serviceFailureException(
                        errorCode: WebAuthErrorCode.ERROR_JSON_PARSING.rawValue,
                        errorMessage: "PAR response missing request_uri",
                        statusCode: HttpStatusCode.DEFAULT.rawValue
                    )), callback)
                    return
                }
                self.finish(.success(result: entity), callback)
            } catch {
                self.finish(.failure(error: self.jsonParseError()), callback)
            }
        }
    }

    private func jsonParseError() -> WebAuthError {
        WebAuthError.shared.serviceFailureException(
            errorCode: WebAuthErrorCode.ERROR_JSON_PARSING.rawValue,
            errorMessage: StringsHelper.shared.ERROR_JSON_PARSING,
            statusCode: HttpStatusCode.DEFAULT.rawValue
        )
    }

    private func finish(
        _ result: Result<ParResponseEntity>,
        _ callback: @escaping (Result<ParResponseEntity>) -> Void
    ) {
        DispatchQueue.main.async {
            callback(result)
        }
    }
}
