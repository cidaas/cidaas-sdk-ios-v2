import XCTest
@testable import Cidaas

final class SimulatorKeyGenerationTests: XCTestCase {

    func testDeviceRegistrationMaterialGeneratesOnSimulator() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Secure Enclave path is covered on device; this asserts Simulator software keys")
        #else
        let material = try CidaasHTTPProof.loadDeviceRegistrationMaterial()
        XCTAssertFalse(material.dpopThumbprint.isEmpty)
        XCTAssertFalse(material.biometricThumbprint.isEmpty)
        XCTAssertFalse(material.biometricPublicKeyDER.isEmpty)
        #endif
    }

    @available(iOS 14.0, *)
    func testBiometricProofEnsureKeyOnSimulator() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Secure Enclave path is covered on device; this asserts Simulator software keys")
        #else
        BiometricProofSigner.deleteKey()
        XCTAssertNoThrow(try BiometricProofSigner.ensureKey())
        #endif
    }
}
