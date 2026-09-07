//
//  CidaasFCM.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// Push token (FCM) update for this installation.
    public func fcm() -> CidaasFCMBuilder {
        CidaasFCMBuilder()
    }
}

public final class CidaasFCMBuilder {

    public init() {}

    /// Updates the push token on the verification backend (`PUT /verification-actions-srv/setup/devices`).
    /// On success, also stores `push_id` locally for later SDK calls.
    public func updateToken(
        incomingData: UpdateFCMRequest,
        completion: @escaping (Result<UpdateFCMResponse>) -> Void
    ) {
        VerificationViewController.shared.updateFCMToken(updateFCMRequest: incomingData) { result in
            if case .success = result, !incomingData.push_id.isEmpty {
                DBHelper.shared.setFCM(fcmToken: incomingData.push_id)
            }
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }
}
