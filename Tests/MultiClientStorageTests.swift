import XCTest
@testable import Cidaas

final class MultiClientStorageTests: XCTestCase {

    var db: DBHelper!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "cidaas.tests.multiclient.\(UUID().uuidString)"
        db = DBHelper()
        db.userDefaults = UserDefaults(suiteName: suiteName)!
        db.userDefaults.removePersistentDomain(forName: suiteName)
        db.setTokenStorage(.userDefaults)
    }

    override func tearDown() {
        db.userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSameSubIsolatedAcrossClients() {
        let sub = "user-sub-1"
        setActive(domain: "https://tenant.example", clientId: "client-a")
        db.setAccessToken(accessTokenModel: token(sub: sub, accessToken: "token-a"))

        setActive(domain: "https://tenant.example", clientId: "client-b")
        db.setAccessToken(accessTokenModel: token(sub: sub, accessToken: "token-b"))
        XCTAssertEqual(db.getAccessToken(key: sub).access_token, "token-b")

        setActive(domain: "https://tenant.example", clientId: "client-a")
        XCTAssertEqual(db.getAccessToken(key: sub).access_token, "token-a")
    }

    func testSetAccessTokenWithoutClientDoesNotWriteLegacyKey() {
        let sub = "orphan-sub"
        db.setAccessToken(accessTokenModel: token(sub: sub, accessToken: "should-not-save"))
        XCTAssertNil(db.userDefaults.object(forKey: db.legacyAccessTokenKey(sub: sub)))
        XCTAssertTrue(db.getAccessToken(key: sub).access_token.isEmpty)
    }

    func testDpopAndDeviceRegDoNotLeakAcrossClients() {
        setActive(domain: "https://tenant.example", clientId: "client-a")
        db.setEnableDpop(enableDpop: true)
        db.setDpopBound(true)
        db.setDeviceRegistrationCompleted(true)

        setActive(domain: "https://tenant.example", clientId: "client-b")
        XCTAssertFalse(db.getEnableDpop())
        XCTAssertFalse(db.getDpopBound())
        XCTAssertFalse(db.getDeviceRegistrationCompleted())

        setActive(domain: "https://tenant.example", clientId: "client-a")
        XCTAssertTrue(db.getEnableDpop())
        XCTAssertTrue(db.getDpopBound())
        XCTAssertTrue(db.getDeviceRegistrationCompleted())
    }

    func testMigrationCopiesLegacyTokenToNamespacedKey() {
        let sub = "legacy-sub"
        let legacy = db.legacyAccessTokenKey(sub: sub)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(token(sub: sub, accessToken: "legacy-token"))
        db.userDefaults.set(String(data: data, encoding: .utf8), forKey: legacy)

        setActive(domain: "https://tenant.example", clientId: "client-a")

        let stored = db.getAccessToken(key: sub)
        XCTAssertEqual(stored.access_token, "legacy-token")
        XCTAssertEqual(stored.sub, sub)

        let namespaced = db.namespacedAccessTokenKey(sub: sub, tenant: "https://tenant.example", clientId: "client-a")
        XCTAssertNotNil(db.userDefaults.object(forKey: namespaced))
        XCTAssertEqual(db.userDefaults.integer(forKey: DBHelper.migrationVersionKey), DBHelper.currentMigrationVersion)
    }

    func testPropertyRegistryKeepsOtherClientConfig() {
        setActive(domain: "https://tenant.example", clientId: "client-a", extra: ["RedirectURL": "app://a"])
        setActive(domain: "https://tenant.example", clientId: "client-b", extra: ["RedirectURL": "app://b"])

        XCTAssertEqual(db.getPropertyFile()?["ClientId"], "client-b")
        let registryA = db.propertyRegistryKey(tenant: "https://tenant.example", clientId: "client-a")
        let savedA = db.userDefaults.object(forKey: registryA) as? [String: String]
        XCTAssertEqual(savedA?["RedirectURL"], "app://a")
        XCTAssertEqual(savedA?["ClientId"], "client-a")
    }

    func testInstanceSuffixDiffersPerClient() {
        let a = db.instanceSuffix(tenant: "https://tenant.example", clientId: "client-a")
        let b = db.instanceSuffix(tenant: "https://tenant.example", clientId: "client-b")
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.contains("client-a"))
        XCTAssertTrue(b.contains("client-b"))
    }

    func testDualReadFallsBackToLegacyKeyBeforeMigrationCompletes() {
        let sub = "dual-sub"
        let encoder = JSONEncoder()
        let data = try! encoder.encode(token(sub: sub, accessToken: "from-legacy"))
        db.userDefaults.set(String(data: data, encoding: .utf8), forKey: db.legacyAccessTokenKey(sub: sub))
        db.userDefaults.set(DBHelper.currentMigrationVersion, forKey: DBHelper.migrationVersionKey)

        setActive(domain: "https://tenant.example", clientId: "client-a")
        XCTAssertEqual(db.getAccessToken(key: sub).access_token, "from-legacy")
    }

    private func setActive(domain: String, clientId: String, extra: [String: String] = [:]) {
        var props = extra
        props["DomainURL"] = domain
        props["ClientId"] = clientId
        db.setPropertyFile(properties: props)
    }

    private func token(sub: String, accessToken: String) -> AccessTokenModel {
        let model = AccessTokenModel()
        model.sub = sub
        model.access_token = accessToken
        model.refresh_token = "refresh"
        model.expires_in = 3600
        return model
    }
}
