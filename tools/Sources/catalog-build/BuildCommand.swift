import ArgumentParser
import CatalogKit
import Foundation

// catalog-build: assemble a canonical signed snapshot.
// Full implementation in M2.

@main
struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-build",
        abstract: "Build a canonical catalog snapshot (implemented in M2)."
    )

    @Option(name: .customLong("in"), help: "Input data/cameras directory.")
    var input: String

    @Option(name: .customLong("out"), help: "Output dist directory.")
    var output: String

    @Option(name: .long, help: "Revision number to embed in the manifest.")
    var revision: Int?

    @Flag(name: .customLong("no-sign"), help: "Skip signing (canonical-check mode).")
    var noSign: Bool = false

    func run() throws {
        var stderr = StderrStream()
        print("catalog-build: not yet implemented (M2)", to: &stderr)
        throw ExitCode.failure
    }
}
