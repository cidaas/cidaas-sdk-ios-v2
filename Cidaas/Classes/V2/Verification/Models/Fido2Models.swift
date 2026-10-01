//
//  Fido2Models.swift
//  Cidaas
//
//  FIDO2 / passkey request & response models matching verification-actions-srv
//  and verification-srv (`fido2_entity`, `fido2_client_response`).
//

import Foundation

// MARK: - Server → client (initiation)

public class Fido2Entity: Codable {
    public init() {}

    public var type: String = ""
    public var fidoRequestId: String = ""
    public var server_challenge: Fido2ServerChallenge = Fido2ServerChallenge()

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.fidoRequestId = try container.decodeIfPresent(String.self, forKey: .fidoRequestId) ?? ""
        self.server_challenge = try container.decodeIfPresent(Fido2ServerChallenge.self, forKey: .server_challenge) ?? Fido2ServerChallenge()
    }
}

public class Fido2ServerChallenge: Codable {
    public init() {}

    public var challenge: String = ""
    public var attestation: String?
    public var rp: Fido2RpEntity?
    public var rpId: String?
    public var user: Fido2UserEntity?
    public var pubKeyCredParams: [Fido2PubKeyCredParam]?
    public var authenticatorSelection: Fido2AuthenticatorSelection?
    public var excludeCredentials: [Fido2CredentialDescriptor]?
    public var allowCredentials: [Fido2CredentialDescriptor]?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.challenge = try container.decodeIfPresent(String.self, forKey: .challenge) ?? ""
        self.attestation = try container.decodeIfPresent(String.self, forKey: .attestation)
        self.rp = try container.decodeIfPresent(Fido2RpEntity.self, forKey: .rp)
        self.rpId = try container.decodeIfPresent(String.self, forKey: .rpId)
        self.user = try container.decodeIfPresent(Fido2UserEntity.self, forKey: .user)
        self.pubKeyCredParams = try container.decodeIfPresent([Fido2PubKeyCredParam].self, forKey: .pubKeyCredParams)
        self.authenticatorSelection = try container.decodeIfPresent(Fido2AuthenticatorSelection.self, forKey: .authenticatorSelection)
        self.excludeCredentials = try container.decodeIfPresent([Fido2CredentialDescriptor].self, forKey: .excludeCredentials)
        self.allowCredentials = try container.decodeIfPresent([Fido2CredentialDescriptor].self, forKey: .allowCredentials)
    }

    public var relyingPartyId: String {
        if let id = rp?.id, !id.isEmpty { return id }
        return rpId ?? ""
    }
}

public class Fido2RpEntity: Codable {
    public init() {}
    public var id: String = ""
    public var name: String = ""
    public var origins: [String]?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.origins = try container.decodeIfPresent([String].self, forKey: .origins)
    }
}

public class Fido2UserEntity: Codable {
    public init() {}
    public var id: String = ""
    public var name: String = ""
    public var displayName: String = ""

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    }
}

public class Fido2PubKeyCredParam: Codable {
    public init() {}
    public var type: String = "public-key"
    public var alg: Int = -7

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "public-key"
        self.alg = try container.decodeIfPresent(Int.self, forKey: .alg) ?? -7
    }
}

public class Fido2AuthenticatorSelection: Codable {
    public init() {}
    public var requireResidentKey: Bool = false
    public var residentKey: String?
    public var userVerification: String?
    public var authenticatorAttachment: String?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requireResidentKey = try container.decodeIfPresent(Bool.self, forKey: .requireResidentKey) ?? false
        self.residentKey = try container.decodeIfPresent(String.self, forKey: .residentKey)
        self.userVerification = try container.decodeIfPresent(String.self, forKey: .userVerification)
        self.authenticatorAttachment = try container.decodeIfPresent(String.self, forKey: .authenticatorAttachment)
    }
}

public class Fido2CredentialDescriptor: Codable {
    public init() {}
    public var id: String = ""
    public var type: String = "public-key"
    public var transports: [String]?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "public-key"
        self.transports = try container.decodeIfPresent([String].self, forKey: .transports)
    }
}

// MARK: - Client → server (enroll / authenticate)

public class Fido2ClientResponse: Codable {
    public init() {}

    public var fidoRequestId: String = ""
    public var client_response: Fido2PublicKeyCredential = Fido2PublicKeyCredential()

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fidoRequestId = try container.decodeIfPresent(String.self, forKey: .fidoRequestId) ?? ""
        self.client_response = try container.decodeIfPresent(Fido2PublicKeyCredential.self, forKey: .client_response) ?? Fido2PublicKeyCredential()
    }
}

public class Fido2PublicKeyCredential: Codable {
    public init() {}

    public var id: String = ""
    public var rawId: String = ""
    public var type: String = "public-key"
    public var authenticatorAttachment: String = "platform"
    public var response: Fido2AuthenticatorResponse = Fido2AuthenticatorResponse()

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.rawId = try container.decodeIfPresent(String.self, forKey: .rawId) ?? ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "public-key"
        self.authenticatorAttachment = try container.decodeIfPresent(String.self, forKey: .authenticatorAttachment) ?? "platform"
        self.response = try container.decodeIfPresent(Fido2AuthenticatorResponse.self, forKey: .response) ?? Fido2AuthenticatorResponse()
    }
}

public class Fido2AuthenticatorResponse: Codable {
    public init() {}

    /// Enrolment (attestation)
    public var attestationObject: String?
    public var clientDataJSON: String = ""

    /// Authentication (assertion)
    public var authenticatorData: String?
    public var signature: String?
    public var userHandle: String?

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.attestationObject = try container.decodeIfPresent(String.self, forKey: .attestationObject)
        self.clientDataJSON = try container.decodeIfPresent(String.self, forKey: .clientDataJSON) ?? ""
        self.authenticatorData = try container.decodeIfPresent(String.self, forKey: .authenticatorData)
        self.signature = try container.decodeIfPresent(String.self, forKey: .signature)
        self.userHandle = try container.decodeIfPresent(String.self, forKey: .userHandle)
    }
}
