import SwiftUI

enum PasteFormMode {
    case add(initialBody: String)
    case edit(PasteItem)

    var submitLabel: String {
        switch self {
        case .add:
            return "Add"
        case .edit:
            return "Save"
        }
    }
}

struct AddEditPasteView: View {
    let mode: PasteFormMode
    let onClose: () -> Void

    @EnvironmentObject private var store: PasteStore

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var bodyError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    init(mode: PasteFormMode, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose

        switch mode {
        case .add(let initialBody):
            _content = State(initialValue: initialBody)
        case .edit(let paste):
            _title = State(initialValue: paste.title)
            _content = State(initialValue: paste.body)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            form
            Spacer(minLength: 0)
            Divider()
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if case .add = mode, content.isEmpty {
                content = Clipboard.string ?? ""
            }
            focusedField = title.isEmpty ? .title : .body
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("Title", systemImage: "textformat")

            TextField("Untitled Paste", text: $title)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .body }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(inputBorder(hasError: false))

            HStack(spacing: 8) {
                fieldLabel("Content", systemImage: "doc.text")

                Spacer()

                Button {
                    content = Clipboard.string ?? ""
                    bodyError = nil
                    focusedField = .body
                } label: {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }
                .font(.caption)
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedField, equals: .body)
                    .onChange(of: content) { _ in bodyError = nil }
                    .padding(6)

                if content.isEmpty {
                    Text("Paste text, code, notes, or logs")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 250, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(inputBorder(hasError: bodyError != nil))

            HStack(alignment: .firstTextBaseline) {
                if let bodyError {
                    errorText(bodyError)
                }

                Spacer()

                Text("\(content.count) character\(content.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                onClose()
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

    private func fieldLabel(_ value: String, systemImage: String) -> some View {
        Label(value, systemImage: systemImage)
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
        bodyError = nil

        do {
            switch mode {
            case .add:
                try store.add(title: title, body: content)
            case .edit(let paste):
                try store.update(paste, title: title, body: content)
            }
            onClose()
        } catch {
            bodyError = error.localizedDescription
            focusedField = .body
        }
    }
}
