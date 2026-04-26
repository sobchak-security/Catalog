import ArgumentParser
import CatalogKit
import Foundation

// MARK: - catalog-publish

/// Publishes a signed catalog snapshot to GitHub Releases via the `gh` CLI.
///
/// Usage:
/// ```
/// catalog-publish --dist dist/v17 --tag catalog-v17 [--notes CHANGELOG.fragment.md]
/// ```
///
/// The tool expects:
/// - `{dist}/manifest.signed.json` — produced by `catalog-sign`
/// - `{dist}/cameras/*.json`       — canonical camera files from `catalog-build`
///
/// Requires `gh` CLI authenticated with `contents: write` permission.
@main
struct PublishCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-publish",
        abstract: "Publish a signed catalog snapshot to GitHub Releases via gh CLI."
    )

    @Option(name: .customLong("dist"), help: "Path to the dist/v{N} directory to publish.")
    var distPath: String

    @Option(name: .long, help: "Tag name, e.g. catalog-v17.")
    var tag: String

    @Option(
        name: .customLong("notes"),
        help: "Path to a Markdown release-notes file. If omitted, gh auto-generates notes."
    )
    var notes: String?

    @Option(
        name: .customLong("title"),
        help: "Release title. Default: tag with 'catalog-v' replaced by 'Catalog v'."
    )
    var title: String?

    @Flag(name: .customLong("draft"), help: "Create a draft release instead of publishing.")
    var draft: Bool = false

    func run() throws {
        var stderr = StderrStream()

        let distURL      = URL(fileURLWithPath: distPath)
        let manifestURL  = distURL.appendingPathComponent("manifest.signed.json")
        let camerasURL   = distURL.appendingPathComponent("cameras")

        // 1. Verify the signed manifest is present.
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            print(
                "error: manifest.signed.json not found at '\(manifestURL.path)'" +
                " — run catalog-sign first",
                to: &stderr
            )
            throw ExitCode.failure
        }

        // 2. Collect camera files.
        let cameraFiles: [String]
        do {
            cameraFiles = try FileManager.default
                .contentsOfDirectory(atPath: camerasURL.path)
                .filter { $0.hasSuffix(".json") }
                .sorted()
                .map { camerasURL.appendingPathComponent($0).path }
        } catch {
            print("error: cannot read cameras directory '\(camerasURL.path)': \(error)", to: &stderr)
            throw ExitCode.failure
        }

        // 3. Assemble gh release create arguments.
        let releaseTitle = title ?? tag.replacingOccurrences(of: "catalog-v", with: "Catalog v")
        var ghArgs: [String] = ["release", "create", tag, "--title", releaseTitle]

        if draft {
            ghArgs.append("--draft")
        }

        if let notesPath = notes {
            guard FileManager.default.fileExists(atPath: notesPath) else {
                print("error: notes file not found at '\(notesPath)'", to: &stderr)
                throw ExitCode.failure
            }
            ghArgs += ["--notes-file", notesPath]
        } else {
            ghArgs.append("--generate-notes")
        }

        // Assets: signed manifest first, then cameras.
        ghArgs.append(manifestURL.path)
        ghArgs += cameraFiles

        print(
            "catalog-publish: creating release '\(tag)' with" +
            " \(cameraFiles.count) camera file(s)...",
            to: &stderr
        )

        // 4. Execute `gh release create`.
        let exitCode = try runSubprocess(executableName: "gh", arguments: ghArgs)
        guard exitCode == 0 else {
            throw ExitCode(exitCode)
        }

        print("catalog-publish: '\(tag)' published successfully.", to: &stderr)
    }

    // Resolves `executableName` through PATH via `/usr/bin/env`, then runs it.
    private func runSubprocess(executableName: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments     = [executableName] + arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
