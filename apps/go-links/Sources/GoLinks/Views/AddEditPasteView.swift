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
        VStack(alignment: .leading, spacing: AppTheme.spacing16) {
            fieldLabel("Title", systemImage: "textformat")

            TextField("Untitled Paste", text: $title)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .body }
                .padding(.horizontal, AppTheme.spacing12)
                .frame(height: 40)
                .background(AppTheme.contentBackground)
                .overlay(inputBorder(hasError: false))

            HStack(spacing: AppTheme.spacing8) {
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
                    .padding(AppTheme.spacing8)

                if content.isEmpty {
                    Text("Paste text, code, notes, or logs")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppTheme.spacing12)
                        .padding(.vertical, AppTheme.spacing16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 250, maxHeight: .infinity)
            .background(AppTheme.contentBackground)
            .overlay(inputBorder(hasError: bodyError != nil))

            HStack(alignment: .firstTextBaseline) {
                if let bodyError {
                    errorText(bodyError)
                }

                Spacer()

                Text("\(content.count) character\(content.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacing16)
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacing8) {
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
        .padding(AppTheme.spacing16)
    }

    private func fieldLabel(_ value: String, systemImage: String) -> some View {
        Label(value, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func inputBorder(hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            .stroke(hasError ? Color.red : AppTheme.separator.opacity(0.3), lineWidth: 1)
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
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
