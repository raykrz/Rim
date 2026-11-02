import Foundation
import Testing
@testable import RIM

@MainActor @Suite struct ConverterTests {
    private func titles(_ name: String) -> [String] {
        Converter.actions(for: URL(fileURLWithPath: "/tmp/\(name)")).map(\.title)
    }

    @Test func imagesOfferOnlyOtherFormats() {
        #expect(titles("photo.heic") == ["to JPG", "to PNG", "to PDF"])
        #expect(titles("photo.png") == ["to JPG", "to PDF"])
        #expect(titles("photo.jpg") == ["to PNG", "to PDF"])
    }

    @Test func documentsOfferWordAndPDFButNotThemselves() {
        let docx = titles("report.docx")
        #expect(!docx.contains("to Word"))
        #expect(docx.contains("to PDF"))
        #expect(titles("notes.md").contains("to Word"))
        #expect(!titles("notes.txt").contains("to Text"))
    }

    @Test func pdfOffersBothWordModes() {
        let pdf = titles("paper.pdf")
        #expect(pdf.contains("to Word (editable text)"))
        #expect(pdf.contains("to Word (exact look)"))
        #expect(pdf.contains("to Text"))
    }

    @Test func videoOffersMP4OnlyForMOV() {
        #expect(titles("clip.mov").contains("to MP4"))
        #expect(!titles("clip.mp4").contains("to MP4"))
        #expect(titles("clip.mp4").contains("Audio only (M4A)"))
    }

    @Test func unknownTypesHaveNoActions() {
        #expect(titles("archive.zip").isEmpty)
        #expect(titles("noextension").isEmpty)
    }

    @Test func destinationNeverOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rim-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("report.docx")
        #expect(Converter.destination(for: source, ext: "pdf").lastPathComponent == "report.pdf")

        FileManager.default.createFile(atPath: dir.appendingPathComponent("report.pdf").path, contents: Data())
        #expect(Converter.destination(for: source, ext: "pdf").lastPathComponent == "report 2.pdf")

        FileManager.default.createFile(atPath: dir.appendingPathComponent("report 2.pdf").path, contents: Data())
        #expect(Converter.destination(for: source, ext: "pdf").lastPathComponent == "report 3.pdf")
    }
}
