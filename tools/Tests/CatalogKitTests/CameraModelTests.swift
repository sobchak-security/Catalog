import Testing
import Foundation
@testable import CatalogKit

// MARK: - CameraModel decoding tests

@Suite("CameraModel decoding")
struct CameraModelDecodingTests {

    let validJSON = """
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
      "userAnnotation": null
    }
    """

    @Test func validCameraDecodesSuccessfully() throws {
        let data = try #require(validJSON.data(using: .utf8))
        let model = try JSONDecoder().decode(CameraModel.self, from: data)
        #expect(model.manufacturer == "Agfa")
        #expect(model.model == "Isolette III")
        #expect(model.rfCoupling == .uncoupled)
        #expect(model.yearOfBuild.from == 1952)
        #expect(model.yearOfBuild.to == 1960)
        #expect(model.schemaVersion == 1)
        #expect(model.baseLength.sources.isEmpty)
        #expect(model.userAnnotation == nil)
    }

    @Test func missingRequiredFieldThrowsDecodingError() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "7f2a1b3c-0001-4e8d-9f0a-1b2c3d4e5f01",
          "createdAt": "2026-04-26"
        }
        """
        let data = json.data(using: .utf8)
        #expect(throws: DecodingError.self) {
            let raw = try #require(data)
            _ = try JSONDecoder().decode(CameraModel.self, from: raw)
        }
    }

    @Test func invalidRFCouplingValueThrowsDecodingError() {
        let json = validJSON.replacingOccurrences(of: "\"uncoupled\"", with: "\"turbo\"")
        let data = json.data(using: .utf8)
        #expect(throws: DecodingError.self) {
            let raw = try #require(data)
            _ = try JSONDecoder().decode(CameraModel.self, from: raw)
        }
    }

    @Test func coupledAndNoneRFCouplingValuesAreValid() throws {
        for value in ["coupled", "none"] {
            let json = validJSON.replacingOccurrences(of: "\"uncoupled\"", with: "\"\(value)\"")
            let data = try #require(json.data(using: .utf8))
            let model = try JSONDecoder().decode(CameraModel.self, from: data)
            #expect(model.rfCoupling.rawValue == value)
        }
    }

    @Test func sourceWithAllFieldsDecodesSuccessfully() throws {
        let json = """
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
              "author": "Leitz",
              "year": 1954,
              "type": "manual",
              "url": "https://example.com/m3",
              "citation": null,
              "tier": 1
            }],
            "ranking": 5,
            "note": null
          },
          "magnification": { "value": 0.91, "sources": [], "ranking": 3, "note": null },
          "userAnnotation": null
        }
        """
        let data = try #require(json.data(using: .utf8))
        let model = try JSONDecoder().decode(CameraModel.self, from: data)
        #expect(model.baseLength.value == 68.5)
        #expect(model.baseLength.sources.count == 1)
        #expect(model.baseLength.sources[0].tier == 1)
        #expect(model.baseLength.sources[0].type == .manual)
        #expect(model.magnification.value == 0.91)
    }
}
