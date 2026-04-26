import Foundation

// MARK: - CameraValidator

/// Validates a single decoded ``CameraModel`` against business rules.
/// Returns an array of ``ValidationDiagnostic`` values (empty = valid).
public struct CameraValidator: Sendable {

    private static let allowedCameraKeys: Set<String> = [
        "schemaVersion",
        "id",
        "createdAt",
        "manufacturer",
        "model",
        "classifiers",
        "yearOfBuild",
        "rfCoupling",
        "format",
        "baseLength",
        "magnification",
        "userAnnotation",
    ]

    private static let allowedYearRangeKeys: Set<String> = ["from", "to"]
    private static let allowedMeasurementKeys: Set<String> = ["value", "unit", "sources", "ranking", "note"]
    private static let allowedSourceKeys: Set<String> = ["title", "author", "year", "type", "url", "citation", "tier"]

    public init() {}

    /// Performs structural checks directly against raw JSON bytes to catch
    /// unexpected keys (`additionalProperties: false`) that Codable decoding
    /// would otherwise ignore.
    public func validateRawJSON(_ data: Data, filePath: String) -> [ValidationDiagnostic] {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            return [diag(filePath, "/", "Invalid JSON: \(error.localizedDescription)")]
        }

        guard let root = jsonObject as? [String: Any] else {
            return [diag(filePath, "/", "Top-level JSON value must be an object")]
        }

        var d = validateUnexpectedKeys(
            in: root,
            allowed: Self.allowedCameraKeys,
            pointer: "",
            filePath: filePath
        )

        if let yearOfBuild = root["yearOfBuild"] as? [String: Any] {
            d += validateUnexpectedKeys(
                in: yearOfBuild,
                allowed: Self.allowedYearRangeKeys,
                pointer: "/yearOfBuild",
                filePath: filePath
            )
        }

        if let baseLength = root["baseLength"] as? [String: Any] {
            d += validateMeasurementShape(baseLength, pointer: "/baseLength", filePath: filePath)
        }

        if let magnification = root["magnification"] as? [String: Any] {
            d += validateMeasurementShape(magnification, pointer: "/magnification", filePath: filePath)
        }

