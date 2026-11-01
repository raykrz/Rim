import AppKit

struct DocxPage {
    let html: String
    let size: CGSize
    let margins: NSEdgeInsets
}

/// Reads a .docx (a zip of XML) and produces HTML that keeps tables, images, lists, links and basic styling.
/// This covers the common cases; LibreOffice is used instead when it's installed.
enum DocxToHTML {
    static func convert(_ url: URL) throws -> DocxPage {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("rim-docx-" + UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", "-o", url.path, "-d", dir.path]
        unzip.standardOutput = FileHandle.nullDevice
        unzip.standardError = FileHandle.nullDevice
        try unzip.run()
        unzip.waitUntilExit()

        let word = dir.appendingPathComponent("word")
        guard unzip.terminationStatus <= 1,
              let data = try? Data(contentsOf: word.appendingPathComponent("document.xml")),
              let doc = try? XMLDocument(data: data, options: []),
              let body = kid(doc.rootElement(), "w:body")
        else { throw ConvertError(message: "This doesn't look like a valid .docx file.") }

        let walker = DocxWalker(word: word)
        let content = walker.blocks(body)

        let sect = kid(body, "w:sectPr")
        func points(_ element: XMLElement?, _ name: String, _ fallback: CGFloat) -> CGFloat {
            attr(element, name).flatMap { Double($0) }.map { CGFloat($0) / 20 } ?? fallback
        }
        let pgSz = kid(sect, "w:pgSz"), pgMar = kid(sect, "w:pgMar")
        let size = CGSize(width: points(pgSz, "w:w", 595), height: points(pgSz, "w:h", 842))
        let margins = NSEdgeInsets(
            top: points(pgMar, "w:top", 72), left: points(pgMar, "w:left", 72),
            bottom: points(pgMar, "w:bottom", 72), right: points(pgMar, "w:right", 72)
        )

        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        body{margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:11pt;line-height:1.2;color:#000;-webkit-print-color-adjust:exact}
        p{margin:0 0 8pt;white-space:pre-wrap}
        h1,h2,h3,h4,h5,h6{margin:12pt 0 4pt;font-weight:bold;white-space:pre-wrap}
        h1{font-size:20pt}h2{font-size:16pt}h3{font-size:14pt}h4,h5,h6{font-size:12pt}
        td p{margin:0}
        td{overflow-wrap:anywhere}
        img{vertical-align:bottom}
        </style></head><body>\(content)</body></html>
        """
        return DocxPage(html: html, size: size, margins: margins)
    }
}

// MARK: - XML helpers

private func kids(_ element: XMLElement?, _ name: String) -> [XMLElement] {
    (element?.children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == name }
}

private func kid(_ element: XMLElement?, _ name: String) -> XMLElement? {
    kids(element, name).first
}

private func attr(_ element: XMLElement?, _ name: String) -> String? {
    element?.attribute(forName: name)?.stringValue
}

private func descendant(_ element: XMLElement, _ name: String) -> XMLElement? {
    for case let child as XMLElement in element.children ?? [] {
        if child.name == name { return child }
        if let found = descendant(child, name) { return found }
    }
    return nil
}

private func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

/// A toggle element like <w:b/> is on unless its value is "0" or "false".
private func isOn(_ element: XMLElement?) -> Bool {
    guard let element else { return false }
    let value = attr(element, "w:val")
    return value != "0" && value != "false"
}

// MARK: - Walker

private final class DocxWalker {
    let word: URL
    private var relationships: [String: (target: String, external: Bool)] = [:]
    private var numberFormats: [String: [Int: String]] = [:]
    private var styleCSS: [String: [String]] = [:]
    private var styleBase: [String: String] = [:]
    private var counters: [String: [Int: Int]] = [:]

    init(word: URL) {
        self.word = word
        loadRelationships()
        loadNumbering()
        loadStyles()
    }

    private func load(_ relative: String) -> XMLElement? {
        guard let data = try? Data(contentsOf: word.appendingPathComponent(relative)),
              let doc = try? XMLDocument(data: data, options: []) else { return nil }
        return doc.rootElement()
    }

    private func loadRelationships() {
        for rel in kids(load("_rels/document.xml.rels"), "Relationship") {
            guard let id = attr(rel, "Id"), let target = attr(rel, "Target") else { continue }
            relationships[id] = (target, attr(rel, "TargetMode") == "External")
        }
    }

    private func loadNumbering() {
        let root = load("numbering.xml")
        var abstract: [String: [Int: String]] = [:]
        for node in kids(root, "w:abstractNum") {
            guard let id = attr(node, "w:abstractNumId") else { continue }
            var levels: [Int: String] = [:]
            for lvl in kids(node, "w:lvl") {
                if let level = attr(lvl, "w:ilvl").flatMap(Int.init), let fmt = attr(kid(lvl, "w:numFmt"), "w:val") {
                    levels[level] = fmt
                }
            }
            abstract[id] = levels
        }
        for num in kids(root, "w:num") {
            if let id = attr(num, "w:numId"), let abs = attr(kid(num, "w:abstractNumId"), "w:val") {
                numberFormats[id] = abstract[abs]
            }
        }
    }

    private func loadStyles() {
        for style in kids(load("styles.xml"), "w:style") {
            guard let id = attr(style, "w:styleId") else { continue }
            styleCSS[id] = runCSS(kid(style, "w:rPr"))
            if let base = attr(kid(style, "w:basedOn"), "w:val") { styleBase[id] = base }
        }
    }

    private func styleChain(_ id: String) -> [String] {
        guard !id.isEmpty else { return [] }
        var chain: [String] = []
        var current: String? = id
        var guardCount = 0
        while let name = current, guardCount < 8 {
            chain = (styleCSS[name] ?? []) + chain
            current = styleBase[name]
            guardCount += 1
        }
        return chain
    }

    // MARK: Blocks

    func blocks(_ parent: XMLElement?) -> String {
        var html = ""
        for case let child as XMLElement in parent?.children ?? [] {
            switch child.name {
            case "w:p": html += paragraph(child)
            case "w:tbl": html += table(child)
            case "w:sdt": html += blocks(kid(child, "w:sdtContent"))
            default: break
            }
        }
        return html
    }

    private func paragraph(_ p: XMLElement) -> String {
        let pPr = kid(p, "w:pPr")
        let styleID = attr(kid(pPr, "w:pStyle"), "w:val") ?? ""
        var css = styleChain(styleID)

        if let jc = attr(kid(pPr, "w:jc"), "w:val") {
            let map = ["center": "center", "right": "right", "end": "right", "both": "justify", "distribute": "justify"]
            css.append("text-align:" + (map[jc] ?? "left"))
        }

        func twips(_ element: XMLElement?, _ names: [String]) -> Double? {
            for name in names { if let value = attr(element, name).flatMap(Double.init) { return value } }
            return nil
        }

        let ind = kid(pPr, "w:ind")
        let left = twips(ind, ["w:left", "w:start"])
        let firstLine = twips(ind, ["w:firstLine"]) ?? 0
        let hanging = twips(ind, ["w:hanging"]) ?? 0
        if let left { css.append("margin-left:\(Int(left / 15))px") }
        if firstLine != 0 || hanging != 0 { css.append("text-indent:\(Int((firstLine - hanging) / 15))px") }

        if let spacing = kid(pPr, "w:spacing") {
            if let before = twips(spacing, ["w:before"]) { css.append("margin-top:\(before / 20)pt") }
            if let after = twips(spacing, ["w:after"]) { css.append("margin-bottom:\(after / 20)pt") }
        }
        if kid(pPr, "w:pageBreakBefore") != nil { css.append("break-before:page") }

        var marker = ""
        if let numPr = kid(pPr, "w:numPr"), let numId = attr(kid(numPr, "w:numId"), "w:val"), numId != "0" {
            let level = attr(kid(numPr, "w:ilvl"), "w:val").flatMap(Int.init) ?? 0
            marker = listMarker(numId: numId, level: level) + "&ensp;"
            if left == nil {
                css.append("margin-left:\(24 * (level + 1))px")
                css.append("text-indent:-18px")
            }
        }

        let inner = runs(p)
        let lower = styleID.lowercased()
        var tag = "p"
        if lower == "title" { tag = "h1" }
        else if lower.hasPrefix("heading"), let n = Int(lower.dropFirst("heading".count)), (1...6).contains(n) { tag = "h\(n)" }

        let style = css.isEmpty ? "" : " style=\"\(css.joined(separator: ";"))\""
        let content = marker + inner
        return "<\(tag)\(style)>\(content.isEmpty ? "<br>" : content)</\(tag)>"
    }

    private func listMarker(numId: String, level: Int) -> String {
        counters[numId, default: [:]][level, default: 0] += 1
        counters[numId]?.keys.filter { $0 > level }.forEach { counters[numId]?[$0] = nil }
        let n = counters[numId]?[level] ?? 1
        switch numberFormats[numId]?[level] ?? "decimal" {
        case "bullet": return level % 2 == 0 ? "•" : "◦"
        case "lowerLetter": return letters(n).lowercased() + "."
        case "upperLetter": return letters(n) + "."
        default: return "\(n)."
        }
    }

    private func letters(_ n: Int) -> String {
        var number = n, result = ""
        while number > 0 {
            number -= 1
            result = String(UnicodeScalar(UInt8(65 + number % 26))) + result
            number /= 26
        }
        return result
    }

    // MARK: Runs

    private func runs(_ parent: XMLElement) -> String {
        var html = ""
        for case let child as XMLElement in parent.children ?? [] {
            switch child.name {
            case "w:r":
                html += run(child)
            case "w:hyperlink":
                let inner = runs(child)
                if let id = attr(child, "r:id"), let rel = relationships[id], rel.external {
                    html += "<a href=\"\(escape(rel.target))\">\(inner)</a>"
                } else {
                    html += inner
                }
            case "w:ins", "w:smartTag", "w:fldSimple", "w:sdt", "w:sdtContent":
                html += runs(child)
            default:
                break
            }
        }
        return html
    }

    private func run(_ r: XMLElement) -> String {
        let css = runCSS(kid(r, "w:rPr"))
        var inner = ""
        for case let child as XMLElement in r.children ?? [] {
            switch child.name {
            case "w:t": inner += escape(child.stringValue ?? "")
            case "w:tab": inner += "&emsp;"
            case "w:br", "w:cr":
                inner += attr(child, "w:type") == "page" ? "<div style=\"break-after:page\"></div>" : "<br>"
            case "w:noBreakHyphen": inner += "-"
            case "w:drawing", "w:pict": inner += image(in: child)
            case "mc:AlternateContent": inner += image(in: kid(child, "mc:Choice") ?? child)
            default: break
            }
        }
        guard !inner.isEmpty, !css.isEmpty else { return inner }
        return "<span style=\"\(css.joined(separator: ";"))\">\(inner)</span>"
    }

    private func image(in element: XMLElement) -> String {
        guard let blip = descendant(element, "a:blip"),
              let id = attr(blip, "r:embed"),
              let rel = relationships[id], !rel.external else { return "" }

        let file = word.appendingPathComponent(rel.target)
        let mimeTypes = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
                         "bmp": "image/bmp", "tif": "image/tiff", "tiff": "image/tiff"]
        guard let mime = mimeTypes[file.pathExtension.lowercased()], let data = try? Data(contentsOf: file) else { return "" }

        var size = ""
        if let extent = descendant(element, "wp:extent"), let cx = attr(extent, "cx").flatMap(Double.init) {
            size = "width:\(Int(cx / 9525))px;max-width:100%;height:auto"
        } else {
            size = "max-width:100%"
        }
        return "<img src=\"data:\(mime);base64,\(data.base64EncodedString())\" style=\"\(size)\">"
    }

    private func runCSS(_ rPr: XMLElement?) -> [String] {
        guard let rPr else { return [] }
        var css: [String] = []
        if isOn(kid(rPr, "w:b")) { css.append("font-weight:bold") }
        if isOn(kid(rPr, "w:i")) { css.append("font-style:italic") }
        var decorations: [String] = []
        if let u = kid(rPr, "w:u"), attr(u, "w:val") != "none" { decorations.append("underline") }
        if isOn(kid(rPr, "w:strike")) { decorations.append("line-through") }
        if !decorations.isEmpty { css.append("text-decoration:" + decorations.joined(separator: " ")) }
        if let color = attr(kid(rPr, "w:color"), "w:val"), color != "auto" { css.append("color:#\(color)") }
        if let size = attr(kid(rPr, "w:sz"), "w:val").flatMap(Double.init) { css.append("font-size:\(size / 2)pt") }
        if let fonts = kid(rPr, "w:rFonts"), let name = attr(fonts, "w:ascii") ?? attr(fonts, "w:hAnsi") {
            let serif = ["Times", "Cambria", "Georgia", "Garamond", "Palatino", "Book"].contains { name.contains($0) }
            css.append("font-family:'\(name)',\(serif ? "serif" : "Helvetica,Arial,sans-serif")")
        }
        if let highlight = attr(kid(rPr, "w:highlight"), "w:val") {
            let colors = ["yellow": "#ffff00", "green": "#00ff00", "cyan": "#00ffff", "magenta": "#ff00ff",
                          "blue": "#0000ff", "red": "#ff0000", "lightGray": "#d3d3d3"]
            if let value = colors[highlight] { css.append("background:\(value)") }
        }
        switch attr(kid(rPr, "w:vertAlign"), "w:val") {
        case "superscript": css.append("vertical-align:super;font-size:smaller")
        case "subscript": css.append("vertical-align:sub;font-size:smaller")
        default: break
        }
        if isOn(kid(rPr, "w:caps")) { css.append("text-transform:uppercase") }
        if isOn(kid(rPr, "w:smallCaps")) { css.append("font-variant:small-caps") }
        return css
    }

    // MARK: Tables

    private struct Cell {
        let element: XMLElement
        let column: Int
        let span: Int
        let merge: String?
    }

    private func table(_ tbl: XMLElement) -> String {
        let tblPr = kid(tbl, "w:tblPr")
        let styleName = (attr(kid(tblPr, "w:tblStyle"), "w:val") ?? "").lowercased()
        let bordered = kid(tblPr, "w:tblBorders") != nil || styleName.contains("grid")
        let columns = kids(kid(tbl, "w:tblGrid"), "w:gridCol").compactMap { attr($0, "w:w").flatMap(Double.init) }

        let grid: [[Cell]] = kids(tbl, "w:tr").map { tr in
            var column = 0
            var cells: [Cell] = []
            for tc in kids(tr, "w:tc") {
                let tcPr = kid(tc, "w:tcPr")
                let span = attr(kid(tcPr, "w:gridSpan"), "w:val").flatMap(Int.init) ?? 1
                var merge: String?
                if let vMerge = kid(tcPr, "w:vMerge") { merge = attr(vMerge, "w:val") == "restart" ? "restart" : "continue" }
                cells.append(Cell(element: tc, column: column, span: span, merge: merge))
                column += span
            }
            return cells
        }

        var html = "<table style=\"border-collapse:collapse;table-layout:fixed;max-width:100%"
        if !columns.isEmpty { html += ";width:\(Int(columns.reduce(0, +) / 15))px" }
        html += "\">"
        if !columns.isEmpty {
            html += "<colgroup>" + columns.map { "<col style=\"width:\(Int($0 / 15))px\">" }.joined() + "</colgroup>"
        }

        for (rowIndex, row) in grid.enumerated() {
            html += "<tr>"
            for cell in row where cell.merge != "continue" {
                var rowSpan = 1
                if cell.merge == "restart" {
                    var next = rowIndex + 1
                    while next < grid.count, grid[next].contains(where: { $0.column == cell.column && $0.merge == "continue" }) {
                        rowSpan += 1
                        next += 1
                    }
                }
                let tcPr = kid(cell.element, "w:tcPr")
                var css = ["padding:3px 6px", "vertical-align:" + (attr(kid(tcPr, "w:vAlign"), "w:val") == "center" ? "middle" : "top")]
                if bordered { css.append("border:1px solid #000") }
                if let fill = attr(kid(tcPr, "w:shd"), "w:fill"), fill != "auto" { css.append("background:#\(fill)") }
                var attrs = ""
                if cell.span > 1 { attrs += " colspan=\"\(cell.span)\"" }
                if rowSpan > 1 { attrs += " rowspan=\"\(rowSpan)\"" }
                html += "<td\(attrs) style=\"\(css.joined(separator: ";"))\">\(blocks(cell.element))</td>"
            }
            html += "</tr>"
        }
        return html + "</table>"
    }
}
