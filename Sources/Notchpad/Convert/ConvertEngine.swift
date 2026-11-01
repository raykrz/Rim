import AppKit
import AVFoundation
import PDFKit

struct ConvertAction: Identifiable {
    let title: String
    let outputExtension: String
    let perform: @MainActor (_ source: URL, _ destination: URL) async throws -> Void

    var id: String { title }
}

struct ConvertError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// File conversions built only on tools that ship with macOS (sips, textutil, AVFoundation, PDFKit).
enum Converter {
    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp"]
    private static let documentExts: Set<String> = ["docx", "doc", "rtf", "html", "htm", "txt", "md", "odt"]
    private static let videoExts: Set<String> = ["mov", "mp4", "m4v"]

    static func actions(for url: URL) -> [ConvertAction] {
        let ext = url.pathExtension.lowercased()
        var actions: [ConvertAction] = []

        if imageExts.contains(ext) {
            if !["jpg", "jpeg"].contains(ext) { actions.append(sips("to JPG", ext: "jpg", format: "jpeg")) }
            if ext != "png" { actions.append(sips("to PNG", ext: "png", format: "png")) }
            actions.append(sips("to PDF", ext: "pdf", format: "pdf"))
        }

        if documentExts.contains(ext) {
            if ext != "docx" { actions.append(textutil("to Word", ext: "docx")) }
            if !["txt", "md"].contains(ext) { actions.append(textutil("to Text", ext: "txt")) }
            if !["html", "htm"].contains(ext) { actions.append(textutil("to HTML", ext: "html")) }
            if ext != "rtf" { actions.append(textutil("to RTF", ext: "rtf")) }
            actions.append(ConvertAction(title: "to PDF", outputExtension: "pdf") { src, dst in
                try renderPDF(from: src, to: dst)
            })
        }

        if ext == "pdf" {
            actions.append(ConvertAction(title: "to Text", outputExtension: "txt") { src, dst in
                try pdfText(src).write(to: dst, atomically: true, encoding: .utf8)
            })
            actions.append(ConvertAction(title: "to Word (text only)", outputExtension: "docx") { src, dst in
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
                defer { try? FileManager.default.removeItem(at: temp) }
                try pdfText(src).write(to: temp, atomically: true, encoding: .utf8)
                try await run("/usr/bin/textutil", ["-format", "txt", "-convert", "docx", "-output", dst.path, temp.path])
            })
            actions.append(sips("to PNG (page 1)", ext: "png", format: "png"))
        }

        if videoExts.contains(ext) {
            if ext != "mp4" {
                actions.append(ConvertAction(title: "to MP4", outputExtension: "mp4") { src, dst in
                    try await export(src, to: dst, preset: AVAssetExportPresetHighestQuality, type: .mp4)
                })
            }
            actions.append(ConvertAction(title: "Audio only (M4A)", outputExtension: "m4a") { src, dst in
                try await export(src, to: dst, preset: AVAssetExportPresetAppleM4A, type: .m4a)
            })
        }

        return actions
    }

    /// Next to the source, with " 2", " 3", ... appended if the name is taken.
    static func destination(for source: URL, ext: String) -> URL {
        let dir = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        var candidate = dir.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }

    // MARK: - Backends

    private static func sips(_ title: String, ext: String, format: String) -> ConvertAction {
        ConvertAction(title: title, outputExtension: ext) { src, dst in
            try await run("/usr/bin/sips", ["-s", "format", format, src.path, "--out", dst.path])
        }
    }

    private static func textutil(_ title: String, ext: String) -> ConvertAction {
        ConvertAction(title: title, outputExtension: ext) { src, dst in
            var args: [String] = []
            if ["md", "txt"].contains(src.pathExtension.lowercased()) { args += ["-format", "txt"] }
            args += ["-convert", ext, "-output", dst.path, src.path]
            try await run("/usr/bin/textutil", args)
        }
    }

    private static func pdfText(_ url: URL) throws -> String {
        guard let text = PDFDocument(url: url)?.string, !text.isEmpty else {
            throw ConvertError(message: "No selectable text in this PDF (it may be a scan).")
        }
        return text
    }

    private static func export(_ src: URL, to dst: URL, preset: String, type: AVFileType) async throws {
        let asset = AVURLAsset(url: src)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ConvertError(message: "This file can't be exported on this Mac.")
        }
        session.outputURL = dst
        session.outputFileType = type
        await session.export()
        if let error = session.error { throw ConvertError(message: error.localizedDescription) }
        guard session.status == .completed else { throw ConvertError(message: "Export didn't finish.") }
    }

    /// Paginated A4 PDF from any document type NSAttributedString can read, plus plain text and Markdown.
    @MainActor
    private static func renderPDF(from src: URL, to dst: URL) throws {
        let ext = src.pathExtension.lowercased()
        let content: NSAttributedString
        if ["txt", "md"].contains(ext) {
            let text = try String(contentsOf: src, encoding: .utf8)
            content = NSAttributedString(string: text, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.black,
            ])
        } else {
            content = try NSAttributedString(url: src, options: [:], documentAttributes: nil)
        }

        let page = NSSize(width: 595, height: 842)
        let margin: CGFloat = 54

        let info = NSPrintInfo()
        info.paperSize = page
        info.topMargin = margin; info.bottomMargin = margin
        info.leftMargin = margin; info.rightMargin = margin
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = dst

        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: page.width - margin * 2, height: page.height))
        view.appearance = NSAppearance(named: .aqua)
        view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        view.textStorage?.setAttributedString(content)
        view.sizeToFit()

        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ConvertError(message: "Couldn't create the PDF.") }
    }

    private static func run(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = errors.fileHandleForReading.readDataToEndOfFile()
                    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: ConvertError(message: text.isEmpty ? "Conversion failed." : text))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
