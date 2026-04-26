import Testing
import Foundation
@testable import CatalogKit

// MARK: - Helpers

private func makeValidModel(
    schemaVersion: Int = 1,
    id: String = "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01",
    createdAt: String = "2026-04-26",
    manufacturer: String = "Agfa",
    model: String = "Isolette III",
    classifiers: String = "Uncoupled rangefinder.",
    yearFrom: Int = 1952,
    yearTo: Int? = 1960,
    rfCoupling: CameraModel.RFCoupling = .uncoupled,
    format: String = "6x6 on 120",
    baseLength: CameraModel.Measurement = .init(),
    magnification: CameraModel.Measurement = .init()
) -> CameraModel {
    CameraModel(
        schemaVersion: schemaVersion,
        id: id,
        createdAt: createdAt,
        manufacturer: manufacturer,
        model: model,
        classifiers: classifiers,
        yearOfBuild: .init(from: yearFrom, to: yearTo),
        rfCoupling: rfCoupling,
        format: format,
        baseLength: baseLength,
        magnification: magnification
    )
}

// MARK: - CameraValidator tests

@Suite("CameraValidator — single model")
struct CameraValidatorTests {

    let validator = CameraValidator()
    let path = "data/cameras/test.json"

    @Test func validModelProducesNoDiagnostics() {
        let model = makeValidModel()
        let diags = validator.validate(model, filePath: path)
        #expect(diags.isEmpty)
    }

    @Test func wrongSchemaVersionProducesDiagnostic() {
        let model = makeValidModel(schemaVersion: 2)
        let diags = validator.validate(model, filePath: path)
        #expect(diags.count == 1)
        #expect(diags[0].jsonPointer == "/schemaVersion")
        #expect(diags[0].severity == .error)
    }

    @Test func invalidUUIDProducesDiagnostic() {
        let model = makeValidModel(id: "not-a-uuid")
        let diags = validator.validate(model, filePath: path)
        let idDiags = diags.filter { $0.jsonPointer == "/id" }
        #expect(!idDiags.isEmpty)
    }

    @Test func emptyManufacturerProducesDiagnostic() {
        let model = makeValidModel(manufacturer: "")
        let diags = validator.validate(model, filePath: path)
        let mfgDiags = diags.filter { $0.jsonPointer == "/manufacturer" }
        #expect(!mfgDiags.isEmpty)
    }

    @Test func emptyModelNameProducesDiagnostic() {
        let model = makeValidModel(model: "")
        let diags = validator.validate(model, filePath: path)
        let modelDiags = diags.filter { $0.jsonPointer == "/model" }
        #expect(!modelDiags.isEmpty)
    }

    @Test func invalidDateFormatProducesDiagnostic() {
        let model = makeValidModel(createdAt: "26-04-2026")  // wrong order
        let diags = validator.validate(model, filePath: path)
        let dateDiags = diags.filter { $0.jsonPointer == "/createdAt" }
        #expect(!dateDiags.isEmpty)
    }

    @Test func yearFromGreaterThanToProducesDiagnostic() {
        let model = makeValidModel(yearFrom: 1970, yearTo: 1960)
        let diags = validator.validate(model, filePath: path)
        let yearDiags = diags.filter { $0.jsonPointer == "/yearOfBuild" }
        #expect(!yearDiags.isEmpty)
    }

    @Test func yearFromOutOfRangeProducesDiagnostic() {
        let model = makeValidModel(yearFrom: 1800)
        let diags = validator.validate(model, filePath: path)
        let diag = diags.first { $0.jsonPointer == "/yearOfBuild/from" }
        #expect(diag != nil)
    }

    @Test func invalidSourceTierProducesDiagnostic() {
        let badSource = CameraModel.Source(title: "Some book", tier: 6)
        let measurement = CameraModel.Measurement(sources: [badSource], ranking: 1)
        let model = makeValidModel(baseLength: measurement)
        let diags = validator.validate(model, filePath: path)
        let tierDiags = diags.filter { $0.jsonPointer.hasSuffix("/tier") }
        #expect(!tierDiags.isEmpty)
    }

