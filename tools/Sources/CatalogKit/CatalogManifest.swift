import Foundation

// MARK: - CatalogManifest

/// The assembled, signed top-level document the RF Buddy app fetches.
/// Mirrors the wire format in ARCHITECTURE.md §5 and
/// schema/manifest.schema.json.
public struct CatalogManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let revision: Revision
    public let modelCount: Int
    public let totalBytes: Int
    public let entries: [Entry]
    public let signerKeyID: String
    public let signature: String

    public struct Revision: Codable, Sendable {
        public let number: Int
        public let publishedAt: String
    }

    public struct Entry: Codable, Sendable {
        public let id: String
        public let revisionAdded: Int
        public let revisionUpdated: Int
        public let contentHash: String
        public let bytes: Int
        public let path: String
    }
}
