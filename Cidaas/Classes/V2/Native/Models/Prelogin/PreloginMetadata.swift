//
//  PreloginMetadata.swift
//  Cidaas
//

import Foundation

public class PreloginMetadataResponse: Codable {
    public var success: Bool = false
    public var status: Int32 = 400
    public var data: PreloginMetadataData = PreloginMetadataData()

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.status = try container.decodeIfPresent(Int32.self, forKey: .status) ?? 400
        self.data = try container.decodeIfPresent(PreloginMetadataData.self, forKey: .data)
            ?? PreloginMetadataData()
    }
}

public class PreloginMetadataData: Codable {
    public var logged_in: Bool = false
    public var validation_type: String = ""
    public var meta_data: PreloginMetaData = PreloginMetaData()
    public var used: Bool = false

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.logged_in = try container.decodeIfPresent(Bool.self, forKey: .logged_in) ?? false
        self.validation_type = try container.decodeIfPresent(String.self, forKey: .validation_type) ?? ""
        self.meta_data = try container.decodeIfPresent(PreloginMetaData.self, forKey: .meta_data)
            ?? PreloginMetaData()
        self.used = try container.decodeIfPresent(Bool.self, forKey: .used) ?? false
    }
}

public class PreloginMetaData: Codable {
    public var amr_values: [String] = []
    public var acr_values: String = ""
    public var last_auth_time: String = ""
    public var terminal_error: String = ""
    public var userConfiguredMethods: [PreloginConfiguredMethod] = []

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.amr_values = try container.decodeIfPresent([String].self, forKey: .amr_values) ?? []
        self.acr_values = try container.decodeIfPresent(String.self, forKey: .acr_values) ?? ""
        self.last_auth_time = try container.decodeIfPresent(String.self, forKey: .last_auth_time) ?? ""
        self.terminal_error = try container.decodeIfPresent(String.self, forKey: .terminal_error) ?? ""
        self.userConfiguredMethods = try container.decodeIfPresent(
            [PreloginConfiguredMethod].self,
            forKey: .userConfiguredMethods
        ) ?? []
    }
}

public class PreloginConfiguredMethod: Codable {
    public var type: String = ""
    public var mediums: [PreloginConfiguredMedium] = []

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.mediums = try container.decodeIfPresent([PreloginConfiguredMedium].self, forKey: .mediums) ?? []
    }
}

public class PreloginConfiguredMedium: Codable {
    public var id: String = ""
    public var key_name: String = ""

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.key_name = try container.decodeIfPresent(String.self, forKey: .key_name) ?? ""
    }
}
