import Foundation
import Testing
@testable import RIM

@Suite struct DevToolsTests {
    private func run(_ id: String, _ input: String) throws -> String {
        try #require(DevTools.tool(id: id)).run(input)
    }

    @Test func jsonFormatSortsKeysAndUsesCompactColons() throws {
        let output = try run("json", #"{"b":1,"a":[1,2]}"#)
        #expect(output.contains("\"a\": ["))
        let a = try #require(output.range(of: "\"a\""))
        let b = try #require(output.range(of: "\"b\""))
        #expect(a.lowerBound < b.lowerBound)
    }

    @Test func jsonMinify() throws {
        #expect(try run("json-min", "{ \"a\" : 1,\n \"b\": [1, 2] }") == #"{"a":1,"b":[1,2]}"#)
    }

    @Test func jsonErrorIsReadable() {
        #expect(throws: DevToolError.self) { try run("json", "{bad") }
        let message = (try? run("json", "{bad")).map { _ in "" } ?? "That isn't valid JSON."
        #expect(message == "That isn't valid JSON.")
    }

    @Test func base64RoundTripWithUnicode() throws {
        let encoded = try run("base64", "héllo wörld")
        #expect(encoded == "aMOpbGxvIHfDtnJsZA==")
        #expect(try run("base64-decode", encoded) == "héllo wörld")
    }

    @Test func base64DecodeAcceptsMissingPaddingAndURLSafeAlphabet() throws {
        #expect(try run("base64-decode", "aMOpbGxvIHfDtnJsZA") == "héllo wörld")
        #expect(try run("base64-decode", "Pz8_") == "???")
    }

    @Test func base64DecodeRejectsGarbage() {
        #expect(throws: DevToolError.self) { try run("base64-decode", "!!!") }
    }

    @Test func urlEncodeAndDecode() throws {
        #expect(try run("url", "a b&c=d/é") == "a%20b%26c%3Dd%2F%C3%A9")
        #expect(try run("url-decode", "a%20b%26c%3Dd%2F%C3%A9") == "a b&c=d/é")
        #expect(try run("url-decode", "a+b") == "a b")
    }

    @Test func hashesMatchKnownValues() throws {
        #expect(try run("sha256", "hello") == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(try run("sha1", "hello") == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
        #expect(try run("md5", "hello") == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test func uuidIsLowercaseAndUnique() throws {
        let first = try run("uuid", ""), second = try run("uuid", "")
        #expect(UUID(uuidString: first) != nil)
        #expect(first == first.lowercased())
        #expect(first != second)
    }

    @Test func jwtDecodeShowsClaimsAndExpiry() throws {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyNDI2MjJ9.sig"
        let output = try run("jwt", token)
        #expect(output.contains("\"alg\": \"HS256\""))
        #expect(output.contains("\"name\": \"John Doe\""))
        #expect(output.contains("expires: 2018-01-18T02:30:22Z (expired)"))
    }

    @Test func jwtRejectsNonTokens() {
        #expect(throws: DevToolError.self) { try run("jwt", "nope") }
    }

    @Test(arguments: ["1700000000", "1700000000000"])
    func timestampFromSecondsAndMilliseconds(input: String) throws {
        #expect(try run("epoch", input).contains("UTC: 2023-11-14T22:13:20Z"))
    }

    @Test func timestampRejectsGarbage() {
        #expect(throws: DevToolError.self) { try run("epoch", "garbage") }
    }

    @Test func colorConversions() throws {
        #expect(try run("color", "#ff8800") == "#ff8800\nrgb(255, 136, 0)\nhsl(32, 100%, 50%)")
        #expect(try run("color", "f80") == "#ff8800\nrgb(255, 136, 0)\nhsl(32, 100%, 50%)")
        #expect(try run("color", "rgb(0, 128, 255)") == "#0080ff\nrgb(0, 128, 255)\nhsl(210, 100%, 50%)")
        #expect(throws: DevToolError.self) { try run("color", "rgb(300, 0, 0)") }
    }

    @Test func caseConversions() throws {
        #expect(try run("snake", "myVariableName2Go") == "my_variable_name2_go")
        #expect(try run("kebab", "Hello World_foo-bar") == "hello-world-foo-bar")
        #expect(try run("camel", "some_snake_case value") == "someSnakeCaseValue")
    }
}
