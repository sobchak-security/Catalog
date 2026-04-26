import Foundation

// MARK: - CameraModel

/// A single rangefinder camera model entry in the RF Buddy Catalog.
/// Mirrors the wire format described in ARCHITECTURE.md §5 and
/// validated by schema/camera.schema.json.
public struct CameraModel: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let id: String
    public let createdAt: String
    public let manufacturer: String
    public let model: String
    public let classifiers: String
    public let yearOfBuild: YearRange
    public let rfCoupling: RFCoupling
    public let format: String
    public let baseLength: Measurement
    public let magnification: Measurement
    public let userAnnotation: String?

    public init(
        schemaVersion: Int,
        id: String,
        createdAt: String,
        manufacturer: String,
        model: String,
        classifiers: String,
        yearOfBuild: YearRange,
        rfCoupling: RFCoupling,
        format: String,
        baseLength: Measurement,
        magnification: Measurement,
        userAnnotation: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.manufacturer = manufacturer
        self.model = model
        self.classifiers = classifiers
        self.yearOfBuild = yearOfBuild
        self.rfCoupling = rfCoupling
        self.format = format
        self.baseLength = baseLength
        self.magnification = magnification
        self.userAnnotation = userAnnotation
    }
}

// MARK: - Nested types

extension CameraModel {

    public struct YearRange: Codable, Sendable, Equatable {
        public let from: Int
        public let to: Int?

        public init(from: Int, to: Int? = nil) {
            self.from = from
            self.to = to
        }
    }

    public enum RFCoupling: String, Codable, Sendable, Equatable {
        case coupled
        case uncoupled
        case none
    }

    public struct Measurement: Codable, Sendable, Equatable {
        public let value: Double?
        public let unit: String?
        public let sources: [Source]
        public let ranking: Int
        public let note: String?

        public init(
            value: Double? = nil,
            unit: String? = nil,
            sources: [Source] = [],
            ranking: Int = 0,
            note: String? = nil
        ) {
            self.value = value
            self.unit = unit
            self.sources = sources
            self.ranking = ranking
            self.note = note
        }
    }

    public struct Source: Codable, Sendable, Equatable {
        public let title: String
        public let author: String?
        public let year: Int?
        public let type: SourceType?
        public let url: String?
        public let citation: String?
        public let tier: Int

        public init(
            title: String,
            author: String? = nil,
            year: Int? = nil,
            type: SourceType? = nil,
            url: String? = nil,
            citation: String? = nil,
            tier: Int
        ) {
            self.title = title
            self.author = author
            self.year = year
            self.type = type
            self.url = url
            self.citation = citation
            self.tier = tier
        }

        public enum SourceType: String, Codable, Sendable, Equatable {
            case book
            case article
            case web
            case manual
            case measurement
        }
    }
}
