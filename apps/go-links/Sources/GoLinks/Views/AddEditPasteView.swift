import SwiftUI

enum PasteFormMode {
    case add(initialBody: String)
    case edit(PasteItem)

    var submitLabel: String {
        switch self {
        case .add:  return "Add"
        case .edit: return "Save"
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
            Divider().background(AppTheme.shelfRule)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.shelfBase)
        .onAppear {
            if case .add = mode, content.isEmpty {
                content = Clipboard.string ?? ""
            }
            focusedField = title.isEmpty ? .title : .body
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing16) {
            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                FieldLabel("Title")

                TextField("Untitled paste", text: $title)
                    .font(AppTheme.sans(14, weight: .medium))
                    .foregroundStyle(AppTheme.shelfInk)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = .body }
                    .padding(.horizontal, AppTheme.spacing12)
                    .frame(height: 40)
                    .background(inputBackground(hasError: false))
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                HStack(spacing: AppTheme.spacing8) {
                    FieldLabel("Content")

                    Spacer()

                    Button {
                        content = Clipboard.string ?? ""
                        bodyError = nil
                        focusedField = .body
                    } label: {
                        HStack(spacing: AppTheme.spacing4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 10))
                            Text("From clipboard")
                                .font(AppTheme.sans(11, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.shelfInkSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Replace content with the current clipboard")
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .font(AppTheme.mono(12))
                        .foregroundStyle(AppTheme.shelfInk)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .body)
                        .onChange(of: content) { _ in bodyError = nil }
                        .padding(AppTheme.spacing8)

                    if content.isEmpty {
                        Text("Paste text, code, notes, or logs")
                            .font(AppTheme.mono(12))
                            .foregroundStyle(AppTheme.shelfInkTertiary)
                            .padding(.horizontal, AppTheme.spacing12)
                            .padding(.vertical, AppTheme.spacing12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 280, maxHeight: .infinity)
                .background(inputBackground(hasError: bodyError != nil))

                HStack(alignment: .firstTextBaseline) {
                    if let bodyError {
                        errorText(bodyError)
                    }

                    Spacer()

                    Text("\(content.count) characters")
                        .font(AppTheme.sans(11, weight: .regular))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                }
            }
        }
        .padding(AppTheme.spacing20)
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacing8) {
            Spacer()

            FormButton(label: "Cancel", style: .secondary) {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])

            FormButton(label: mode.submitLabel, style: .primary) {
                submit()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(AppTheme.spacing16)
        .background(AppTheme.shelfBase)
    }

    private func inputBackground(hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
            .fill(hasError ? AppTheme.shelfDanger.opacity(0.08) : AppTheme.shelfAccentSoft)
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(AppTheme.sans(11, weight: .medium))
            .foregroundStyle(AppTheme.shelfDanger)
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
