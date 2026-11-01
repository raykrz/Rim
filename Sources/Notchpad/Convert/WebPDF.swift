import AppKit
import WebKit

/// Prints HTML to a paginated PDF with WebKit.
@MainActor
final class WebPDF: NSObject, WKNavigationDelegate {
    private var loaded: CheckedContinuation<Void, Error>?
    private var printed: CheckedContinuation<Bool, Never>?

    enum Source {
        case html(String)
        case file(URL)
    }

    static func render(_ source: Source, pageSize: CGSize, margins: NSEdgeInsets, to destination: URL) async throws {
        try await WebPDF().run(source, pageSize: pageSize, margins: margins, to: destination)
    }

    private func run(_ source: Source, pageSize: CGSize, margins: NSEdgeInsets, to destination: URL) async throws {
        let printable = NSSize(
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )

        let web = WKWebView(frame: NSRect(origin: .zero, size: printable))
        web.navigationDelegate = self
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: printable), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = web

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loaded = continuation
            switch source {
            case .html(let html): web.loadHTMLString(html, baseURL: nil)
            case .file(let url): web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
        }
        // Give images and layout a moment to settle before printing.
        try await Task.sleep(nanoseconds: 300_000_000)

        let info = NSPrintInfo()
        info.paperSize = pageSize
        info.topMargin = margins.top; info.bottomMargin = margins.bottom
        info.leftMargin = margins.left; info.rightMargin = margins.right
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destination

        let operation = web.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = NSRect(origin: .zero, size: printable)

        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            printed = continuation
            operation.runModal(for: window, delegate: self, didRun: #selector(printFinished(_:success:contextInfo:)), contextInfo: nil)
        }
        guard success, FileManager.default.fileExists(atPath: destination.path) else {
            throw ConvertError(message: "Couldn't create the PDF.")
        }
    }

    @objc private func printFinished(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        printed?.resume(returning: success)
        printed = nil
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            loaded?.resume()
            loaded = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loaded?.resume(throwing: error)
            loaded = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loaded?.resume(throwing: error)
            loaded = nil
        }
    }
}
