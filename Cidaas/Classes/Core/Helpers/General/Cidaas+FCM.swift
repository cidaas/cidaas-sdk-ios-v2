//
//  Cidaas+FCM.swift
//  Cidaas
//

import Foundation

extension Cidaas {
    /// Registers the FCM push token with cidaas verification services.
    public func registerFCM(_ token: String?) {
        let trimmed = (token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        CidaasVerification.shared.updateFCM(push_id: trimmed)
        DBHelper.shared.setFCM(fcmToken: trimmed)
    }
}
