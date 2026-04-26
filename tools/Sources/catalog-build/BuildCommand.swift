import ArgumentParser
import CatalogKit
import Foundation

// MARK: - catalog-build

/// Assembles a canonical, unsigned catalog snapshot from a cameras directory.
///
/// Usage:
/// ```
/// catalog-build --in data/cameras --out dist/v1 --revision 1
/// ```
///
/// Output layout:
/// ```
/// dist/v1/
/// ├── manifest.json        # unsigned (signature: "")
/// └── cameras/
///     └── <uuid>.json      # canonical-JSON copies of the source files
/// ```
@main
struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-build",
        abstract: "Assemble a canonical, unsigned catalog snapshot."
    )

    @Option(name: .customLong("in"), help: "Input data/cameras directory.")
    var input: String

    @Option(name: .customLong("out"), help: "Output dist directory (e.g. dist/v1).")
    var output: String

    @Option(name: .long, help: "Revision number to embed in the manifest (default: 1).")
    var revision: Int = 1

    @Option(
        name: .customLong("previous-manifest"),
        help: "Path to a previous manifest.json for revisionAdded/revisionUpdated tracking."
    )
    var previousManifest: String?

    @Option(
        name: .customLong("key-id"),
        help: "Signer key ID to embed in the manifest."
    )
    var keyID: String = "rf-buddy-catalog-2026-04"

    @Option(
        name: .customLong("published-at"),
        help: "ISO 8601 UTC timestamp to embed (default: current time)."
    )
    var publishedAt: String?

    @Flag(
        name: .customLong("no-sign"),
        help: "Produce an unsigned manifest.json (signature field stays empty string)."
    )
    var noSign: Bool = false

    func run() throws {
        var stderr = StderrStream()

        let inputURL  = URL(fileURLWithPath: input)
        let outputURL = URL(fileURLWithPath: output)

        // 1. Load cameras.
        let loadResult = loadCameras(from: inputURL)
        if !loadResult.errors.isEmpty {
            for err in loadResult.errors {
                print("error: \(err.filePath): \(err.message)", to: &stderr)
            }
            throw ExitCode.failure
        }
        if loadResult.cameras.isEmpty {
            print("error: no camera JSON files found in '\(input)'", to: &stderr)
            throw ExitCode.failure
        }

        // 2. Load previous manifest if supplied.
        var prevManifest: CatalogManifest?
        if let path = previousManifest {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            prevManifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        }

        // 3. Build canonical snapshot.
        let options = ManifestBuilder.Options(
            revision: revision,
            previousManifest: prevManifest,
            publishedAt: publishedAt,
            signerKeyID: keyID
        )
        let (manifest, writtenFiles) = try ManifestBuilder().build(
            cameras: loadResult.cameras,
            into: outputURL,
            options: options
        )

        // 4. Write manifest.json (unsigned).
        let manifestURL = outputURL.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestURL, options: .atomic)

        print(
            "catalog-build: revision \(revision), \(manifest.modelCount) model(s)," +
            " \(manifest.totalBytes) byte(s), \(writtenFiles.count) camera file(s) → \(manifestURL.path)" +
            (noSign ? " [unsigned]" : ""),
            to: &stderr
        )
    }
}
