import Foundation
import Testing

@testable import CatalogKit

@Suite("CanonicalJSON")
struct CanonicalJSONTests {

    // MARK: - Key sorting

    @Test("single-level object keys are sorted")
    func singleLevelSortedKeys() throws {
        let input = try utf8Data(#"{"z":1,"a":2,"m":3}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"a":2,"m":3,"z":1}"#)
    }

    @Test("nested object keys are sorted at every depth")
    func nestedSortedKeys() throws {
        let input = try utf8Data(#"{"b":{"z":1,"a":2},"a":3}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"a":3,"b":{"a":2,"z":1}}"#)
    }

    @Test("array element order is preserved")
    func arrayOrderPreserved() throws {
        let input = try utf8Data(#"{"arr":[3,1,2]}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"arr":[3,1,2]}"#)
    }

    @Test("objects inside arrays have sorted keys")
    func objectsInsideArraysSorted() throws {
        let input = try utf8Data(#"{"list":[{"z":1,"a":2},{"y":3,"b":4}]}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"list":[{"a":2,"z":1},{"b":4,"y":3}]}"#)
    }

    // MARK: - Determinism

    @Test("same logical JSON with different key order produces identical output")
    func deterministicAcrossKeyOrders() throws {
        let a = try utf8Data(#"{"z":99,"a":1,"m":"hello"}"#)
        let b = try utf8Data(#"{"m":"hello","z":99,"a":1}"#)
        let ca = try CanonicalJSON.canonicalise(a)
        let cb = try CanonicalJSON.canonicalise(b)
        #expect(ca == cb)
    }

    @Test("double-canonicalise is idempotent")
    func idempotent() throws {
        let input = try utf8Data(#"{"z":1,"a":{"y":2,"b":3}}"#)
        let once  = try CanonicalJSON.canonicalise(input)
        let twice = try CanonicalJSON.canonicalise(once)
        #expect(once == twice)
    }

    // MARK: - Number handling

    @Test("integer values are preserved")
    func integerPreserved() throws {
        let input = try utf8Data(#"{"n":42}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"n":42}"#)
    }

    @Test("negative integer preserved")
    func negativeInteger() throws {
        let input = try utf8Data(#"{"n":-7}"#)
        let result = try utf8String(try CanonicalJSON.canonicalise(input))
        #expect(result == #"{"n":-7}"#)
    }

    // MARK: - contentHash

    @Test("contentHash starts with 'sha256-' prefix")
    func contentHashPrefix() throws {
        let hash = try CanonicalJSON.contentHash(of: utf8Data(#"{"a":1}"#))
        #expect(hash.hasPrefix("sha256-"))
    }

    @Test("contentHash base64 portion is exactly 44 chars (256-bit SHA-256)")
    func contentHashLength() throws {
        let hash = try CanonicalJSON.contentHash(of: utf8Data(#"{"a":1}"#))
        let b64 = String(hash.dropFirst("sha256-".count))
        #expect(b64.count == 44)
    }

    @Test("contentHash is stable across calls")
    func contentHashStable() throws {
        let data = try utf8Data(#"{"a":1}"#)
        let h1 = try CanonicalJSON.contentHash(of: data)
        let h2 = try CanonicalJSON.contentHash(of: data)
        #expect(h1 == h2)
    }

    @Test("contentHash treats logically equal JSON as identical")
    func contentHashLogicallyEqual() throws {
        let a = try utf8Data(#"{"z":1,"a":2}"#)
        let b = try utf8Data(#"{"a":2,"z":1}"#)
        let ha = try CanonicalJSON.contentHash(of: a)
        let hb = try CanonicalJSON.contentHash(of: b)
        #expect(ha == hb)
    }

    @Test("contentHash distinguishes different content")
    func contentHashDistinguishes() throws {
        let a = try utf8Data(#"{"n":1}"#)
        let b = try utf8Data(#"{"n":2}"#)
        let ha = try CanonicalJSON.contentHash(of: a)
        let hb = try CanonicalJSON.contentHash(of: b)
        #expect(ha != hb)
    }

    // MARK: - canonicaliseAndHash

    @Test("canonicaliseAndHash returns consistent canonical bytes and hash")
    func canonicaliseAndHashConsistency() throws {
        let input = try utf8Data(#"{"z":1,"a":2}"#)
        let (canonical, hash) = try CanonicalJSON.canonicaliseAndHash(input)
        let expectedHash = try CanonicalJSON.contentHash(of: input)
        // canonical bytes and hash match individual call results
        #expect(hash == expectedHash)
        #expect(canonical == (try CanonicalJSON.canonicalise(input)))
    }

    // MARK: - Helpers

    private func utf8Data(_ string: String) throws -> Data {
        try #require(string.data(using: .utf8))
    }

    private func utf8String(_ data: Data) throws -> String {
        try #require(String(data: data, encoding: .utf8))
    }
}
