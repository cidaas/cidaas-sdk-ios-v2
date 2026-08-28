import XCTest
@testable import Cidaas

final class SDKDeviceIdResolverTests: XCTestCase {

    func testPersistNormalizesToUppercase() {
        let mixed = "aBcDeF12-3456-7890-abcd-ef1234567890"
        SDKDeviceIdResolver.persist(mixed)
        let resolved = SDKDeviceIdResolver.resolve()
        XCTAssertEqual(resolved, mixed.uppercased())
        XCTAssertFalse(resolved.contains(where: { $0.isLowercase }))
    }

    func testResolveMigratesStoredLowercaseToUppercase() {
        var info = DBHelper.shared.getDeviceInfo()
        let lower = "abcdef12-3456-7890-abcd-ef1234567890"
        info.deviceId = lower
        DBHelper.shared.setDeviceInfo(deviceInfo: info)

        let resolved = SDKDeviceIdResolver.resolve()
        XCTAssertEqual(resolved, lower.uppercased())
    }
}
