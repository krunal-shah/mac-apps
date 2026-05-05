import SwiftUI

enum LinkFormMode {
    case add
    case edit(GoLink)

    var title: String {
        switch self {
        case .add:  return "Add Link"
        case .edit: return "Edit Link"
        }
    }

    var submitLabel: String {
        switch self {
        case .add:  return "Add"
        case .edit: return "Save"
        }
    }

    var linkID: UUID? {
        if case .edit(let link) = self { return link.id }
        return nil
    }
}

struct AddEditLinkView: View {
    let mode: LinkFormMode
    let onClose: () -> Void

    @EnvironmentObject private var store: GoLinkStore

    @State private var shortName: String = ""
    @State private var destinationURL: String = ""
    @State private var nameError: String?
    @State private var urlError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case url
    }

    init(mode: LinkFormMode, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose
        if case .edit(let link) = mode {
            _shortName = State(initialValue: link.shortName)
            _destinationURL = State(initialValue: link.destinationURL)
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
            focusedField = .name
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing20) {
            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                FieldLabel("Shortcut")

                HStack(spacing: 0) {
                    Text("\(AppConfig.hostName)/")
                        .font(AppTheme.mono(14, weight: .regular))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                        .padding(.leading, AppTheme.spacing12)

                    TextField("docs", text: $shortName)
                        .font(AppTheme.mono(14, weight: .medium))
                        .foregroundStyle(AppTheme.shelfInk)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .name)
                        .onChange(of: shortName) { _ in nameError = nil }
                        .onSubmit { focusedField = .url }
                        .padding(.trailing, AppTheme.spacing12)
                }
                .frame(height: 40)
                .background(inputBackground(hasError: nameError != nil))

                if let nameError {
                    errorText(nameError)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                FieldLabel("Destination")

                TextField("https://google.com/search?q={path}", text: $destinationURL)
                    .font(AppTheme.sans(14, weight: .regular))
                    .foregroundStyle(AppTheme.shelfInk)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .url)
                    .onChange(of: destinationURL) { _ in urlError = nil }
                    .onSubmit { submit() }
                    .padding(.horizontal, AppTheme.spacing12)
                    .frame(height: 40)
                    .background(inputBackground(hasError: urlError != nil))

                Text("Use {path} to insert the rest of the URL after the shortcut.")
                    .font(AppTheme.sans(11))
                    .foregroundStyle(AppTheme.shelfInkTertiary)

                if let urlError {
                    errorText(urlError)
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
            onClose()
        } catch GoLinkValidationError.duplicateName {
            nameError = GoLinkValidationError.duplicateName.localizedDescription
        } catch {
            urlError = error.localizedDescription
        }
    }
}

// MARK: - Form button

struct FormButton: View {
    enum Style { case primary, secondary }

    let label: String
    let style: Style
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.sans(12, weight: .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, AppTheme.spacing16)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous).fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppTheme.hoverAnimation) { isHovering = hovering }
        }
    }

    private var textColor: Color {
        AppTheme.shelfInk
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovering ? AppTheme.shelfRuleStrong : AppTheme.shelfAccentSoft
        case .secondary:
            return isHovering ? AppTheme.shelfRule.opacity(0.7) : .clear
        }
    }
}
