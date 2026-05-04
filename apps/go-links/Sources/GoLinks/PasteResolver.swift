import Foundation

final class PasteResolver {
    private let queue = DispatchQueue(label: "com.golinks.paste-resolver", attributes: .concurrent)
    private var orderedPastes: [PasteItem] = []
    private var pastesByID: [String: PasteItem] = [:]

    func replace(with pastes: [PasteItem]) {
        let ordered = pastes.sorted { $0.updatedAt > $1.updatedAt }
        var indexed: [String: PasteItem] = [:]
        for paste in ordered {
            indexed[paste.id.lowercased()] = paste
        }

        queue.sync(flags: .barrier) {
            orderedPastes = ordered
            pastesByID = indexed
        }
    }

    func snapshot() -> [PasteItem] {
        queue.sync { orderedPastes }
    }

    func paste(id: String) -> PasteItem? {
        queue.sync { pastesByID[id] }
    }
}
