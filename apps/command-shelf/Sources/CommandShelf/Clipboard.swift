import AppKit

enum Clipboard {
    static var string: String? {
        NSPasteboard.general.string(forType: .string)
    }

    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
