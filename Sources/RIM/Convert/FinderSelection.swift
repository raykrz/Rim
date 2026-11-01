import Foundation

enum FinderSelection {
    /// Files currently selected in Finder. The first call triggers macOS's Automation permission prompt.
    static func urls() -> Result<[URL], ConvertError> {
        let source = """
        tell application "Finder"
            set out to {}
            repeat with f in (get selection as alias list)
                set end of out to POSIX path of f
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(ConvertError(message: "Couldn't read the Finder selection."))
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            if code == -1743 {
                return .failure(ConvertError(message: "Allow RIM to control Finder in System Settings > Privacy & Security > Automation."))
            }
            return .failure(ConvertError(message: "Couldn't read the Finder selection."))
        }

        var urls: [URL] = []
        if result.numberOfItems > 0 {
            for index in 1...result.numberOfItems {
                if let path = result.atIndex(index)?.stringValue { urls.append(URL(fileURLWithPath: path)) }
            }
        }
        return .success(urls)
    }
}
