import Foundation
import Testing
@testable import RIM

@MainActor @Suite struct ClipboardClassificationTests {
    @Test(arguments: ["Tr0ub4dor&3xK9", "correct-Horse-9-battery", "p@ssW0rd!2024", "aB3$kL9#mQ2"])
    func passwordsAreSecrets(password: String) {
        #expect(ClipboardStore.classify(password) == .secret)
    }

    @Test(arguments: ["sk-abcdefghijklmnop", "ghp_abcdefghijklmnopqrstuvwxyz0123456789", "AKIAIOSFODNN7EXAMPLE", "xoxb-1234-abcd",
                      "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----"])
    func knownTokenPrefixesAreSecrets(token: String) {
        #expect(ClipboardStore.classify(token) == .secret)
    }

    @Test(arguments: [
        #"{"user":{"id":42,"name":"Ray","tags":["dev","mac"]},"ok":true}"#,
        "github.com/raykrz/rim/pull/12",
        "/Users/raykrz/Documents/report-final.pdf",
        "Hello RIM",
        "short",
        "https://example.com/path?x=1&y=2",
        "<div class=\"Box-1\">",
    ])
    func everydayTextIsNotASecret(sample: String) {
        #expect(ClipboardStore.classify(sample) != .secret)
    }

    @Test func linksCodeAndPlainText() {
        #expect(ClipboardStore.classify("https://github.com/raykrz/Rim") == .link)
        #expect(ClipboardStore.classify("const token = await getAuth()") == .code)
        #expect(ClipboardStore.classify("func main() { return }") == .code)
        #expect(ClipboardStore.classify("Meeting at noon") == .text)
    }

    @Test func previewMasksSecretsAndTruncatesLongLines() {
        #expect(ClipItem(text: "hunter2!A", kind: .secret, date: Date()).preview == "••••••••••••")
        let long = ClipItem(text: String(repeating: "a", count: 200), kind: .text, date: Date())
        #expect(long.preview.count == 91)
        #expect(long.preview.hasSuffix("…"))
        #expect(ClipItem(text: "first\nsecond", kind: .text, date: Date()).preview == "first")
    }

    @Test func repeatCopiesCountAsTheSameContent() {
        let a = ClipItem(text: "same", kind: .text, date: Date())
        let b = ClipItem(text: "same", kind: .text, date: Date())
        let c = ClipItem(text: "same", kind: .code, date: Date())
        #expect(a.hasSameContent(as: b))
        #expect(!a.hasSameContent(as: c))
        #expect(a != b)  // identity is by id, not content
    }
}
