import AppKit
import PDFKit

enum PDFToWord {
    // MARK: Editable text

    /// Text with bold, italic and sizes kept, and lines re-joined into paragraphs.
    /// Images and table layout aren't recovered; use `exactLook` or LibreOffice for those.
    static func editable(from source: URL, to destination: URL) throws {
        guard let pdf = PDFDocument(url: source) else { throw ConvertError(message: "Couldn't open this PDF.") }

        let result = NSMutableAttributedString()
        for index in 0..<pdf.pageCount {
            guard let text = pdf.page(at: index)?.attributedString, text.length > 0 else { continue }
            let page = NSMutableAttributedString(attributedString: text)
            normalizeFonts(page)
            reflow(page)
            if result.length > 0 { result.append(NSAttributedString(string: "\n\n")) }
            result.append(page)
        }
        guard !result.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConvertError(message: "No selectable text in this PDF (it may be a scan). Try \"exact look\".")
        }

        let data = try result.data(
            from: NSRange(location: 0, length: result.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try data.write(to: destination)
    }

    /// PDF fonts are often embedded subsets that Word can't find, so keep size and style but use Arial.
    private static func normalizeFonts(_ text: NSMutableAttributedString) {
        let manager = NSFontManager.shared
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let font = value as? NSFont else { return }
            var replacement = NSFont(name: "Arial", size: max(font.pointSize, 6)) ?? NSFont.systemFont(ofSize: font.pointSize)
            let traits = font.fontDescriptor.symbolicTraits
            if traits.contains(.bold) { replacement = manager.convert(replacement, toHaveTrait: .boldFontMask) }
            if traits.contains(.italic) { replacement = manager.convert(replacement, toHaveTrait: .italicFontMask) }
            text.addAttribute(.font, value: replacement, range: range)
        }
        text.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: text.length))
    }

    /// PDFs break text at every visual line. Join lines that continue the same paragraph.
    private static func reflow(_ text: NSMutableAttributedString) {
        let ns = text.string as NSString
        var joins: [(newline: NSRange, dehyphenate: Bool)] = []

        var lineStart = 0
        while lineStart < ns.length {
            var lineEnd = 0, contentsEnd = 0
            ns.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))
            defer { lineStart = lineEnd }
            guard lineEnd > contentsEnd, lineEnd < ns.length else { continue }

            var nextEnd = 0, nextContentsEnd = 0
            ns.getLineStart(nil, end: &nextEnd, contentsEnd: &nextContentsEnd, for: NSRange(location: lineEnd, length: 0))

            let line = ns.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart)).trimmingCharacters(in: .whitespaces)
            let next = ns.substring(with: NSRange(location: lineEnd, length: nextContentsEnd - lineEnd)).trimmingCharacters(in: .whitespaces)
            guard let last = line.last, let first = next.first else { continue }

            let sizeNow = (text.attribute(.font, at: lineStart, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
            let sizeNext = (text.attribute(.font, at: lineEnd, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
            guard abs(sizeNow - sizeNext) < 1.5 else { continue }

            let hyphenated = last == "-" && line.count > 1 && first.isLowercase
            let endsSentence = ".:;!?\"”)".contains(last)
            if hyphenated || (!endsSentence && first.isLowercase) {
                joins.append((NSRange(location: contentsEnd, length: lineEnd - contentsEnd), hyphenated))
            }
        }

        for join in joins.reversed() {
            if join.dehyphenate {
                text.deleteCharacters(in: NSRange(location: join.newline.location - 1, length: join.newline.length + 1))
            } else {
                text.replaceCharacters(in: join.newline, with: " ")
            }
        }
    }

    // MARK: Exact look

    /// One full-page picture per PDF page inside a .docx. Looks identical, but isn't editable text.
    static func exactLook(from source: URL, to destination: URL) throws {
        guard let pdf = PDFDocument(url: source), pdf.pageCount > 0, let first = pdf.page(at: 0) else {
            throw ConvertError(message: "Couldn't open this PDF.")
        }

        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("notchpad-pdf-" + UUID().uuidString)
        try fm.createDirectory(at: dir.appendingPathComponent("word/media"), withIntermediateDirectories: true)
        try fm.createDirectory(at: dir.appendingPathComponent("word/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: dir.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let pageBox = first.bounds(for: .mediaBox)
        let pageWidth = pageBox.width, pageHeight = pageBox.height

        var relationships = ""
        var paragraphs = ""
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let box = page.bounds(for: .mediaBox)
            let image = page.thumbnail(of: NSSize(width: box.width * 2, height: box.height * 2), for: .mediaBox)
            guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                throw ConvertError(message: "Couldn't render page \(index + 1).")
            }
            try png.write(to: dir.appendingPathComponent("word/media/page\(index + 1).png"))

            // Slightly smaller than the page so Word doesn't spill onto an extra blank page.
            let scale = min(pageWidth / box.width, pageHeight / box.height) * 0.97
            let cx = Int(box.width * scale * 12700), cy = Int(box.height * scale * 12700)
            let id = index + 1
            relationships += "<Relationship Id=\"rId\(id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/page\(id).png\"/>"
            let pageBreak = index < pdf.pageCount - 1 ? "<w:r><w:br w:type=\"page\"/></w:r>" : ""
            paragraphs += """
            <w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr><w:r><w:drawing>\
            <wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="\(cx)" cy="\(cy)"/><wp:docPr id="\(id)" name="Page \(id)"/>\
            <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic>\
            <pic:nvPicPr><pic:cNvPr id="\(id)" name="page\(id).png"/><pic:cNvPicPr/></pic:nvPicPr>\
            <pic:blipFill><a:blip r:embed="rId\(id)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>\
            <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>\
            </pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>\(pageBreak)</w:p>
            """
        }

        let document = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" \
        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>\(paragraphs)\
        <w:sectPr><w:pgSz w:w="\(Int(pageWidth * 20))" w:h="\(Int(pageHeight * 20))"/>\
        <w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr></w:body></w:document>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/>\
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
        """
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
        """
        let documentRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(relationships)</Relationships>
        """

        try contentTypes.write(to: dir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rootRels.write(to: dir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try document.write(to: dir.appendingPathComponent("word/document.xml"), atomically: true, encoding: .utf8)
        try documentRels.write(to: dir.appendingPathComponent("word/_rels/document.xml.rels"), atomically: true, encoding: .utf8)

        try? fm.removeItem(at: destination)
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = dir
        zip.arguments = ["-X", "-q", "-r", destination.path, "[Content_Types].xml", "_rels", "word"]
        zip.standardOutput = FileHandle.nullDevice
        try zip.run()
        zip.waitUntilExit()
        guard zip.terminationStatus == 0 else { throw ConvertError(message: "Couldn't package the Word file.") }
    }
}
