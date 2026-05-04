import SwiftUI

enum LinkFormMode {
    case add
    case edit(GoLink)

    var title: String {
        switch self {
        case .add:
            return "Add Link"
        case .edit:
            return "Edit Link"
        }
    }

    var submitLabel: String {
        switch self {
        case .add:
            return "Add"
        case .edit:
            return "Save"
        }
    }

    var linkID: UUID? {
        if case .edit(let link) = self { return link.id }
        return nil
    }
}

struct AddEditLinkView: View {
    let mode: LinkFormMode

    @EnvironmentObject private var store: GoLinkStore
    @Environment(\.dismiss) private var dismiss

    @State private var shortName: String = ""
    @State private var destinationURL: String = ""
    @State private var nameError: String?
    @State private var urlError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case url
    }

    init(mode: LinkFormMode) {
        self.mode = mode
        if case .edit(let link) = mode {
            _shortName = State(initialValue: link.shortName)
            _destinationURL = State(initialValue: link.destinationURL)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            actions
        }
        .frame(width: 380)
        .onAppear {
            focusedField = .name
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "link.badge.plus")
                .foregroundColor(.accentColor)
            Text(mode.title)
                .font(.headline)
            Spacer()
        }
        .padding(16)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("Shortcut", systemImage: "textformat")

            HStack(spacing: 0) {
                Text("\(AppConfig.hostName)/")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 44)

                TextField("docs", text: $shortName)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .name)
                    .onChange(of: shortName) { _ in nameError = nil }
                    .onSubmit { focusedField = .url }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(inputBorder(hasError: nameError != nil))

            if let nameError {
                errorText(nameError)
            }

            fieldLabel("Destination", systemImage: "globe")

            TextField("https://example.com", text: $destinationURL)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .url)
                .onChange(of: destinationURL) { _ in urlError = nil }
                .onSubmit { submit() }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(inputBorder(hasError: urlError != nil))

            if let urlError {
                errorText(urlError)
            }
        }
        .padding(16)
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button(mode.submitLabel) {
                submit()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func fieldLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func inputBorder(hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(hasError ? Color.red : Color(NSColor.separatorColor), lineWidth: 1)
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func submit() {
        nameError = nil
        urlError = nil

        do {
            _ = try GoLinkInput.normalizedName(shortName)
        } catch {
            nameError = error.localizedDescription
        }

        do {
            _ = try GoLinkInput.normalizedURL(destinationURL)
        } catch {
            urlError = error.localizedDescription
        }

        guard nameError == nil, urlError == nil else { return }

        do {
            switch mode {
            case .add:
                try store.add(shortName: shortName, destinationURL: destinationURL)
            case .edit(let original):
                var updated = original
                updated.shortName = shortName
                updated.destinationURL = destinationURL
                try store.update(updated)
            }
            dismiss()
        } catch GoLinkValidationError.duplicateName {
            nameError = GoLinkValidationError.duplicateName.localizedDescription
        } catch {
            urlError = error.localizedDescription
        }
    }
}
