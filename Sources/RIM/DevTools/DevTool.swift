import CryptoKit
import Foundation

struct DevTool: Identifiable {
    let id: String
    let title: String
    let run: (String) throws -> String
}

struct DevToolError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Small text utilities that run on whatever is in the input box (usually your clipboard).
enum DevTools {
    static let all: [DevTool] = [
        DevTool(id: "json", title: "JSON format") { try json($0, pretty: true) },
        DevTool(id: "json-min", title: "JSON minify") { try json($0, pretty: false) },
        DevTool(id: "base64", title: "Base64 encode") { Data($0.utf8).base64EncodedString() },
        DevTool(id: "base64-decode", title: "Base64 decode", run: base64Decode),
        DevTool(id: "url", title: "URL encode", run: urlEncode),
        DevTool(id: "url-decode", title: "URL decode", run: urlDecode),
        DevTool(id: "jwt", title: "JWT decode", run: jwtDecode),
        DevTool(id: "sha256", title: "SHA-256") { hex(SHA256.hash(data: Data($0.utf8))) },
        DevTool(id: "sha1", title: "SHA-1") { hex(Insecure.SHA1.hash(data: Data($0.utf8))) },
        DevTool(id: "md5", title: "MD5") { hex(Insecure.MD5.hash(data: Data($0.utf8))) },
        DevTool(id: "uuid", title: "New UUID") { _ in UUID().uuidString.lowercased() },
        DevTool(id: "epoch", title: "Timestamp", run: epoch),
        DevTool(id: "color", title: "Color", run: color),
        DevTool(id: "snake", title: "snake_case") { words($0).joined(separator: "_") },
        DevTool(id: "kebab", title: "kebab-case") { words($0).joined(separator: "-") },
        DevTool(id: "camel", title: "camelCase") { input in
            words(input).enumerated().map { $0.offset == 0 ? $0.element : $0.element.capitalized }.joined()
        },
    ]

    static func tool(id: String) -> DevTool? { all.first { $0.id == id } }

    // MARK: - JSON

    private static func json(_ input: String, pretty: Bool) throws -> String {
        let object = try parseJSON(input)
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        if pretty { options.insert(.prettyPrinted) }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        let text = String(decoding: data, as: UTF8.self)
        // Foundation prints `"key" : value`; developers expect `"key": value`.
        return pretty ? text.replacingOccurrences(of: "\" : ", with: "\": ") : text
    }

    private static func parseJSON(_ text: String) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch {
            throw DevToolError(message: "That isn't valid JSON.")
        }
    }

    // MARK: - Encoding

    private static func base64Data(_ text: String) -> Data? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    private static func base64Decode(_ input: String) throws -> String {
        guard let data = base64Data(input) else { throw DevToolError(message: "That isn't valid Base64.") }
        guard let text = String(data: data, encoding: .utf8) else {
            throw DevToolError(message: "Decoded to \(data.count) bytes that aren't text.")
        }
        return text
    }

    private static func urlEncode(_ input: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return input.addingPercentEncoding(withAllowedCharacters: allowed) ?? input
    }

    private static func urlDecode(_ input: String) throws -> String {
        guard let text = input.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
            throw DevToolError(message: "That isn't valid percent-encoding.")
        }
        return text
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - JWT

    private static func jwtDecode(_ input: String) throws -> String {
        let parts = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let headerData = base64Data(String(parts[0])), let payloadData = base64Data(String(parts[1])),
              let header = try? JSONSerialization.jsonObject(with: headerData),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) else {
            throw DevToolError(message: "That doesn't look like a JWT.")
        }

        func pretty(_ object: Any) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
            return String(decoding: data, as: UTF8.self)
        }

        var output = "Header\n\(pretty(header))\n\nPayload\n\(pretty(payload))"
        if let claims = payload as? [String: Any] {
            let formatter = ISO8601DateFormatter()
            let times = ["iat": "issued", "nbf": "not before", "exp": "expires"].sorted { $0.key < $1.key }.compactMap { key, label -> String? in
                guard let seconds = (claims[key] as? NSNumber)?.doubleValue else { return nil }
                let date = Date(timeIntervalSince1970: seconds)
                let state = key == "exp" ? (date < Date() ? " (expired)" : " (valid)") : ""
                return "\(label): \(formatter.string(from: date))\(state)"
            }
            if !times.isEmpty { output += "\n\n" + times.joined(separator: "\n") }
        }
        return output
    }

    // MARK: - Time

    private static func epoch(_ input: String) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()

        func describe(_ date: Date) -> String {
            let seconds = Int(date.timeIntervalSince1970)
            let local = DateFormatter()
            local.dateStyle = .full
            local.timeStyle = .long
            return "seconds: \(seconds)\nmilliseconds: \(seconds * 1000)\nUTC: \(iso.string(from: date))\nlocal: \(local.string(from: date))"
        }

        if text.isEmpty { return describe(Date()) }
        if let number = Double(text) {
            let seconds = abs(number) > 100_000_000_000 ? number / 1000 : number
            return describe(Date(timeIntervalSince1970: seconds))
        }
        if let date = iso.date(from: text) { return describe(date) }

        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd"]
        for format in formats {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = format
            if let date = parser.date(from: text) { return describe(date) }
        }
        throw DevToolError(message: "Enter a Unix timestamp or a date like 2026-11-01 14:30.")
    }

    // MARK: - Color

    private static func color(_ input: String) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var rgb: (Int, Int, Int)?

        let hexDigits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        if [3, 6].contains(hexDigits.count), hexDigits.allSatisfy(\.isHexDigit) {
            let full = hexDigits.count == 3 ? hexDigits.map { "\($0)\($0)" }.joined() : hexDigits
            let value = Int(full, radix: 16) ?? 0
            rgb = (value >> 16 & 255, value >> 8 & 255, value & 255)
        } else if text.hasPrefix("rgb") {
            let numbers = text.split { !$0.isNumber }.compactMap { Int($0) }
            if numbers.count >= 3, numbers.prefix(3).allSatisfy({ (0...255).contains($0) }) {
                rgb = (numbers[0], numbers[1], numbers[2])
            }
        }
        guard let (r, g, b) = rgb else { throw DevToolError(message: "Enter a color like #ff8800 or rgb(255, 136, 0).") }

        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let maxC = max(rf, gf, bf), minC = min(rf, gf, bf), delta = maxC - minC
        let lightness = (maxC + minC) / 2
        var hue = 0.0, saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            if maxC == rf { hue = 60 * ((gf - bf) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == gf { hue = 60 * ((bf - rf) / delta + 2) }
            else { hue = 60 * ((rf - gf) / delta + 4) }
            if hue < 0 { hue += 360 }
        }
        return String(format: "#%02x%02x%02x\nrgb(%d, %d, %d)\nhsl(%d, %d%%, %d%%)",
                      r, g, b, r, g, b, Int(hue.rounded()), Int((saturation * 100).rounded()), Int((lightness * 100).rounded()))
    }

    // MARK: - Case

    /// Splits camelCase, snake_case, kebab-case and spaced text into lowercase words.
    private static func words(_ input: String) -> [String] {
        var spaced = ""
        var previous: Character?
        for character in input {
            if let previous, character.isUppercase, previous.isLowercase || previous.isNumber { spaced.append(" ") }
            spaced.append(character)
            previous = character
        }
        return spaced.split { !$0.isLetter && !$0.isNumber }.map { $0.lowercased() }
    }
}
