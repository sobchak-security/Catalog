import Foundation
import Testing

@testable import CatalogKit

@Suite("ManifestSigner")
struct ManifestSignerTests {

    // MARK: - Key generation

    @Test("generateKeyPair returns 32-byte private and public keys")
    func keygenSize() {
        let (priv, pub) = ManifestSigner.generateKeyPair()
        #expect(priv.count == 32)
        #expect(pub.count == 32)
    }

    @Test("generateKeyPair produces distinct keys each call")
    func keygenDistinct() {
        let (priv1, _) = ManifestSigner.generateKeyPair()
        let (priv2, _) = ManifestSigner.generateKeyPair()
        #expect(priv1 != priv2)
    }

    @Test("sign throws invalidKeyLength for non-32-byte private key")
    func signRejectsInvalidPrivateKeyLength() {
        let badPrivateKey = Data(repeating: 0xAB, count: 31)
        #expect(throws: SigningError.invalidKeyLength(expected: 32, actual: 31)) {
            _ = try ManifestSigner.sign(
                manifestData: makeUnsignedManifestData(),
                privateKeyData: badPrivateKey
            )
        }
    }

    // MARK: - Sign & verify round-trip

    @Test("sign then verify with matching key succeeds")
    func signThenVerifySucceeds() throws {
        let (privData, pubData) = ManifestSigner.generateKeyPair()
        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )
        // Must not throw.
        try ManifestSigner.verify(signedManifestData: signed, publicKeyData: pubData)
    }

    @Test("verify throws invalidSignature when public key does not match")
    func verifyFailsWrongKey() throws {
        let (privData, _)         = ManifestSigner.generateKeyPair()
        let (_, wrongPubData)     = ManifestSigner.generateKeyPair()

        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )

        #expect(throws: SigningError.invalidSignature) {
            try ManifestSigner.verify(signedManifestData: signed, publicKeyData: wrongPubData)
        }
    }

    @Test("verify throws invalidKeyLength for non-32-byte public key")
    func verifyRejectsInvalidPublicKeyLength() throws {
        let (privData, _) = ManifestSigner.generateKeyPair()
        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )

        let badPublicKey = Data(repeating: 0xCD, count: 30)
        #expect(throws: SigningError.invalidKeyLength(expected: 32, actual: 30)) {
            try ManifestSigner.verify(signedManifestData: signed, publicKeyData: badPublicKey)
        }
    }

    @Test("verify throws invalidSignature when manifest is tampered")
    func verifyFailsTamperedManifest() throws {
        let (privData, pubData) = ManifestSigner.generateKeyPair()
        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )

        // Tamper: increment modelCount.
        var root = try jsonDictionary(from: signed)
        root["modelCount"] = 999
        let tampered = try JSONSerialization.data(withJSONObject: root)

        #expect(throws: SigningError.invalidSignature) {
            try ManifestSigner.verify(signedManifestData: tampered, publicKeyData: pubData)
        }
    }

    @Test("verify throws missingOrMalformedSignature when signature field absent")
    func verifyFailsMissingSignature() throws {
        let (_, pubData) = ManifestSigner.generateKeyPair()
        // Build a manifest without a signature field.
        let json: [String: Any] = [
            "schemaVersion": 1,
            "revision": ["number": 1, "publishedAt": "2026-04-26T00:00:00Z"],
            "modelCount": 0,
            "totalBytes": 0,
            "entries": [],
            "signerKeyID": "test-key-2026",
            // "signature" deliberately omitted
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: SigningError.missingOrMalformedSignature) {
            try ManifestSigner.verify(signedManifestData: data, publicKeyData: pubData)
        }
    }

    // MARK: - Signature field format

    @Test("signed manifest has 'ed25519-' prefixed signature field")
    func signatureFieldPrefix() throws {
        let (privData, _) = ManifestSigner.generateKeyPair()
        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )

        let root = try jsonDictionary(from: signed)
        let sigField = root["signature"] as? String
        #expect(sigField?.hasPrefix("ed25519-") == true)
    }

    @Test("signature base64url part contains no '+', '/', or '='")
    func signatureBase64URLEncoded() throws {
        let (privData, _) = ManifestSigner.generateKeyPair()
        let signed = try ManifestSigner.sign(
            manifestData: makeUnsignedManifestData(),
            privateKeyData: privData
        )

        let root = try jsonDictionary(from: signed)
        let signature = try #require(root["signature"] as? String)
        let sigField = signature.dropFirst("ed25519-".count)
        #expect(!sigField.contains("+"))
        #expect(!sigField.contains("/"))
        #expect(!sigField.contains("="))
    }

    // MARK: - Signing input canonicalisation

    @Test("sign uses canonical bytes (key order in source does not affect signature)")
    func signCanonical() throws {
        let (privData, pubData) = ManifestSigner.generateKeyPair()

        // Two logically identical manifests with different key ordering in their JSON bytes.
        let manifestA = makeUnsignedManifestData(keyOrder: .sorted)
        let manifestB = makeUnsignedManifestData(keyOrder: .reversed)

        let signedA = try ManifestSigner.sign(manifestData: manifestA, privateKeyData: privData)
        // The signature from manifest A must verify against manifest B (same logical content).
        let rootA = try jsonDictionary(from: signedA)
        let sigValue = try #require(rootA["signature"] as? String)

        // Inject sigValue into manifestB and verify.
        var rootB = try jsonDictionary(from: manifestB)
        rootB["signature"] = sigValue
        let signedB = try JSONSerialization.data(withJSONObject: rootB)
        // Must not throw — same canonical bytes → same signature.
        try ManifestSigner.verify(signedManifestData: signedB, publicKeyData: pubData)
    }

    // MARK: - base64url helpers

    @Test("base64url encoding avoids '+', '/', '=' characters")
    func base64urlNoSpecialChars() {
        let data = Data([0xFB, 0xFF, 0xFE, 0x01, 0x02])
        let encoded = data.base64URLEncodedString()
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test("base64url round-trip decodes to original bytes")
    func base64urlRoundTrip() {
        let original = Data((0..<32).map { UInt8($0) })
        let encoded = original.base64URLEncodedString()
        let decoded = Data(base64URLEncoded: encoded)
        #expect(decoded == original)
    }

    @Test("Data(base64URLEncoded:) accepts strings without padding")
    func base64urlNoPadding() {
        let data = Data([0x01, 0x02, 0x03])
        let withoutPadding = data.base64URLEncodedString()
        let decoded = Data(base64URLEncoded: withoutPadding)
        #expect(decoded == data)
    }

    // MARK: - Key file I/O

    @Test("loadPublicKeyData round-trips through a temp file")
    func publicKeyFileRoundTrip() throws {
        let (_, pubData) = ManifestSigner.generateKeyPair()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).pub")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        try Data(pubData.base64EncodedString().utf8).write(to: tmpURL, options: .atomic)
        let loaded = try ManifestSigner.loadPublicKeyData(fromFile: tmpURL.path)
        #expect(loaded == pubData)
    }

    @Test("loadPrivateKeyData throws invalidKeyEncoding for garbage content")
    func loadPrivateKeyBadEncoding() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).key")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let badData = try #require("not-base64!!@@##".data(using: .utf8))
        try badData.write(to: tmpURL, options: .atomic)

        #expect(throws: SigningError.invalidKeyEncoding) {
            try ManifestSigner.loadPrivateKeyData(fromFile: tmpURL.path)
        }
    }

    @Test("loadPrivateKeyData throws invalidKeyLength for valid base64 with wrong byte count")
    func loadPrivateKeyBadLength() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).key")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let tenBytes = Data(repeating: 0x01, count: 10).base64EncodedString()
        try Data(tenBytes.utf8).write(to: tmpURL, options: .atomic)

        #expect(throws: SigningError.invalidKeyLength(expected: 32, actual: 10)) {
            try ManifestSigner.loadPrivateKeyData(fromFile: tmpURL.path)
        }
    }

    // MARK: - Helpers

    private enum KeyOrder { case sorted, reversed }

    private func jsonDictionary(from data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }

    private func makeUnsignedManifestData(keyOrder: KeyOrder = .sorted) -> Data {
        let dict: [String: Any] = [
            "schemaVersion": 1,
            "revision": ["number": 1, "publishedAt": "2026-04-26T00:00:00Z"],
            "modelCount": 0,
            "totalBytes": 0,
            "entries": [],
            "signerKeyID": "test-key-2026",
            "signature": "",
        ]
        let opts: JSONSerialization.WritingOptions = keyOrder == .sorted ? [.sortedKeys] : []
        return (try? JSONSerialization.data(withJSONObject: dict, options: opts)) ?? Data()
    }
}
