# Command Shelf — Interface System

A macOS menu bar app for keyboard-first power users. Two tools today (Pastes, Links) plus Setup, all reachable from a left rail. Identity: a workshop shelf — labeled, dense, light, mono.

## Direction & feel

- **Workshop shelf, not dashboard.** Items rest on a flat surface; there are no cards. Hairlines, not borders, divide rows.
- **Pure neutral paper & ink.** Light mode only (`.preferredColorScheme(.light)` on the menu bar root). Achromatic — cool neutral paper surfaces and cool charcoal ink hierarchy. No chromatic accent: the "accent" role is filled by ink itself layered as soft and edge tints. Status colors (red/amber/green) are the only chroma in the system, used semantically only.
- **Google Sans is the voice.** The whole interface speaks in Google Sans. Mono parts (paste titles, link short names, eyebrow labels, kbd glyphs) prefer Google Sans Mono *if it's installed*, otherwise they fall back to Google Sans proportional rather than SF Mono — keeping the voice unified. Use `AppTheme.mono(size, weight:)` for "name-of-a-thing" / label-tape text and `AppTheme.sans(size, weight:)` for prose text. Never use raw `.font(.system(...))` on Text views.
- **Keyboard is the primary input.** Every list view supports `↑↓` navigation, `↵` for the canonical action, `⌘⌫` to delete. Mouse hover reveals secondary affordances; mouse is never required.
- **Density.** Rows are tight (~36–44px). The window is 540×680. The rail is 52px.

## Depth strategy

**Borders-only with subtle surface tints.** No drop shadows on inline UI (the floating preview panel is the lone exception). Hierarchy comes from:
1. Color shifts between `shelfBase` (default), `shelfRail` (rail/footer), `shelfPaper` (content/inputs), `shelfHighlight` (selected/hovered rows).
2. Hairline separators in `shelfRule` (1px, ~10% black).
3. A 2px copper bar on the leading edge of the selected row.

## Spacing

Base unit **4pt**. Scale: 2, 4, 6, 8, 10, 12, 16, 20. Available as `AppTheme.spacing4`…`spacing20`.

## Radii

`radiusSmall: 4` (kbd glyph, micro chips), `radiusMedium: 6` (inputs, rail items, buttons), `radiusLarge: 8` (preview panel). No 10+px radii — they read too friendly for the workshop tone.

## Tokens

All defined in `AppTheme` in `apps/go-links/Sources/GoLinks/Views/SharedToolViews.swift`. Never use raw `NSColor.*` or hex literals in views — only `shelf*` tokens.

| Token | Role |
|---|---|
| `shelfBase` | Window background, headers, action rows (cool pale paper) |
| `shelfRail` | Left rail and footer (slightly darker neutral with cool tilt) |
| `shelfTape` | Slightly raised surface (preview header, brand mark) |
| `shelfPaper` | Content surfaces — list bg, inputs, search field (near-white, cool) |
| `shelfHighlight` | Selected/hovered row background (cool blue-tinted) |
| `shelfRule` / `shelfRuleStrong` | Borders & separators (charcoal at 9% / 18%) |
| `shelfInk` → `…Secondary` → `…Tertiary` → `…Muted` | 4-level cool charcoal text hierarchy |
| `shelfAccent` | Solo accent — active rail tab, kbd-glyph prominent state, primary CTAs (deep ink-blue) |
| `shelfAccentSoft` / `shelfAccentEdge` | Accent tints for fills/borders |
| `shelfReady` / `shelfWarn` / `shelfDanger` | Status only — never decorative |

## Typography

- **`AppTheme.mono(size, weight:)`** — primary helper. Resolves to Google Sans Mono if installed; otherwise Google Sans proportional. Use for any *name of a thing*: identifiers, titles, search input, tool labels, eyebrow labels.
- **`AppTheme.sans(size, weight:)`** — Google Sans proportional. Use for prose, error text, helper text, and StatusRow titles in setup.
- `AppTheme.labelMono` and `AppTheme.chrome` are kept as legacy aliases for `mono` / `sans`.
- **Eyebrow labels** are mono 9pt semibold, `tracking(0.8)`, uppercased — produced by the `FieldLabel` component.
- **Kbd glyphs** are mono 9.5pt semibold inside `KbdGlyph`.
- Body text in lists is 12pt mono medium. Detail text drops to 10pt mono and `shelfInkSecondary`.
- Image SF Symbols may keep `.font(.system(size:weight:))` — those calls control symbol scale, not typeface, and don't belong to the Google Sans rule.

