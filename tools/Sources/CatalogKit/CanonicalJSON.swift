import Crypto
import Foundation

// MARK: - CanonicalJSON

/// Deterministic JSON serialisation utilities used for content-hashing and
/// Ed25519 signing.  The canonical form is defined as:
///
/// * Object keys sorted lexicographically at every depth.
/// * Compact output (no extra whitespace).
/// * Forward slashes not escaped (avoids `\/` noise in URLs).
/// * Arrays maintain their original element order.
///
/// These rules are a subset of RFC 8785 (JSON Canonicalization Scheme) and are
/// sufficient for our use case; a full JCS implementation is not required.
public enum CanonicalJSON {

    /// Re-serialises ``input`` JSON bytes with all object keys sorted
    /// lexicographically at every depth.
    public static func canonicalise(_ input: Data) throws -> Data {
        let obj = try JSONSerialization.jsonObject(with: input, options: [])
        return try serialize(obj)
    }

    /// Serialises any Foundation JSON-compatible object to canonical bytes.
    public static func serialize(_ jsonObject: Any) throws -> Data {
        let options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        return try JSONSerialization.data(withJSONObject: jsonObject, options: options)
    }

    /// Returns the SHA-256 content hash of the canonical form of ``input``,
    /// formatted as ``"sha256-<standard-base64>"`` (44 characters after the prefix).
    public static func contentHash(of input: Data) throws -> String {
        let canonical = try canonicalise(input)
        return sha256HashString(of: canonical)
    }

    /// Canonicalises ``input`` and computes its SHA-256 hash in a single pass.
    /// - Returns: `(canonical bytes, "sha256-<base64>" string)`
    public static func canonicaliseAndHash(_ input: Data) throws -> (canonical: Data, hash: String) {
        let canonical = try canonicalise(input)
        return (canonical, sha256HashString(of: canonical))
    }

    // MARK: - Internal helpers

    static func sha256HashString(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return "sha256-\(Data(digest).base64EncodedString())"
    }
}
