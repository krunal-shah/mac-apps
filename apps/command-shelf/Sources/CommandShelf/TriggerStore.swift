import Foundation

@MainActor
final class TriggerStore: ObservableObject {
    @Published private(set) var triggers: [TriggerDefinition] = []
    @Published private(set) var lastLoadError: String?

    let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? TriggerStore.defaultURL()
        bootstrapIfNeeded()
        reload()
    }

    /// `~/Documents/K_and_A/Launcher/triggers.json`
    static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("K_and_A", isDirectory: true)
            .appendingPathComponent("Launcher", isDirectory: true)
            .appendingPathComponent("triggers.json", isDirectory: false)
    }

    /// Re-read from disk. Called on each palette open so vault edits in Obsidian
    /// show up immediately without restarting Command Shelf.
    func reload() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                triggers = []
                lastLoadError = "triggers.json not found at \(fileURL.path)"
                return
            }
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let parsed = try decoder.decode(TriggerFile.self, from: data)
            triggers = parsed.triggers
            lastLoadError = nil
        } catch {
            triggers = []
            lastLoadError = "Failed to load triggers: \(error.localizedDescription)"
            NSLog("[CommandShelf] %@", lastLoadError ?? "")
        }
    }

    // MARK: - First-run seeding

    /// If the vault path doesn't have a triggers.json yet, drop the bundled seed
    /// in place so the launcher works out of the box. Existing files are left
    /// untouched — user edits in Obsidian are sacred.
    private func bootstrapIfNeeded() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            guard let seedData = TriggerSeed.defaultJSON.data(using: .utf8) else { return }
            try seedData.write(to: fileURL, options: .atomic)
            NSLog("[CommandShelf] Seeded triggers.json at %@", fileURL.path)
        } catch {
            NSLog("[CommandShelf] Failed to seed triggers.json: %@", error.localizedDescription)
        }
    }
}

/// Default trigger set baked into the binary, written to disk on first run.
enum TriggerSeed {
    static let defaultJSON: String = """
    {
      "triggers": [
        {
          "keyword": "linear",
          "label": "Linear — draft ticket",
          "description": "Draft a Linear ticket from a short note.",
          "prompt": "Draft a Linear ticket with a clear title and description.\\n\\nContext:\\n{input}\\n\\nFormat as:\\nTitle: <succinct>\\nDescription:\\n<details>",
          "action": { "type": "clipboard" }
        },
        {
          "keyword": "ask",
          "label": "Ask Claude",
          "description": "Inline answer streamed into the palette.",
          "prompt": "{input}",
          "action": { "type": "stream_inline", "context": "general" }
        },
        {
          "keyword": "read",
          "label": "Reading — add to inbox",
          "description": "Add a URL or title to the Syl reading inbox.",
          "action": {
            "type": "syl_api",
            "method": "POST",
            "endpoint": "/api/reading/inbox",
            "body": { "text": "{input}" }
          }
        },
        {
          "keyword": "todo",
          "label": "Todo — quick capture",
          "description": "Capture a todo straight into Syl.",
          "action": {
            "type": "syl_api",
            "method": "POST",
            "endpoint": "/api/todos",
            "body": { "text": "{input}" }
          }
        },
        {
          "keyword": "note",
          "label": "Note — append to Home.md",
          "description": "Append a stray note to the vault quick capture.",
          "action": {
            "type": "syl_api",
            "method": "POST",
            "endpoint": "/api/vault/append",
            "body": { "path": "Home.md", "text": "{input}" }
          }
        },
        {
          "keyword": "recipe",
          "label": "Recipe — weeknight pick",
          "description": "Suggest a recipe from your library for a meal slot.",
          "prompt": "Pick a weeknight recipe from our household library that fits this slot:\\n\\n{input}\\n\\nReturn one recipe name with a one-line reason.",
          "action": { "type": "clipboard" }
        }
      ]
    }
    """
}
