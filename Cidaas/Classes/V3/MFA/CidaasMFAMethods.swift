//
//  CidaasMFAMethods.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Delete enrolled verification methods on a device.
    public func mfaMethods() -> CidaasMFAMethodsBuilder {
        CidaasMFAMethodsBuilder()
    }
}

public final class CidaasMFAMethodsBuilder {

    public init() {}

    /// Removes one enrolled method (`DELETE /verification-actions-srv/setup/devices/{method}/{sub}`).
    public func delete(
        incomingData: DeleteRequest,
        completion: @escaping (Result<DeleteResponse>) -> Void
    ) {
        VerificationViewController.shared.delete(incomingData: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }

    /// Removes all enrolled methods for the request `device_id`
    /// (`DELETE /verification-actions-srv/setup/devices/{deviceId}`).
    public func deleteAll(
        incomingData: DeleteRequest,
        completion: @escaping (Result<DeleteResponse>) -> Void
    ) {
        VerificationViewController.shared.deleteAll(incomingData: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }
}
