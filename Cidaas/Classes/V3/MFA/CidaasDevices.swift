//
//  CidaasDevices.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Linked devices, enrolled methods, pending authentications, and unlink.
    public func devices() -> CidaasDevicesBuilder {
        CidaasDevicesBuilder()
    }
}

public final class CidaasDevicesBuilder {

    public init() {}

    /// Lists linked devices for the user (`POST /verification-actions-srv/devices`).
    public func linkedDevices(
        incomingData: MFAConfiguredDeviceListRequest,
        completion: @escaping (Result<MFAConfiguredDeviceListResponse>) -> Void
    ) {
        VerificationViewController.shared.getMFAConfiguredDeviceList(
            mfaConfiguredDeviceListRequest: incomingData
        ) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }

    /// Configured MFA methods for the user on this device (`sub` + current `device_id` / `push_id`).
    public func configurations(sub: String, completion: @escaping (Result<MFAListResponse>) -> Void) {
        let resolvedSub = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedSub.isEmpty else {
            MFA.fail("sub is required", completion: completion)
            return
        }
        let req = MFAListRequest()
        req.sub = resolvedSub
        req.device_id = MFA.deviceId()
        req.push_id = MFA.pushId()
        VerificationViewController.shared.getConfiguredList(incomingData: req) { result in
            MFA.onMain { completion(result) }
        }
    }

    /// Lists enrolled verification methods on this or a linked device (`POST /verification-actions-srv/setup/devices`).
    /// Set `linked_device_id` on the request to query another device.
    public func configurations(
        incomingData: MFAListRequest,
        completion: @escaping (Result<MFAListResponse>) -> Void
    ) {
        VerificationViewController.shared.getDeviceConfiguredList(mfaListRequest: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }

    /// Lists pending initiated push authentications (`POST /verification-actions-srv/setup/devices/notifications`).
    public func pendingAuthentications(
        incomingData: PendingNotificationRequest,
        completion: @escaping (Result<PendingNotificationResponse>) -> Void
    ) {
        VerificationViewController.shared.getPendingNotificationList(incomingData: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }

    /// Unlinks a device (`DELETE /verification-actions-srv/devices`).
    public func unlinkDevice(
        incomingData: DeleteDeviceRequest,
        completion: @escaping (Result<DeleteResponse>) -> Void
    ) {
        VerificationViewController.shared.deleteDevice(deleteRequest: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }
}
