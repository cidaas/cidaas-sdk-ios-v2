//
//  ContinueLoginChallenge.swift
//  Cidaas
//
//  Precheck failure from POST /login-srv/verification/sdk/login when MFA/step-up is required.
//

import Foundation

/// Body shape when continue-login prechecks fail with `data.error == mfa_required`.
struct ContinueLoginChallenge: Equatable {
    let trackId: String
    let requestId: String
    let sub: String
    let error: String
    let suggestedURL: String
    let clientId: String
    let status: Int

    var isMFARequired: Bool {
        error.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "mfa_required"
            && !trackId.isEmpty
    }

    func asErrorResponseEntity() -> ErrorResponseEntity {
        let entity = ErrorResponseEntity()
        entity.success = true
        entity.status = Int16(status)
        entity.error.error = error
        entity.error.track_id = trackId
        entity.error.requestId = requestId
        entity.error.sub = sub
        entity.error.suggested_url = suggestedURL
        entity.error.client_id = clientId
        return entity
    }
}

enum ContinueLoginChallengeParser {

    private struct Envelope: Codable {
        let success: Bool?
        let status: Int?
        let data: Payload?
    }

    private struct Payload: Codable {
        let error: String?
        let track_id: String?
        let trackId: String?
        let requestId: String?
        let sub: String?
        let suggested_url: String?
        let client_id: String?
    }

    static func parse(_ raw: String) -> ContinueLoginChallenge? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let payload = envelope.data else {
            return nil
        }
        let trackId = (payload.track_id ?? payload.trackId ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let error = (payload.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !error.isEmpty else { return nil }
        return ContinueLoginChallenge(
            trackId: trackId,
            requestId: (payload.requestId ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            sub: (payload.sub ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            error: error,
            suggestedURL: (payload.suggested_url ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            clientId: (payload.client_id ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            status: envelope.status ?? 417
        )
    }

    static func parse(from error: WebAuthError) -> ContinueLoginChallenge? {
        let data = error.error.error
        if data.error.lowercased() == "mfa_required" {
            let trackId = data.track_id.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trackId.isEmpty {
                return ContinueLoginChallenge(
                    trackId: trackId,
                    requestId: data.requestId,
                    sub: data.sub,
                    error: data.error,
                    suggestedURL: data.suggested_url,
                    clientId: data.client_id,
                    status: Int(error.statusCode)
                )
            }
        }
        return parse(error.errorMessage)
    }
}

enum PreloginMFARequiredResolver {

    static func fetch(
        trackId: String,
        requestId: String,
        sub: String,
        properties: [String: String]? = DBHelper.shared.getPropertyFile(),
        callback: @escaping (Result<InitLoginMFARequired>) -> Void
    ) {
        guard let properties else {
            DispatchQueue.main.async {
                callback(.failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 417,
                    errorMessage: "properties cannot be empty",
                    statusCode: 417
                )))
            }
            return
        }
        AuthzServiceWorker.shared.fetchPreloginMetadata(trackId: trackId, properties: properties) { response, error in
            if let error {
                DispatchQueue.main.async { callback(.failure(error: error)) }
                return
            }
            guard let response, let data = response.data(using: .utf8) else {
                DispatchQueue.main.async {
                    callback(.failure(error: WebAuthError.shared.serviceFailureException(
                        errorCode: 500,
                        errorMessage: "Empty prelogin metadata response",
                        statusCode: 500
                    )))
                }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(PreloginMetadataResponse.self, from: data)
                let validation = decoded.data.validation_type
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard decoded.success, validation == "mfa_required" else {
                    DispatchQueue.main.async {
                        callback(.failure(error: WebAuthError.shared.serviceFailureException(
                            errorCode: Int(decoded.status),
                            errorMessage: "prelogin metadata validation_type=\(decoded.data.validation_type) (expected mfa_required)",
                            statusCode: Int(decoded.status)
                        )))
                    }
                    return
                }
                let payload = InitLoginMFARequired(
                    trackId: trackId,
                    requestId: requestId,
                    sub: sub,
                    validationType: decoded.data.validation_type,
                    userConfiguredMethods: decoded.data.meta_data.userConfiguredMethods,
                    metaData: decoded.data.meta_data
                )
                DispatchQueue.main.async {
                    callback(.success(result: payload))
                }
            } catch {
                DispatchQueue.main.async {
                    callback(.failure(error: WebAuthError.shared.serviceFailureException(
                        errorCode: 500,
                        errorMessage: error.localizedDescription,
                        statusCode: 500
                    )))
                }
            }
        }
    }
}
