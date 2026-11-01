import Foundation

/// Optional high-fidelity engine. Used for Word and PDF when LibreOffice is installed.
enum LibreOffice {
    static var executable: URL? {
        [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/soffice",
            "/usr/local/bin/soffice",
        ]
        .map { URL(fileURLWithPath: $0) }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var isInstalled: Bool { executable != nil }

    /// Converts `source` and moves the result to `destination`.
    /// `target` is soffice's filter string, such as "pdf" or "docx:MS Word 2007 XML".
    static func convert(_ source: URL, to destination: URL, target: String, importFilter: String? = nil) async throws {
        guard let soffice = executable else { throw ConvertError(message: "LibreOffice isn't installed.") }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("rim-lo-" + UUID().uuidString)
        let profile = fm.temporaryDirectory.appendingPathComponent("rim-lo-profile")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        var arguments = ["--headless", "-env:UserInstallation=file://\(profile.path)"]
        if let importFilter { arguments.append("--infilter=\(importFilter)") }
        arguments += ["--convert-to", target, "--outdir", work.path, source.path]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = soffice
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ConvertError(message: "LibreOffice couldn't convert this file."))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }

        let produced = try fm.contentsOfDirectory(at: work, includingPropertiesForKeys: nil).first
        guard let produced else { throw ConvertError(message: "LibreOffice didn't produce a file.") }
        try fm.moveItem(at: produced, to: destination)
    }
}
