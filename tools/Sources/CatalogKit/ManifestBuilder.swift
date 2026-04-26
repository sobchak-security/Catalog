import Foundation

// MARK: - ManifestBuilder

/// Builds an unsigned ``CatalogManifest`` from a set of loaded camera files.
///
/// For each camera the builder:
/// 1. Canonicalises the raw JSON bytes (sorted keys, compact).
/// 2. Writes the canonical form to ``outputDirectory/cameras/<filename>``.
/// 3. Computes a SHA-256 content hash of the canonical bytes.
/// 4. Tracks ``revisionAdded`` / ``revisionUpdated`` by comparing against the
///    previous manifest's entries (if provided).
///
/// The returned manifest always has ``signature == ""``.  Sign it with
/// ``ManifestSigner`` to produce the final distributable artifact.
public struct ManifestBuilder {

    // MARK: - Options

    public struct Options: Sendable {
        /// Monotonically increasing release number.
        public var revision: Int
        /// Previous release manifest used to track revision bookkeeping.
        /// Pass `nil` for a first release — both `revisionAdded` and
        /// `revisionUpdated` will be set to `revision`.
        public var previousManifest: CatalogManifest?
        /// ISO 8601 UTC timestamp embedded in the manifest.  Defaults to now.
        public var publishedAt: String?
        /// Key ID matching `catalog.config.yml signing.current_key_id`.
        public var signerKeyID: String

        public init(
            revision: Int,
            previousManifest: CatalogManifest? = nil,
            publishedAt: String? = nil,
            signerKeyID: String
        ) {
            self.revision = revision
            self.previousManifest = previousManifest
            self.publishedAt = publishedAt
            self.signerKeyID = signerKeyID
        }
    }

    public init() {}

    // MARK: - Build

    /// Builds the manifest and writes canonical camera JSON files.
    ///
    /// - Parameters:
    ///   - cameras: Loaded camera models (order is irrelevant; sorted by UUID).
    ///   - outputDirectory: Target directory.  Created if absent.
    ///                      `cameras/` subdirectory is created automatically.
    ///   - options: Revision metadata and previous-manifest for bookkeeping.
    /// - Returns: The unsigned manifest and the URLs of every written camera file.
    public func build(
        cameras: [LoadedCamera],
        into outputDirectory: URL,
        options: Options
    ) throws -> (manifest: CatalogManifest, writtenFiles: [URL]) {

        let fm = FileManager.default
        let camerasOutDir = outputDirectory.appendingPathComponent("cameras")
        try fm.createDirectory(at: camerasOutDir,
                                withIntermediateDirectories: true,
                                attributes: nil)

        // Fast lookup of previous entries by camera UUID.
        var prevEntries: [String: CatalogManifest.Entry] = [:]
        for entry in (options.previousManifest?.entries ?? []) {
            prevEntries[entry.id] = entry
        }

        // Deterministic ordering: sort by UUID string.
        let sorted = cameras.sorted { $0.model.id < $1.model.id }
        let fallbackEncoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return encoder
        }()

        var entries: [CatalogManifest.Entry] = []
        var totalBytes = 0
        var writtenFiles: [URL] = []

        for loaded in sorted {
            // Canonicalise and hash in one pass.
            let sourceData = loaded.rawData.isEmpty
                ? try fallbackEncoder.encode(loaded.model)
                : loaded.rawData

            let (canonical, hash) = try CanonicalJSON.canonicaliseAndHash(sourceData)
            let bytes = canonical.count
            totalBytes += bytes

            // Preserve the original filename (UUID-based).
            let filename = loaded.fileURL.lastPathComponent.lowercased()
            let destURL = camerasOutDir.appendingPathComponent(filename)
            try canonical.write(to: destURL, options: .atomic)
            writtenFiles.append(destURL)

            // Revision bookkeeping.
            let prev = prevEntries[loaded.model.id]
            let revAdded   = prev?.revisionAdded ?? options.revision
            let revUpdated: Int
            if let prev, prev.contentHash == hash {
                // Content unchanged — keep the previous revisionUpdated.
                revUpdated = prev.revisionUpdated
            } else {
                // New or changed — update to current revision.
                revUpdated = options.revision
            }

            entries.append(CatalogManifest.Entry(
                id: loaded.model.id,
                revisionAdded: revAdded,
                revisionUpdated: revUpdated,
                contentHash: hash,
                bytes: bytes,
                path: "cameras/\(filename)"
            ))
        }

        let publishedAt = options.publishedAt ?? ISO8601DateFormatter().string(from: Date())
        let manifest = CatalogManifest(
            schemaVersion: 1,
            revision: .init(number: options.revision, publishedAt: publishedAt),
            modelCount: entries.count,
            totalBytes: totalBytes,
            entries: entries,
            signerKeyID: options.signerKeyID,
            signature: ""
        )

        return (manifest, writtenFiles)
    }
}
