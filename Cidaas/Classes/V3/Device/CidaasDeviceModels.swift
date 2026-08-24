//
//  CidaasDeviceModels.swift
//  Cidaas
//

import Foundation

/// Attestation provider from the device registration initiate response (verification options).
public enum DeviceRegistrationProvider: Equatable {
    /// Apple App Attest.
    case apple
    /// Firebase App Check.
    case firebase
    /// Empty initiate `provider`; verification options have no AppAttest.
    case none
    case unknown(String)

    init(apiValue: String?) {
        let normalized = (apiValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "apple":
            self = .apple
        case "firebase":
            self = .firebase
        case "":
            self = .none
        default:
            self = .unknown(normalized)
        }
    }
}

/// Challenge material returned by initiate and consumed by verify.
public struct DeviceRegistrationInitiateResult {
    public let sessionId: String
    public let nonce: String
    public let provider: DeviceRegistrationProvider

    public init(sessionId: String, nonce: String, provider: DeviceRegistrationProvider) {
        self.sessionId = sessionId
        self.nonce = nonce
        self.provider = provider
    }
}

/// Initiate API response envelope.
final class DeviceRegistrationInitiateAPIResponse: Codable {
    var success: Bool = false
    var status: Int32 = 0
    var data: DeviceRegistrationInitiateDataResponse?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case data
    }
}

/// Initiate API `data` payload.
struct DeviceRegistrationInitiateDataResponse: Codable {
    let session_id: String
    let nonce: String
    let provider: String?
}

/// Successful registration result.
public struct DeviceRegistrationVerifyResult {
    public let deviceId: String

    public init(deviceId: String) {
        self.deviceId = deviceId
    }
}

/// Verify API response envelope.
final class DeviceRegistrationVerifyAPIResponse: Codable {
    var success: Bool = false
    var status: Int32 = 0
    var data: DeviceRegistrationVerifyDataResponse?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case data
    }
}

/// Verify API `data` payload.
struct DeviceRegistrationVerifyDataResponse: Codable {
    let device_id: String
}
