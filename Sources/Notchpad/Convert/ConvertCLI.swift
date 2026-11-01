import AppKit

enum ConvertCLI {
    @MainActor
    static func run(path: String, ext: String) {
        let source = URL(fileURLWithPath: path)
        guard let action = Converter.actions(for: source).first(where: { $0.outputExtension == ext }) else {
            print("No \(ext) conversion for \(source.lastPathComponent)")
            exit(2)
        }
        let destination = Converter.destination(for: source, ext: ext)
        Task { @MainActor in
            do {
                try await action.perform(source, destination)
                print("Saved \(destination.path)")
                exit(0)
            } catch {
                print("Failed: \(error.localizedDescription)")
                exit(1)
            }
        }
    }
}
