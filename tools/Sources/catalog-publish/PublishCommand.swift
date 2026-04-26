import ArgumentParser
import CatalogKit
import Foundation

// catalog-publish: publish a signed snapshot to GitHub Releases via gh CLI.
// Full implementation in M3.

@main
struct PublishCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-publish",
        abstract: "Publish a signed catalog snapshot to GitHub Releases (implemented in M3)."
    )

    @Option(name: .customLong("dist"), help: "Path to the dist/v{N} directory to publish.")
    var distPath: String

    @Option(name: .long, help: "Tag name, e.g. catalog-v17.")
    var tag: String

    @Option(name: .customLong("notes"), help: "Path to the release notes Markdown file.")
    var notes: String?

    func run() throws {
        var stderr = StderrStream()
        print("catalog-publish: not yet implemented (M3)", to: &stderr)
        throw ExitCode.failure
    }
}
