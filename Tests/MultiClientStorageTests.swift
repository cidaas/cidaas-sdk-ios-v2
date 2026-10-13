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
        XCTAssertNil(db.userDefaults.object(forKey: legacy), "legacy flat key must be removed after migration")
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

    func testActiveClientDoesNotFallBackToLegacyToken() {
        let sub = "dual-sub"
        let encoder = JSONEncoder()
        let data = try! encoder.encode(token(sub: sub, accessToken: "from-legacy"))
        db.userDefaults.set(String(data: data, encoding: .utf8), forKey: db.legacyAccessTokenKey(sub: sub))
        db.userDefaults.set(DBHelper.currentMigrationVersion, forKey: DBHelper.migrationVersionKey)

        // Migration already marked complete — setPropertyFile will not re-copy.
        // With an active client, legacy must not be used (prevents cross-client leak).
        let props = ["DomainURL": "https://tenant.example", "ClientId": "client-a"]
        db.userDefaults.set(props, forKey: "OAuthProperty")

        XCTAssertTrue(db.getAccessToken(key: sub).access_token.isEmpty)
    }

    func testLegacyTokenDoesNotLeakToSecondClientAfterMigration() {
        let sub = "shared-sub"
        let encoder = JSONEncoder()
        let data = try! encoder.encode(token(sub: sub, accessToken: "legacy-only"))
        db.userDefaults.set(String(data: data, encoding: .utf8), forKey: db.legacyAccessTokenKey(sub: sub))

        setActive(domain: "https://tenant.example", clientId: "client-a")
        XCTAssertEqual(db.getAccessToken(key: sub).access_token, "legacy-only")

        setActive(domain: "https://tenant.example", clientId: "client-b")
        XCTAssertTrue(
            db.getAccessToken(key: sub).access_token.isEmpty,
            "client-b must not see client-a's migrated/legacy session"
        )
    }

    func testInstanceFlagsDoNotFallBackToGlobalLegacy() {
        // Migration already done — globals must not apply to an active client without instance keys.
        db.userDefaults.set(DBHelper.currentMigrationVersion, forKey: DBHelper.migrationVersionKey)
        db.userDefaults.set(true, forKey: "OAuthEnableDpop")
        db.userDefaults.set(true, forKey: "com.cidaas.sdk.dpop.bound")
        db.userDefaults.set(true, forKey: "OAuthDeviceRegistrationCompleted")

        setActive(domain: "https://tenant.example", clientId: "client-b")
        XCTAssertFalse(db.getEnableDpop())
        XCTAssertFalse(db.getDpopBound())
        XCTAssertFalse(db.getDeviceRegistrationCompleted())
    }

    func testSetURLConfigSourceTakesPrecedenceFlag() {
        XCTAssertFalse(db.prefersSetURLConfig())
        db.setConfigSource(.setURL)
        XCTAssertTrue(db.prefersSetURLConfig())
        XCTAssertEqual(db.getConfigSource(), .setURL)

        db.setConfigSource(.plist)
        XCTAssertFalse(db.prefersSetURLConfig())
        XCTAssertEqual(db.getConfigSource(), .plist)
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