    @Test func validSourceTierBoundariesAreAccepted() {
        for tier in 1...5 {
            let src = CameraModel.Source(title: "Source", tier: tier)
            let m = CameraModel.Measurement(sources: [src], ranking: 0)
            let model = makeValidModel(baseLength: m)
            let diags = validator.validate(model, filePath: path)
            let tierDiags = diags.filter { $0.jsonPointer.hasSuffix("/tier") }
            #expect(tierDiags.isEmpty, "tier \(tier) should be valid")
        }
    }

    @Test func invalidSourceURLProducesDiagnostic() {
        let badSource = CameraModel.Source(title: "Bad URL", url: "not-a-url", tier: 2)
        let measurement = CameraModel.Measurement(sources: [badSource], ranking: 0)
        let model = makeValidModel(baseLength: measurement)
        let diags = validator.validate(model, filePath: path)
        let urlDiags = diags.filter { $0.jsonPointer.hasSuffix("/url") }
        #expect(!urlDiags.isEmpty)
    }

    @Test func validHTTPSSourceURLIsAccepted() {
        let src = CameraModel.Source(
            title: "Valid URL",
            url: "https://example.com/source",
            tier: 2
        )
        let measurement = CameraModel.Measurement(sources: [src], ranking: 0)
        let model = makeValidModel(baseLength: measurement)
        let diags = validator.validate(model, filePath: path)
        let urlDiags = diags.filter { $0.jsonPointer.hasSuffix("/url") }
        #expect(urlDiags.isEmpty)
    }
}

// MARK: - Batch validation (uniqueness)

@Suite("batchValidate — cross-file checks")
struct BatchValidationTests {

    @Test func uniqueIDsProduceNoDiagnostics() {
        let cameras = [
            LoadedCamera(
                model: makeValidModel(id: "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01"),
                filePath: "data/cameras/a.json",
                fileURL: URL(fileURLWithPath: "data/cameras/a.json")
            ),
            LoadedCamera(
                model: makeValidModel(id: "7f2a1b3c-0002-4e8d-9f0a-1b2c3d4e5f02"),
                filePath: "data/cameras/b.json",
                fileURL: URL(fileURLWithPath: "data/cameras/b.json")
            ),
        ]
        let diags = batchValidate(cameras)
        #expect(diags.isEmpty)
    }

    @Test func duplicateIDProducesDiagnostic() {
        let sharedID = "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01"
        let cameras = [
            LoadedCamera(
                model: makeValidModel(id: sharedID),
                filePath: "data/cameras/a.json",
                fileURL: URL(fileURLWithPath: "data/cameras/a.json")
            ),
            LoadedCamera(
                model: makeValidModel(id: sharedID),
                filePath: "data/cameras/b.json",
                fileURL: URL(fileURLWithPath: "data/cameras/b.json")
            ),
        ]
        let diags = batchValidate(cameras)
        let idDiags = diags.filter { $0.jsonPointer == "/id" }
        #expect(!idDiags.isEmpty)
    }

        @Test func unexpectedTopLevelKeyProducesDiagnostic() throws {
                let raw = """
                {
                    "schemaVersion": 1,
                    "id": "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01",
                    "createdAt": "2026-04-26",
                    "manufacturer": "Agfa",
                    "model": "Isolette III",
                    "classifiers": "Uncoupled rangefinder.",
                    "yearOfBuild": { "from": 1952, "to": 1960 },
                    "rfCoupling": "uncoupled",
                    "format": "6x6 on 120",
                    "baseLength": { "value": null, "unit": "mm", "sources": [], "ranking": 0, "note": null },
                    "magnification": { "value": null, "sources": [], "ranking": 0, "note": null },
                    "userAnnotation": null,
                    "unexpected": true
                }
                """

                let data = try #require(raw.data(using: .utf8))
                let model = try JSONDecoder().decode(CameraModel.self, from: data)

                let camera = LoadedCamera(
                        model: model,
                        filePath: "data/cameras/with-extra-key.json",
                        fileURL: URL(fileURLWithPath: "data/cameras/with-extra-key.json"),
                        rawData: data
                )

                let diags = batchValidate([camera])
                let extraKeyDiag = diags.first { $0.jsonPointer == "/unexpected" }
                #expect(extraKeyDiag != nil)
        }

