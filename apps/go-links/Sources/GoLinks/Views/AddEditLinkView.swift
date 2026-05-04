import SwiftUI

enum LinkFormMode {
    case add
    case edit(GoLink)

    var title: String {
        switch self {
        case .add:  return "Add Go Link"
        case .edit: return "Edit Go Link"
        }
    }

    var submitLabel: String {
        switch self {
        case .add:  return "Add"
        case .edit: return "Save"
        }
    }
}

struct AddEditLinkView: View {
    let mode: LinkFormMode
    @EnvironmentObject var store: GoLinkStore
    @Environment(\.dismiss) private var dismiss

    @State private var shortName: String = ""
    @State private var destinationURL: String = ""
    @State private var nameError: String?
    @State private var urlError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, url }

    init(mode: LinkFormMode) {
        self.mode = mode
        if case .edit(let link) = mode {
            _shortName = State(initialValue: link.shortName)
            _destinationURL = State(initialValue: link.destinationURL)
        }
    }

    var existingID: UUID? {
        if case .edit(let link) = mode { return link.id }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Short name
                VStack(alignment: .leading, spacing: 4) {
                    Label("Short name", systemImage: "link")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 0) {
                        Text("go/")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color(NSColor.separatorColor)),
                                alignment: .trailing
                            )

                        TextField("mylink", text: $shortName)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .focused($focusedField, equals: .name)
                            .onChange(of: shortName) { _ in nameError = nil }
                            .onSubmit { focusedField = .url }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(nameError != nil ? Color.red : Color(NSColor.separatorColor),
                                    lineWidth: 1)
                    )
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    if let err = nameError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Letters, numbers, hyphens only. No spaces.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Destination URL
                VStack(alignment: .leading, spacing: 4) {
                    Label("Destination URL", systemImage: "globe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("https://example.com", text: $destinationURL)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(urlError != nil ? Color.red : Color(NSColor.separatorColor),
                                        lineWidth: 1)
                        )
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .focused($focusedField, equals: .url)
                        .onChange(of: destinationURL) { _ in urlError = nil }
                        .onSubmit { submit() }

                    if let err = urlError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(16)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(mode.submitLabel) { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 360)
        .onAppear { focusedField = .name }
    }

    // MARK: - Validation & Submit

    private func submit() {
        var valid = true

        // Validate name
        let name = shortName.lowercased().trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            nameError = "Short name is required."
            valid = false
        } else if !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            nameError = "Only letters, numbers, hyphens, and underscores are allowed."
            valid = false
        } else if store.isNameTaken(name, excluding: existingID) {
            nameError = "This short name is already in use."
            valid = false
        }

        // Validate URL
        let rawURL = destinationURL.trimmingCharacters(in: .whitespaces)
        if rawURL.isEmpty {
            urlError = "Destination URL is required."
            valid = false
        } else {
            let withScheme = rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://")
                ? rawURL : "https://" + rawURL
            if URL(string: withScheme) == nil {
                urlError = "Please enter a valid URL."
                valid = false
            }
        }

        guard valid else { return }

        switch mode {
        case .add:
            store.add(shortName: name, destinationURL: rawURL)
        case .edit(let original):
            var updated = original
            updated.shortName = name
            updated.destinationURL = rawURL
            store.update(updated)
        }
        dismiss()
    }
}
