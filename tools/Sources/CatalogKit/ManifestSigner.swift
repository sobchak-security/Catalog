import Crypto
import Foundation

// MARK: - ManifestSigner

/// Ed25519 sign and verify utilities for catalog manifests.
///
/// **Signing algorithm:**
/// 1. Parse the manifest JSON.
/// 2. Set the ``signature`` field to the empty string ``""``.
/// 3. Produce canonical JSON bytes (sorted keys, compact, §CanonicalJSON).
/// 4. Sign those bytes with the Ed25519 private key.
/// 5. Encode the raw 64-byte signature as base64url (no padding).
/// 6. Write ``"ed25519-<base64url>"`` back into the ``signature`` field.
/// 7. Serialise the final manifest as sorted, pretty-printed JSON.
///
/// **Key storage:**
/// Both the private and public keys are stored as standard base64 of their
/// 32-byte raw Ed25519 representations (44 characters each including padding).
/// The private key may also be supplied via the ``ED25519_PRIVATE_KEY``
/// environment variable in CI.
public enum ManifestSigner {

    private static let ed25519KeyLength = 32
    private static let ed25519SignatureLength = 64

    // MARK: - Sign

    /// Signs ``manifestData`` (unsigned manifest JSON with ``signature == ""``)
    /// using the 32-byte Ed25519 private key seed in ``privateKeyData``.
    ///
    /// - Returns: New JSON data with ``signature`` filled in.
    public static func sign(manifestData: Data, privateKeyData: Data) throws -> Data {
        guard privateKeyData.count == ed25519KeyLength else {
            throw SigningError.invalidKeyLength(expected: ed25519KeyLength, actual: privateKeyData.count)
        }

        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let signingBytes = try canonicalisedForSigning(manifestData)
        let rawSig = try key.signature(for: signingBytes)
        let sigValue = "ed25519-\(Data(rawSig).base64URLEncodedString())"
        return try setField("signature", to: sigValue, in: manifestData)
    }

    // MARK: - Verify

    /// Verifies the Ed25519 signature on a signed manifest.
    ///
    /// - Throws: ``SigningError`` if the signature is absent, malformed, or invalid.
    public static func verify(signedManifestData: Data, publicKeyData: Data) throws {
        guard publicKeyData.count == ed25519KeyLength else {
            throw SigningError.invalidKeyLength(expected: ed25519KeyLength, actual: publicKeyData.count)
        }

        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)

        guard let root = (try? JSONSerialization.jsonObject(with: signedManifestData)) as? [String: Any],
              let sigString = root["signature"] as? String,
              sigString.hasPrefix("ed25519-") else {
            throw SigningError.missingOrMalformedSignature
        }

        let b64url = String(sigString.dropFirst("ed25519-".count))
        guard let rawSig = Data(base64URLEncoded: b64url) else {
            throw SigningError.missingOrMalformedSignature
        }
        guard rawSig.count == ed25519SignatureLength else {
            throw SigningError.missingOrMalformedSignature
        }

        let signingBytes = try canonicalisedForSigning(signedManifestData)
        guard key.isValidSignature(rawSig, for: signingBytes) else {
            throw SigningError.invalidSignature
        }
    }

    // MARK: - Key generation

    /// Generates a fresh Ed25519 key pair.
    /// - Returns: `(rawPrivateKey 32 B, rawPublicKey 32 B)`
    public static func generateKeyPair() -> (privateKey: Data, publicKey: Data) {
        let key = Curve25519.Signing.PrivateKey()
        return (key.rawRepresentation, key.publicKey.rawRepresentation)
    }

    // MARK: - Key loading

    /// Reads a base64-encoded 32-byte Ed25519 private key from a file.
    public static func loadPrivateKeyData(fromFile path: String) throws -> Data {
        try loadBase64KeyBytes(fromFile: path)
    }

    /// Reads a base64-encoded 32-byte Ed25519 public key from a file.
    public static func loadPublicKeyData(fromFile path: String) throws -> Data {
        try loadBase64KeyBytes(fromFile: path)
    }

    /// Reads the private key from the ``ED25519_PRIVATE_KEY`` environment variable.
    public static func privateKeyDataFromEnv() throws -> Data {
        guard let value = ProcessInfo.processInfo.environment["ED25519_PRIVATE_KEY"] else {
            throw SigningError.envVarMissing("ED25519_PRIVATE_KEY")
        }
        let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: stripped) else {
            throw SigningError.invalidKeyEncoding
        }
        guard raw.count == ed25519KeyLength else {
            throw SigningError.invalidKeyLength(expected: ed25519KeyLength, actual: raw.count)
        }
        return raw
    }

    // MARK: - Private helpers

    private static func loadBase64KeyBytes(fromFile path: String) throws -> Data {
        let content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: content) else {
            throw SigningError.invalidKeyEncoding
        }
        guard raw.count == ed25519KeyLength else {
            throw SigningError.invalidKeyLength(expected: ed25519KeyLength, actual: raw.count)
        }
        return raw
    }

    private static func canonicalisedForSigning(_ manifestData: Data) throws -> Data {
        guard var root = (try? JSONSerialization.jsonObject(with: manifestData)) as? [String: Any] else {
            throw SigningError.invalidManifestJSON
        }
        root["signature"] = ""
        return try CanonicalJSON.serialize(root)
    }

    private static func setField(_ key: String, to value: String, in data: Data) throws -> Data {
        guard var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw SigningError.invalidManifestJSON
        }
        root[key] = value
        let opts: JSONSerialization.WritingOptions = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try JSONSerialization.data(withJSONObject: root, options: opts)
    }
}

// MARK: - SigningError

public enum SigningError: Error, CustomStringConvertible, Equatable {
    case invalidManifestJSON
    case missingOrMalformedSignature
    case invalidSignature
    case invalidKeyEncoding
    case invalidKeyLength(expected: Int, actual: Int)
    case envVarMissing(String)

    public var description: String {
        switch self {
        case .invalidManifestJSON:
            return "Manifest data is not valid JSON"
        case .missingOrMalformedSignature:
            return "Signature field is missing or malformed"
        case .invalidSignature:
            return "Signature verification failed"
        case .invalidKeyEncoding:
            return "Key is not valid base64"
        case .invalidKeyLength(let expected, let actual):
            return "Key length must be \(expected) bytes, got \(actual)"
        case .envVarMissing(let name):
            return "Required environment variable '\(name)' is not set"
        }
    }
}

// MARK: - Data base64url helpers

extension Data {
    /// Encodes to base64url (RFC 4648 §5) without padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Initialises from a base64url string (with or without ``=`` padding).
    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder != 0 {
            s += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: s)
    }
}
