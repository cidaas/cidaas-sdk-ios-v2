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

    /// Lists enrolled verification methods on this or a linked device (`POST /verification-actions-srv/setup/devices`).
    /// Set `linked_device_id` on the request to query another device.
    public func enrolledMethods(
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