## Component patterns

### `RailItem` (`SharedToolViews.swift`)
The left rail tool button. 44pt tall, icon + uppercase mono label below. Active state: `shelfAccentSoft` fill + `shelfAccentEdge` 0.5pt stroke + accent icon + ink label.

### `KbdGlyph` (`SharedToolViews.swift`)
A mini keycap. Used everywhere a keyboard shortcut is mentioned (footer hints, focus-revealed row actions). `prominent: true` paints it in the accent color. Always pair with a lowercase label like `"copy"` (rendered uppercase by the component).

### `FieldLabel` (`SharedToolViews.swift`)
The eyebrow above a section or input. Optional SF Symbol leading. Use for any "this is a thing called X" moment in chrome.

### `FormButton` (`AddEditLinkView.swift`)
The only button style for action rows. `style: .primary` is accent-tinted; `.secondary` is ink-on-clear. Mono uppercase label, 28pt height. Prefer this over `.borderedProminent`.

### `ToolIconButton` (`SharedToolViews.swift`)
Square 24/28pt icon button. Hover bg is `shelfRule`. Pass an explicit `tint` for state (`shelfAccent` for primary, `shelfDanger` for delete).

### List rows (`PasteRow`, `GoLinkRow`)
Pattern for any new tool list:
1. **Slug** — small SF Symbol on the left, ink-tertiary normally, copper on focus.
2. **Title** in `labelMono(12, weight: .medium)`.
3. **Trailing area** swaps based on focus:
   - Default: tiny mono uppercase relative-time stamp.
   - `isFocused` (= selected OR hovered): `KbdGlyph` chips for keyboard actions.
   - `isHovering` only: pencil/trash `ToolIconButton`s appear inline.
4. **Background** picks from `shelfHighlight` (selected), `shelfHighlight.opacity(0.5)` (hovered), or `.clear`.
5. **Selection edge** — a 2pt wide `shelfAccent` rectangle on the leading edge.
6. Rows separated by 0.5pt `shelfRule` rectangles, **not** `Divider()`. Indent the separator past the slug column.

### Tool view skeleton
Every tool view (`PastesToolView`, `LinksToolView`) follows:
```
VStack(spacing: 0) {
    listControls           // search + maybe (+) action, height 40
    Divider() background shelfRule
    content                // ScrollView of rows on shelfPaper
    Divider() background shelfRule
    footer                 // KbdGlyph hints + StatusDot + count, height 28, bg shelfRail
}
```
No header inside the tool view — the rail is the navigation. Use `FieldLabel` next to the search field if you need to name the tool.

### Keyboard handler shape
Use `KeyboardCaptureView` with a `focusToken` that bumps when the menu reopens or selection changes. Standard mappings:
- 123/124 left/right: `onSwitchTool(±1)`
- 125/126 down/up: `moveSelection(by: ±1)`
- 36/76 return: canonical action (copy / open)
- 49 space: secondary (preview)
- 51 backspace: search edit; with `.command` modifier → delete row
- 117 forward delete: delete row
- 53 esc: dismiss overlay → clear search → fall through to system

## Anti-patterns (do not reintroduce)

- ❌ `Color(NSColor.windowBackgroundColor)` etc. — use `shelf*` tokens.
- ❌ `.font(.headline)` / `.body` / `.caption` — be explicit about size, weight, design.
- ❌ `.font(.system(size:..., design: .monospaced))` on a Text view — call `AppTheme.mono(...)` instead so Google Sans wins.
- ❌ Always-visible row action buttons with fixed-width gutter. Actions are focus/hover-revealed.
- ❌ Bordered cards per row. Use flat rows with hairline separators.
- ❌ Multiple accent colors. Ink-blue alone via `shelfAccent`.
- ❌ Drop shadows on inline UI. Layered borders + surface tints only. (Floating panels can have one soft shadow.)
- ❌ `Divider()` for primary separators inside content lists — use a 0.5pt `Rectangle().fill(shelfRule)` so weight matches the design.
- ❌ Adding new accent hues for status without first asking whether it earns its color (only the three semantic tokens).

## When adding a third tool

1. Add the case to `AppTool` (`MenuBarView.swift`) with title + SF Symbol icon.
2. Mirror the `PastesToolView` skeleton (search + content + kbd footer).
3. Reuse the row pattern from `PasteRow` — copy the slug/title/focus-actions structure, swap the data binding.
4. Wire keyboard handling per the standard mapping above.
5. The rail and shell pick up the new tool automatically.