        return d
    }

    public func validate(_ model: CameraModel, filePath: String) -> [ValidationDiagnostic] {
        var d: [ValidationDiagnostic] = []

        // schemaVersion must be 1
        if model.schemaVersion != 1 {
            d.append(diag(filePath, "/schemaVersion",
                "Expected schemaVersion 1, got \(model.schemaVersion)"))
        }

        // id must parse as a UUID
        if UUID(uuidString: model.id) == nil {
            d.append(diag(filePath, "/id", "Not a valid UUID: \(model.id)"))
        }

        // createdAt must be YYYY-MM-DD
        if !isValidISODate(model.createdAt) {
            d.append(diag(filePath, "/createdAt",
                "Does not match YYYY-MM-DD format: \(model.createdAt)"))
        }

        // manufacturer and model must be non-empty
        if model.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            d.append(diag(filePath, "/manufacturer", "Must not be empty"))
        }
        if model.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            d.append(diag(filePath, "/model", "Must not be empty"))
        }

        // yearOfBuild range
        let yr = model.yearOfBuild
        if yr.from < 1900 || yr.from > 2100 {
            d.append(diag(filePath, "/yearOfBuild/from",
                "Must be between 1900 and 2100, got \(yr.from)"))
        }
        if let to = yr.to {
            if to < 1900 || to > 2100 {
                d.append(diag(filePath, "/yearOfBuild/to",
                    "Must be between 1900 and 2100, got \(to)"))
            }
            if yr.from > to {
                d.append(diag(filePath, "/yearOfBuild",
                    "from (\(yr.from)) must not be greater than to (\(to))"))
            }
        }

        // format must be non-empty
        if model.format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            d.append(diag(filePath, "/format", "Must not be empty"))
        }

        // measurement rankings
        if model.baseLength.ranking < 0 {
            d.append(diag(filePath, "/baseLength/ranking", "Must be >= 0"))
        }
        if model.magnification.ranking < 0 {
            d.append(diag(filePath, "/magnification/ranking", "Must be >= 0"))
        }

        // sources in each measurement
        for (i, src) in model.baseLength.sources.enumerated() {
            d += validateSource(src, at: "/baseLength/sources/\(i)", filePath: filePath)
        }
        for (i, src) in model.magnification.sources.enumerated() {
            d += validateSource(src, at: "/magnification/sources/\(i)", filePath: filePath)
        }

        return d
    }

    // MARK: - Private helpers

    private func validateSource(
        _ source: CameraModel.Source,
        at pointer: String,
        filePath: String
    ) -> [ValidationDiagnostic] {
        var d: [ValidationDiagnostic] = []

        if source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            d.append(diag(filePath, "\(pointer)/title", "Must not be empty"))
        }

        if source.tier < 1 || source.tier > 5 {
            d.append(diag(filePath, "\(pointer)/tier",
                "Must be between 1 and 5, got \(source.tier)"))
        }

        if let urlString = source.url {
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                d.append(diag(filePath, "\(pointer)/url",
                    "Must be a valid http/https URI: \(urlString)"))
                // Continue validating other fields for fuller diagnostics.
                if let year = source.year, year < 1900 || year > 2100 {
                    d.append(diag(filePath, "\(pointer)/year",
                        "Must be between 1900 and 2100, got \(year)"))
                }
                return d
            }
        }

        if let year = source.year, year < 1900 || year > 2100 {
            d.append(diag(filePath, "\(pointer)/year",
                "Must be between 1900 and 2100, got \(year)"))
        }

        return d
    }

    private func diag(
        _ filePath: String,
        _ pointer: String,
        _ message: String,
        severity: ValidationDiagnostic.Severity = .error
    ) -> ValidationDiagnostic {
        ValidationDiagnostic(
            filePath: filePath,
            jsonPointer: pointer,
            message: message,
            severity: severity
        )
    }

    private func isValidISODate(_ value: String) -> Bool {
        guard value.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil else {
            return false
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) != nil
    }

    private func validateMeasurementShape(
        _ measurement: [String: Any],
        pointer: String,
        filePath: String
    ) -> [ValidationDiagnostic] {
        var d = validateUnexpectedKeys(
            in: measurement,
            allowed: Self.allowedMeasurementKeys,
            pointer: pointer,
            filePath: filePath
        )

        if let sources = measurement["sources"] as? [Any] {
            for (index, sourceValue) in sources.enumerated() {
                guard let source = sourceValue as? [String: Any] else {
                    continue
                }
                d += validateUnexpectedKeys(
                    in: source,
                    allowed: Self.allowedSourceKeys,
                    pointer: "\(pointer)/sources/\(index)",
                    filePath: filePath
                )
            }
        }

        return d
    }

    private func validateUnexpectedKeys(
        in object: [String: Any],
        allowed: Set<String>,
        pointer: String,
        filePath: String
    ) -> [ValidationDiagnostic] {
        var d: [ValidationDiagnostic] = []

        for key in object.keys.sorted() where !allowed.contains(key) {
            d.append(
                diag(
                    filePath,
                    appendingJSONPointerToken(base: pointer, token: key),
                    "Unexpected property '\(key)'"
                )
            )
        }

        return d
    }

    private func appendingJSONPointerToken(base: String, token: String) -> String {
        let escapedToken = token
            .replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")

        if base.isEmpty {
            return "/\(escapedToken)"
        }
        return "\(base)/\(escapedToken)"
    }
}

// MARK: - Batch validation

/// Validates a collection of already-decoded cameras, including
/// the cross-file uniqueness check on `id`.
public func batchValidate(_ cameras: [LoadedCamera]) -> [ValidationDiagnostic] {
    let validator = CameraValidator()
    var diagnostics: [ValidationDiagnostic] = []

    for camera in cameras {
        if !camera.rawData.isEmpty {
            diagnostics += validator.validateRawJSON(camera.rawData, filePath: camera.filePath)
        }
        diagnostics += validator.validate(camera.model, filePath: camera.filePath)
    }

    var seen: [String: String] = [:]
    for camera in cameras {
        let id = camera.model.id
        if let previous = seen[id] {
            diagnostics.append(ValidationDiagnostic(
                filePath: camera.filePath,
                jsonPointer: "/id",
                message: "Duplicate id \(id) — also present in \(previous)"
            ))
        } else {
            seen[id] = camera.filePath
        }
    }

    return diagnostics
}
