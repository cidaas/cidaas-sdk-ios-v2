//
//  InitLoginLocationParser.swift
//  Cidaas
//

import Foundation

/// Outcome of inspecting the final URL from `GET /authz-srv/authz` (after redirects).
enum InitLoginLocationOutcome: Equatable {
    case authorizationCode(String)
    /// Call `GET /token-srv/prelogin/metadata/{trackId}`.
    case preloginTrack(trackId: String, requestId: String?, sub: String?)
    case loginRequired(requestId: String)
    case unrecognized
}

enum InitLoginLocationParser {

    static func parse(location: String, redirectURI: String) -> InitLoginLocationOutcome {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let redirect = redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return .unrecognized }

        if !redirect.isEmpty, loc.lowercased().hasPrefix(redirect.lowercased()) {
            if let code = queryValue("code", in: loc), !code.isEmpty {
                return .authorizationCode(code)
            }
            // Step-up / MFA redirect onto redirect_uri with track_id (no code yet).
            if let trackId = queryValue("track_id", in: loc), !trackId.isEmpty {
                return .preloginTrack(
                    trackId: trackId,
                    requestId: queryValue("request_id", in: loc) ?? queryValue("requestId", in: loc),
                    sub: queryValue("sub", in: loc)
                )
            }
            return .unrecognized
        }

        // Prefer track_id (step-up) over bare requestId when both are present.
        if let trackId = queryValue("track_id", in: loc), !trackId.isEmpty {
            return .preloginTrack(
                trackId: trackId,
                requestId: queryValue("request_id", in: loc) ?? queryValue("requestId", in: loc),
                sub: queryValue("sub", in: loc)
            )
        }

        if let requestId = queryValue("request_id", in: loc) ?? queryValue("requestId", in: loc),
           !requestId.isEmpty {
            return .loginRequired(requestId: requestId)
        }
        return .unrecognized
    }

    static func queryValue(_ name: String, in urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return queryValueFromRawString(name, in: urlString)
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = comps.queryItems {
            if let value = items.first(where: { $0.name == name })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return queryValueFromRawString(name, in: urlString)
    }

    /// Fallback when `URL` / `URLComponents` fail on custom schemes.
    private static func queryValueFromRawString(_ name: String, in urlString: String) -> String? {
        guard let queryStart = urlString.firstIndex(of: "?") else { return nil }
        let query = urlString[urlString.index(after: queryStart)...]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == name else { continue }
            let decoded = parts[1].removingPercentEncoding ?? parts[1]
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}

/// Public result for ``CidaasPublicBuilder/initLogin(extraParams:completion:)``.
public enum InitLoginResult {
    case loggedIn(LoginResponseEntity)
    case loginRequired(requestId: String)
    case mfaRequired(InitLoginMFARequired)
}

/// MFA step-up payload from prelogin metadata when `validation_type == mfa_required`.
public struct InitLoginMFARequired {
    public let trackId: String
    public let requestId: String
    public let sub: String
    public let validationType: String
    public let userConfiguredMethods: [PreloginConfiguredMethod]
    public let metaData: PreloginMetaData

    public init(
        trackId: String,
        requestId: String,
        sub: String,
        validationType: String,
        userConfiguredMethods: [PreloginConfiguredMethod],
        metaData: PreloginMetaData
    ) {
        self.trackId = trackId
        self.requestId = requestId
        self.sub = sub
        self.validationType = validationType
        self.userConfiguredMethods = userConfiguredMethods
        self.metaData = metaData
    }
}
