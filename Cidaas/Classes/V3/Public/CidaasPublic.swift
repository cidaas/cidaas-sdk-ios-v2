//
//  CidaasPublic.swift
//  Cidaas
//

import Foundation

extension Cidaas {
    /// Pre-login public APIs (OAuth request id, verification catalog).
    public func publicAPI() -> CidaasPublicBuilder {
        CidaasPublicBuilder()
    }

    /// Convenience alias for ``Cidaas/publicAPI()`` — e.g. `Cidaas.public().requestId(...)`.
    public static func `public`() -> CidaasPublicBuilder {
        shared.publicAPI()
    }
}

public final class CidaasPublicBuilder {

    /// OAuth `request_id` with required `cidaas_dr` Cookie.
    public func requestId(
        extraParams: [String: String] = [:],
        completion: @escaping (Result<RequestIdResponseEntity>) -> Void
    ) {
        let params = CidaasHTTPProofAuthz.mergingDpopJKT(into: extraParams)
        AuthzInteractor.shared.getRequestId(extraParams: params) { result in
            CidaasV3Callback.deliver(result, to: completion)
        }
    }

    /// Lists passwordless sign-in methods for an identifier (`POST /verification-srv/public/graph/user/setup`).
    public func fetchConfiguredList(
        requestId: String,
        identifier: String,
        completion: @escaping (Result<PublicConfiguredListResponse>) -> Void
    ) {
        let rid = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "request_id is required", statusCode: 417
            )), to: completion)
            return
        }
        guard !id.isEmpty else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "identifier is required", statusCode: 417
            )), to: completion)
            return
        }
        guard let properties = DBHelper.shared.getPropertyFile() else {
            CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "OAuth properties not loaded", statusCode: 417
            )), to: completion)
            return
        }

        var body = PublicConfiguredListRequest()
        body.request_id = rid
        if id.contains("@") {
            body.email = id
        } else {
            body.identifier = id
        }

        PublicConfiguredListService.shared.fetch(
            request: body,
            properties: properties
        ) { response, error in
            if let error {
                CidaasV3Callback.deliver(.failure(error: error), to: completion)
                return
            }
            guard let response else {
                CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 500, errorMessage: "Empty public configured list response", statusCode: 500
                )), to: completion)
                return
            }
            do {
                let data = response.data(using: .utf8) ?? Data()
                let decoded = try JSONDecoder().decode(PublicConfiguredListResponse.self, from: data)
                CidaasV3Callback.deliver(.success(result: decoded), to: completion)
            } catch {
                CidaasV3Callback.deliver(.failure(error: WebAuthError.shared.serviceFailureException(
                    errorCode: 500, errorMessage: error.localizedDescription, statusCode: 500
                )), to: completion)
            }
        }
    }
}

public class PublicConfiguredListRequest: Codable {
    public init() {}
    public var request_id: String = ""
    public var identifier: String = ""
    public var email: String = ""
    public var sub: String = ""
    public var mobile_number: String = ""
    public var username: String = ""
}

public class PublicConfiguredListResponse: Codable {
    public init() {}
    public var success: Bool = true
    public var status: Int32 = 200
    public var data: PublicConfiguredListResponseData = PublicConfiguredListResponseData()
    public var configured_list: [PublicConfiguredListItem]?

    public var resolvedList: [PublicConfiguredListItem] {
        if !data.configured_list.isEmpty { return data.configured_list }
        return configured_list ?? []
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        self.status = try container.decodeIfPresent(Int32.self, forKey: .status) ?? 200
        self.data = try container.decodeIfPresent(PublicConfiguredListResponseData.self, forKey: .data) ?? PublicConfiguredListResponseData()
        self.configured_list = try container.decodeIfPresent([PublicConfiguredListItem].self, forKey: .configured_list)
    }
}

public class PublicConfiguredListResponseData: Codable {
    public init() {}
    public var configured_list: [PublicConfiguredListItem] = []

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.configured_list = try container.decodeIfPresent([PublicConfiguredListItem].self, forKey: .configured_list) ?? []
    }
}

public class PublicConfiguredListItem: Codable {
    public init() {}
    public var verification_type: String = ""
    public var type: String = ""
    public var medium_id: String?
    public var mediums: [PublicConfiguredMedium]?

    public var resolvedType: String {
        let value = verification_type.isEmpty ? type : verification_type
        return value.uppercased()
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.verification_type = try container.decodeIfPresent(String.self, forKey: .verification_type) ?? ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.medium_id = try container.decodeIfPresent(String.self, forKey: .medium_id)
        self.mediums = try container.decodeIfPresent([PublicConfiguredMedium].self, forKey: .mediums)
    }
}

public class PublicConfiguredMedium: Codable {
    public init() {}
    public var id: String = ""
    public var medium_id: String = ""
    public var key_name: String = ""

    public var resolvedId: String {
        !id.isEmpty ? id : medium_id
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.medium_id = try container.decodeIfPresent(String.self, forKey: .medium_id) ?? ""
        self.key_name = try container.decodeIfPresent(String.self, forKey: .key_name) ?? ""
    }
}

private enum PublicConfiguredListService {
    static let shared = PublicConfiguredListWorker()
}

private final class PublicConfiguredListWorker {
    private let session = SessionManager.shared

    func fetch(
        request: PublicConfiguredListRequest,
        properties: [String: String],
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        guard let baseURL = properties["DomainURL"], !baseURL.isEmpty else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417, errorMessage: "DomainURL missing", statusCode: 417
            ))
            return
        }
        let url = baseURL + "/verification-srv/public/graph/user/setup"
        var bodyParams: [String: Any] = [:]
        do {
            let data = try JSONEncoder().encode(request)
            bodyParams = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        session.startSession(
            url: url,
            method: .post,
            parameters: bodyParams,
            callback: callback
        )
    }
}
