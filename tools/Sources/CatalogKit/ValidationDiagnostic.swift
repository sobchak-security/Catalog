import Foundation

// MARK: - ValidationDiagnostic

/// A single validation finding for a camera model file.
public struct ValidationDiagnostic: Sendable, CustomStringConvertible {

    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let filePath: String
    /// JSON Pointer (RFC 6901) indicating the location of the problem.
    public let jsonPointer: String
    public let message: String
    public let severity: Severity

    public init(
        filePath: String,
        jsonPointer: String,
        message: String,
        severity: Severity = .error
    ) {
        self.filePath = filePath
        self.jsonPointer = jsonPointer
        self.message = message
        self.severity = severity
    }

    // MARK: Output styles

    public enum OutputStyle: String, Sendable {
        /// Plain text: path: [/pointer] [severity] message
        case text
        /// GitHub Actions annotation: ::error file=...::pointer: message
        case github
    }

    public func formatted(style: OutputStyle) -> String {
        switch style {
        case .text:
            return "\(filePath): [\(jsonPointer)] [\(severity.rawValue)] \(message)"
        case .github:
            let escapedFile = escapeGitHubPropertyValue(filePath)
            let escapedTitle = escapeGitHubPropertyValue("Schema violation")
            let escapedMessage = escapeGitHubMessage("\(jsonPointer): \(message)")
            return "::\(severity.rawValue) file=\(escapedFile),title=\(escapedTitle)::\(escapedMessage)"
        }
    }

    public var description: String { formatted(style: .text) }
}

// MARK: - StderrStream

/// A TextOutputStream that writes to standard error.
public struct StderrStream: TextOutputStream {
    public init() {}
    public mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

private func escapeGitHubPropertyValue(_ value: String) -> String {
    value
        .replacingOccurrences(of: "%", with: "%25")
        .replacingOccurrences(of: "\r", with: "%0D")
        .replacingOccurrences(of: "\n", with: "%0A")
        .replacingOccurrences(of: ":", with: "%3A")
        .replacingOccurrences(of: ",", with: "%2C")
}

private func escapeGitHubMessage(_ value: String) -> String {
    value
        .replacingOccurrences(of: "%", with: "%25")
        .replacingOccurrences(of: "\r", with: "%0D")
        .replacingOccurrences(of: "\n", with: "%0A")
}
