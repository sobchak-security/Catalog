import ArgumentParser
import CatalogKit
import Foundation

// MARK: - catalog-sign

/// Signs, verifies, or generates Ed25519 keys for catalog manifests.
///
/// Default action — sign:
/// ```
/// catalog-sign --in dist/v1/manifest.json \
///              --out dist/v1/manifest.signed.json \
///              [--key key.private]          # or ED25519_PRIVATE_KEY env var
/// ```
///
/// Subcommands:
/// ```
/// catalog-sign verify  --in manifest.signed.json --pubkey tools/keys/rf-buddy-catalog-2026-04.pub
/// catalog-sign keygen  --out key.private --pub tools/keys/rf-buddy-catalog-2026-04.pub
/// ```
@main
struct SignCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-sign",
        abstract: "Sign, verify, or generate Ed25519 keys for catalog manifests.",
        subcommands: [SignSubcommand.self, VerifySubcommand.self, KeygenSubcommand.self],
        defaultSubcommand: SignSubcommand.self
    )
}

// MARK: - sign subcommand (default)

struct SignSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "Sign an unsigned manifest.json with an Ed25519 private key."
    )

    @Option(name: .customLong("in"), help: "Unsigned manifest.json to sign.")
    var input: String

    @Option(name: .customLong("out"), help: "Output path for manifest.signed.json.")
    var output: String

    @Option(
        name: .long,
        help: "Path to Ed25519 private key file (base64, 44 chars). Falls back to ED25519_PRIVATE_KEY env var."
    )
    var key: String?

    func run() throws {
        var stderr = StderrStream()

        // Load manifest.
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: input))

        // Resolve private key.
        let privateKeyData: Data
        if let keyPath = key {
            privateKeyData = try ManifestSigner.loadPrivateKeyData(fromFile: keyPath)
        } else {
            do {
                privateKeyData = try ManifestSigner.privateKeyDataFromEnv()
            } catch SigningError.envVarMissing {
                print("error: provide --key <path> or set ED25519_PRIVATE_KEY env var", to: &stderr)
                throw ExitCode.failure
            }
        }

        // Sign.
        let signedData = try ManifestSigner.sign(manifestData: manifestData, privateKeyData: privateKeyData)

        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try signedData.write(to: outputURL, options: .atomic)

        print("catalog-sign: signed manifest written to '\(output)'", to: &stderr)
    }
}

// MARK: - verify subcommand

struct VerifySubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify the Ed25519 signature on a signed manifest."
    )

    @Option(name: .customLong("in"), help: "Signed manifest.signed.json to verify.")
    var input: String

    @Option(name: .long, help: "Path to the Ed25519 public key file (.pub, base64, 44 chars).")
    var pubkey: String

    func run() throws {
        var stderr = StderrStream()

        let signedData = try Data(contentsOf: URL(fileURLWithPath: input))
        let pubKeyData = try ManifestSigner.loadPublicKeyData(fromFile: pubkey)

        try ManifestSigner.verify(signedManifestData: signedData, publicKeyData: pubKeyData)

        print("catalog-sign verify: signature valid ✓", to: &stderr)
    }
}

// MARK: - keygen subcommand

struct KeygenSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keygen",
        abstract: "Generate a new Ed25519 key pair for catalog signing."
    )

    @Option(name: .customLong("out"), help: "Output path for the private key file (base64).")
    var output: String

    @Option(name: .long, help: "Output path for the public key .pub file (base64).")
    var pub: String

    func run() throws {
        var stderr = StderrStream()

        let (privBytes, pubBytes) = ManifestSigner.generateKeyPair()

        let privB64 = privBytes.base64EncodedString()
        let pubB64  = pubBytes.base64EncodedString()

        let privURL = URL(fileURLWithPath: output)
        let pubURL  = URL(fileURLWithPath: pub)

        try FileManager.default.createDirectory(
            at: privURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: pubURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data(privB64.utf8).write(to: privURL, options: .atomic)
        try Data(pubB64.utf8).write(to: pubURL,  options: .atomic)

        print("catalog-sign keygen: private key → '\(output)'", to: &stderr)
        print("catalog-sign keygen: public  key → '\(pub)'",    to: &stderr)
        print(
            "catalog-sign keygen: public key (base64): \(pubB64)" +
            "\n  Add to catalog.config.yml signing.current_key_id and commit '\(pub)'.",
            to: &stderr
        )
    }
}
