import Foundation

/// Which household member is using the launcher. Sent as the `X-User` header
/// on every Syl request so Syl can attribute the action to the right person.
enum LauncherUser: String, CaseIterable, Identifiable {
    case krunal = "Krunal"
    case aarohi = "Aarohi"

    var id: String { rawValue }
}

@MainActor
final class Identity: ObservableObject {
    private static let key = "syl.launcher.activeUser"

    @Published var activeUser: LauncherUser {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key),
           let user = LauncherUser(rawValue: raw) {
            self.activeUser = user
        } else {
            self.activeUser = .krunal
        }
    }

    private func persist() {
        defaults.set(activeUser.rawValue, forKey: Self.key)
    }
}
