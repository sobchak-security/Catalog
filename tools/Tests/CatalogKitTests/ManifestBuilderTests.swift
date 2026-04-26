import Foundation
import Testing

@testable import CatalogKit

@Suite("ManifestBuilder")
struct ManifestBuilderTests {

    // MARK: - Basic build

    @Test("build creates a valid manifest")
    func buildCreatesValidManifest() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let cameras = [makeCamera(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01")]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "test-key")
        let (manifest, written) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.revision.number == 1)
        #expect(manifest.modelCount == 1)
        #expect(manifest.entries.count == 1)
        #expect(manifest.signature == "")
        #expect(manifest.signerKeyID == "test-key")
        #expect(written.count == 1)
    }

    @Test("build writes canonical camera files to output/cameras/")
    func buildWritesCameraFiles() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let id = "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01"
        let cameras = [makeCamera(id: id)]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (_, written) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        #expect(written.count == 1)
        #expect(written[0].lastPathComponent == "\(id).json")
        #expect(FileManager.default.fileExists(atPath: written[0].path))
    }

    @Test("entries have sha256- prefixed content hashes")
    func entriesHaveSHA256Hashes() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let cameras = [makeCamera(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01")]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        #expect(manifest.entries[0].contentHash.hasPrefix("sha256-"))
    }

    @Test("build falls back to model encoding when rawData is empty")
    func buildWithEmptyRawData() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let base = makeCamera(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01")
        let camera = LoadedCamera(
            model: base.model,
            filePath: base.filePath,
            fileURL: base.fileURL,
            rawData: Data()
        )

        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest, written) = try ManifestBuilder().build(cameras: [camera], into: tmpDir, options: opts)

        #expect(manifest.entries.count == 1)
        #expect(FileManager.default.fileExists(atPath: written[0].path))
    }

    @Test("totalBytes equals sum of entry bytes")
    func totalBytesSumEntries() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let cameras = [
            makeCamera(id: "10000000-0000-4000-a000-000000000001"),
            makeCamera(id: "20000000-0000-4000-a000-000000000002"),
        ]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        let expectedTotal = manifest.entries.reduce(0) { $0 + $1.bytes }
        #expect(manifest.totalBytes == expectedTotal)
    }

    // MARK: - Ordering

    @Test("entries are sorted by UUID string")
    func entriesSortedByUUID() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let id1 = "10000000-0000-4000-a000-000000000001"
        let id2 = "20000000-0000-4000-a000-000000000002"
        // Supply in reverse order to test sorting.
        let cameras = [makeCamera(id: id2), makeCamera(id: id1)]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        #expect(manifest.entries[0].id == id1)
        #expect(manifest.entries[1].id == id2)
    }

    // MARK: - Revision bookkeeping

    @Test("first build sets revisionAdded and revisionUpdated to current revision")
    func firstBuildSetsRevision() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let cameras = [makeCamera(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01")]
        let opts = ManifestBuilder.Options(revision: 3, signerKeyID: "k")
        let (manifest, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        #expect(manifest.entries[0].revisionAdded == 3)
        #expect(manifest.entries[0].revisionUpdated == 3)
    }

    @Test("unchanged camera keeps revisionAdded and revisionUpdated from previous build")
    func unchangedCameraKeepsRevisions() throws {
        let id = "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01"
        let cameras = [makeCamera(id: id)]

        let tmpDir1 = makeTmpDir()
        defer { cleanup(tmpDir1) }
        let opts1 = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest1, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir1, options: opts1)

        let tmpDir2 = makeTmpDir()
        defer { cleanup(tmpDir2) }
        let opts2 = ManifestBuilder.Options(revision: 2, previousManifest: manifest1, signerKeyID: "k")
        let (manifest2, _) = try ManifestBuilder().build(cameras: cameras, into: tmpDir2, options: opts2)

        #expect(manifest2.entries[0].revisionAdded == 1)
        #expect(manifest2.entries[0].revisionUpdated == 1)
    }

    @Test("changed camera updates revisionUpdated but preserves revisionAdded")
    func changedCameraUpdatesRevisionUpdated() throws {
        let id = "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01"

        let tmpDir1 = makeTmpDir()
        defer { cleanup(tmpDir1) }
        let opts1 = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest1, _) = try ManifestBuilder().build(
            cameras: [makeCamera(id: id, manufacturer: "Leica")],
            into: tmpDir1, options: opts1
        )

        let tmpDir2 = makeTmpDir()
        defer { cleanup(tmpDir2) }
        let opts2 = ManifestBuilder.Options(revision: 5, previousManifest: manifest1, signerKeyID: "k")
        let (manifest2, _) = try ManifestBuilder().build(
            cameras: [makeCamera(id: id, manufacturer: "Voigtlander")],  // changed content
            into: tmpDir2, options: opts2
        )

        #expect(manifest2.entries[0].revisionAdded == 1)   // preserved
        #expect(manifest2.entries[0].revisionUpdated == 5) // updated
    }

    @Test("new camera in second build gets current revision for both revision fields")
    func newCameraInSecondBuild() throws {
        let id1 = "10000000-0000-4000-a000-000000000001"
        let id2 = "20000000-0000-4000-a000-000000000002"

        let tmpDir1 = makeTmpDir()
        defer { cleanup(tmpDir1) }
        let opts1 = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (manifest1, _) = try ManifestBuilder().build(
            cameras: [makeCamera(id: id1)], into: tmpDir1, options: opts1
        )

        let tmpDir2 = makeTmpDir()
        defer { cleanup(tmpDir2) }
        let opts2 = ManifestBuilder.Options(revision: 4, previousManifest: manifest1, signerKeyID: "k")
        let (manifest2, _) = try ManifestBuilder().build(
            cameras: [makeCamera(id: id1), makeCamera(id: id2)],
            into: tmpDir2, options: opts2
        )

        let entry2 = manifest2.entries.first { $0.id == id2 }
        #expect(entry2?.revisionAdded == 4)
        #expect(entry2?.revisionUpdated == 4)
    }

    // MARK: - Canonical output

    @Test("written camera files are canonical (idempotent)")
    func writtenFilesAreCanonical() throws {
        let tmpDir = makeTmpDir()
        defer { cleanup(tmpDir) }

        let cameras = [makeCamera(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01")]
        let opts = ManifestBuilder.Options(revision: 1, signerKeyID: "k")
        let (_, written) = try ManifestBuilder().build(cameras: cameras, into: tmpDir, options: opts)

        let data = try Data(contentsOf: written[0])
        let recanonicalized = try CanonicalJSON.canonicalise(data)
        #expect(data == recanonicalized)
    }

    // MARK: - Helpers

    private func makeCamera(id: String, manufacturer: String = "Leica") -> LoadedCamera {
        let model = CameraModel(
            schemaVersion: 1,
            id: id,
            createdAt: "2026-01-01",
            manufacturer: manufacturer,
            model: "M3",
            classifiers: "rangefinder, 35mm",
            yearOfBuild: .init(from: 1954, to: 1966),
            rfCoupling: .coupled,
            format: "35mm",
            baseLength: .init(value: 69.25, unit: "mm", sources: [], ranking: 1),
            magnification: .init(value: 0.91, unit: "x", sources: [], ranking: 1)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rawData = (try? encoder.encode(model)) ?? Data()
        return LoadedCamera(
            model: model,
            filePath: "/tmp/cameras/\(id).json",
            fileURL: URL(fileURLWithPath: "/tmp/cameras/\(id).json"),
            rawData: rawData
        )
    }

    private func makeTmpDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