        @Test func unexpectedNestedSourceKeyProducesDiagnostic() throws {
                let raw = """
                {
                    "schemaVersion": 1,
                    "id": "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01",
                    "createdAt": "2026-04-26",
                    "manufacturer": "Leica",
                    "model": "M3",
                    "classifiers": "Coupled rangefinder.",
                    "yearOfBuild": { "from": 1954, "to": 1966 },
                    "rfCoupling": "coupled",
                    "format": "35mm",
                    "baseLength": {
                        "value": 68.5,
                        "unit": "mm",
                        "sources": [{
                            "title": "Leica M3 Manual",
                            "tier": 1,
                            "isbn": "1234"
                        }],
                        "ranking": 4,
                        "note": null
                    },
                    "magnification": { "value": 0.91, "sources": [], "ranking": 3, "note": null },
                    "userAnnotation": null
                }
                """

                let data = try #require(raw.data(using: .utf8))
                let model = try JSONDecoder().decode(CameraModel.self, from: data)

                let camera = LoadedCamera(
                        model: model,
                        filePath: "data/cameras/with-extra-source-key.json",
                        fileURL: URL(fileURLWithPath: "data/cameras/with-extra-source-key.json"),
                        rawData: data
                )

                let diags = batchValidate([camera])
                let extraKeyDiag = diags.first { $0.jsonPointer == "/baseLength/sources/0/isbn" }
                #expect(extraKeyDiag != nil)
        }
}

// MARK: - ValidationDiagnostic formatting

@Suite("ValidationDiagnostic formatting")
struct ValidationDiagnosticTests {

    @Test func textFormatIncludesAllComponents() {
        let d = ValidationDiagnostic(
            filePath: "data/cameras/foo.json",
            jsonPointer: "/manufacturer",
            message: "Must not be empty",
            severity: .error
        )
        let output = d.formatted(style: .text)
        #expect(output.contains("data/cameras/foo.json"))
        #expect(output.contains("/manufacturer"))
        #expect(output.contains("Must not be empty"))
        #expect(output.contains("[error]"))
    }

    @Test func githubFormatStartsWithAnnotationPrefix() {
        let d = ValidationDiagnostic(
            filePath: "data/cameras/foo.json",
            jsonPointer: "/id",
            message: "Not a valid UUID",
            severity: .error
        )
        let output = d.formatted(style: .github)
        #expect(output.hasPrefix("::error "))
        #expect(output.contains("file=data/cameras/foo.json"))
        #expect(output.contains("Not a valid UUID"))
    }

    @Test func warningUsesCorrectSeverityLabel() {
        let d = ValidationDiagnostic(
            filePath: "x.json",
            jsonPointer: "/note",
            message: "Consider adding a note",
            severity: .warning
        )
        #expect(d.formatted(style: .text).contains("[warning]"))
        #expect(d.formatted(style: .github).hasPrefix("::warning "))
    }

    @Test func githubFormatEscapesReservedCharacters() {
        let d = ValidationDiagnostic(
            filePath: "data/cameras/a,b:c\nname.json",
            jsonPointer: "/id",
            message: "Bad value: 100%\nsecond line",
            severity: .error
        )

        let output = d.formatted(style: .github)
        #expect(output.contains("file=data/cameras/a%2Cb%3Ac%0Aname.json"))
        #expect(output.contains("100%25%0Asecond line"))
        #expect(!output.contains("\n"))
    }
}
