import ArgumentParser
import CatalogKit
import Foundation

// catalog-sign: Ed25519 sign, verify, and keygen for catalog manifests.
// Full implementation in M2.

@main
struct SignCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-sign",
        abstract: "Sign, verify, or generate Ed25519 keys for catalog manifests.",
        subcommands: [VerifyCommand.self, KeygenCommand.self]
    )

    // Default: sign a manifest
    @Option(name: .customLong("in"), help: "Unsigned manifest.json to sign.")
    var input: String

    @Option(name: .customLong("out"), help: "Output path for manifest.signed.json.")
    var output: String

    func run() throws {
        var stderr = StderrStream()
        print("catalog-sign: not yet implemented (M2)", to: &stderr)
        throw ExitCode.failure
    }
}

// MARK: - Subcommands

struct VerifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify the Ed25519 signature on a signed manifest."
    )

    @Option(name: .customLong("in"), help: "Signed manifest.signed.json to verify.")
    var input: String

    @Option(name: .long, help: "Path to the Ed25519 public key (.pub file).")
    var pubkey: String

    func run() throws {
        var stderr = StderrStream()
        print("catalog-sign verify: not yet implemented (M2)", to: &stderr)
        throw ExitCode.failure
    }
}

struct KeygenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keygen",
        abstract: "Generate a new Ed25519 key pair for catalog signing."
    )

    @Option(name: .customLong("out"), help: "Output path for the private key file.")
    var output: String

    @Option(name: .long, help: "Output path for the public key (.pub) file.")
    var pub: String

    func run() throws {
        var stderr = StderrStream()
        print("catalog-sign keygen: not yet implemented (M2)", to: &stderr)
        throw ExitCode.failure
    }
}
