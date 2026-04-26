import ArgumentParser
import CatalogKit
import Foundation

// MARK: - Root command

enum ReportFormat: String, ExpressibleByArgument {
    case text
    case github
}

@main
struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog-validate",
        abstract: "Validate RF Buddy Catalog files.",
        subcommands: [CdnProbeCommand.self, LinkRotCommand.self]
    )

    // Default invocation: catalog-validate <cameras-dir> [options]
    // Subcommands handle cdn-probe and link-rot (implemented in M5).

    @Argument(help: "Path to the data/cameras directory.")
    var camerasDirectory: String

    @Option(
        name: .long,
        help: "Path to camera.schema.json (accepted for compatibility; structural validation is used)."
    )
    var schema: String?

    @Option(
        name: .customLong("report-format"),
        help: "Output format: 'text' (default) or 'github' (GitHub Actions annotations)."
    )
    var reportFormat: ReportFormat = .text

    func run() throws {
        let style: ValidationDiagnostic.OutputStyle = (reportFormat == .github) ? .github : .text
        var stderr = StderrStream()

        if let schemaPath = schema,
           !FileManager.default.fileExists(atPath: schemaPath) {
            throw ValidationError("Schema file not found: \(schemaPath)")
        }

        let dirURL = URL(fileURLWithPath: camerasDirectory)
        let result = loadCameras(from: dirURL)

        var allDiagnostics: [ValidationDiagnostic] = []

        // Collect decode / load errors
        for loadError in result.errors {
            allDiagnostics.append(ValidationDiagnostic(
                filePath: loadError.filePath,
                jsonPointer: "/",
                message: loadError.message
            ))
        }

        // Per-model + cross-file validation
        allDiagnostics += batchValidate(result.cameras)

        let sortedDiagnostics = allDiagnostics.sorted {
            if $0.filePath != $1.filePath {
                return $0.filePath < $1.filePath
            }
            if $0.jsonPointer != $1.jsonPointer {
                return $0.jsonPointer < $1.jsonPointer
            }
            return $0.message < $1.message
        }

        // Emit diagnostics
        for diagnostic in sortedDiagnostics {
            print(diagnostic.formatted(style: style), to: &stderr)
        }

        let total = result.cameras.count + result.errors.count
        let errorCount = sortedDiagnostics.filter { $0.severity == .error }.count
        let warnCount  = sortedDiagnostics.filter { $0.severity == .warning }.count

        print(
            "catalog-validate: \(total) file(s) checked" +
            " — \(errorCount) error(s), \(warnCount) warning(s).",
            to: &stderr
        )

        if errorCount > 0 {
            throw ExitCode.failure
        }
    }
}

// MARK: - Stub subcommands (implemented in M5)

struct CdnProbeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cdn-probe",
        abstract: "Probe CDN endpoints for reachability (implemented in M5)."
    )
    func run() throws {
        var stderr = StderrStream()
        print("cdn-probe: not yet implemented (M5)", to: &stderr)
        throw ExitCode.failure
    }
}

struct LinkRotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link-rot",
        abstract: "Check citation URLs for link rot (implemented in M5)."
    )

    @Option(name: .customLong("in"), help: "Input cameras directory.")
    var input: String = "./data/cameras"

    @Option(name: .long, help: "Output report path.")
    var report: String = "./docs/health/report.md"

    func run() throws {
        var stderr = StderrStream()
        print("link-rot: not yet implemented (M5)", to: &stderr)
        throw ExitCode.failure
    }
}
