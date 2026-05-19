//
//  CidaasDeviceModels.swift
//  Cidaas
//

import Foundation

/// Session and nonce returned from the initiate step (used internally between steps).
public struct DeviceRegistrationInitiateResult {
    public let sessionId: String
    public let nonce: String

    public init(sessionId: String, nonce: String) {
        self.sessionId = sessionId
        self.nonce = nonce
    }
}

/// JSON envelope for the initiate API response.
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

/// `data` object from the initiate response.
struct DeviceRegistrationInitiateDataResponse: Codable {
    let session_id: String
    let nonce: String
}

/// Registered device id returned to the app on success.
public struct DeviceRegistrationVerifyResult {
    public let deviceId: String

    public init(deviceId: String) {
        self.deviceId = deviceId
    }
}

/// JSON envelope for the verify API response.
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

/// `data` object from the verify response.
struct DeviceRegistrationVerifyDataResponse: Codable {
    let device_id: String
}
