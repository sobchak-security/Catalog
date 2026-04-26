import Foundation

// MARK: - CameraLoader

/// A successfully loaded and decoded camera model file.
public struct LoadedCamera: Sendable {
    public let model: CameraModel
    public let filePath: String
    public let fileURL: URL
    public let rawData: Data

    public init(
        model: CameraModel,
        filePath: String,
        fileURL: URL,
        rawData: Data = Data()
    ) {
        self.model = model
        self.filePath = filePath
        self.fileURL = fileURL
        self.rawData = rawData
    }
}

/// A file that could not be loaded or decoded.
public struct LoadError: Sendable {
    public let filePath: String
    public let message: String
}

/// The combined result of loading an entire cameras directory.
public struct LoadResult: Sendable {
    public let cameras: [LoadedCamera]
    public let errors: [LoadError]

    public var isEmpty: Bool { cameras.isEmpty && errors.isEmpty }
}

/// Loads and decodes every `*.json` file under `directoryURL`.
/// Files are processed in lexicographic order for deterministic output.
public func loadCameras(from directoryURL: URL) -> LoadResult {
    let fm = FileManager.default
    var cameras: [LoadedCamera] = []
    var errors: [LoadError] = []

    var isDirectory: ObjCBool = false
    guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
        return LoadResult(
            cameras: [],
            errors: [LoadError(filePath: directoryURL.path,
                               message: "Directory not found")]
        )
    }

    guard isDirectory.boolValue else {
        return LoadResult(
            cameras: [],
            errors: [LoadError(filePath: directoryURL.path,
                               message: "Path exists but is not a directory")]
        )
    }

    let enumerator = fm.enumerator(
        at: directoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    )

    let urls = (enumerator?.compactMap { $0 as? URL } ?? [])
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.standardizedFileURL.path < $1.standardizedFileURL.path }

    let decoder = JSONDecoder()

    for url in urls {
        let filePath = url.standardizedFileURL.path
        do {
            let data = try Data(contentsOf: url)
            let model = try decoder.decode(CameraModel.self, from: data)
            cameras.append(
                LoadedCamera(
                    model: model,
                    filePath: filePath,
                    fileURL: url,
                    rawData: data
                )
            )
        } catch let e as DecodingError {
            errors.append(LoadError(filePath: filePath, message: e.humanReadable))
        } catch {
            errors.append(LoadError(filePath: filePath, message: error.localizedDescription))
        }
    }

    return LoadResult(cameras: cameras, errors: errors)
}

// MARK: - DecodingError helpers

extension DecodingError {
    var humanReadable: String {
        switch self {
        case .keyNotFound(let key, _):
            return "Missing required field '\(key.stringValue)'"
        case .valueNotFound(_, let ctx):
            let path = ctx.codingPath.map(\.stringValue).joined(separator: "/")
            return "Null value not allowed at /\(path)"
        case .typeMismatch(let type, let ctx):
            let path = ctx.codingPath.map(\.stringValue).joined(separator: "/")
            return "Type mismatch at /\(path): expected \(type)"
        case .dataCorrupted(let ctx):
            return "Data corrupted: \(ctx.debugDescription)"
        @unknown default:
            return localizedDescription
        }
    }
}
