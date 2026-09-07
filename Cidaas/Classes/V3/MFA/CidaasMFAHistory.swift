//
//  CidaasMFAHistory.swift
//  Cidaas
//

import Foundation

extension Cidaas {

    /// MFA usage history and timeline.
    public func mfaHistory() -> CidaasMFAHistoryBuilder {
        CidaasMFAHistoryBuilder()
    }
}

public final class CidaasMFAHistoryBuilder {

    public init() {}

    /// MFA usage history (`POST /verification-actions-srv/mfa/history`).
    public func history(
        incomingData: MFAHistoryRequest,
        completion: @escaping (Result<MFAHistoryResponse>) -> Void
    ) {
        VerificationViewController.shared.getMFAHistoryList(incomingData: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }

    /// Timeline for a status id (`POST /verification-actions-srv/mfa/timeline`).
    public func timeline(
        incomingData: TimeLineRequest,
        completion: @escaping (Result<TimeLineDetailsResponse>) -> Void
    ) {
        VerificationViewController.shared.getTimeLineDetails(timeLineRequest: incomingData) { result in
            CidaasMFAHelpers.onMain { completion(result) }
        }
    }
}
