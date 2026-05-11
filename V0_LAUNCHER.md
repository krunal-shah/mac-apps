# Syl Launcher — v0

A hotkey-summoned command palette, built into Command Shelf, that turns Krunal & Aarohi's shared Syl state into one-keystroke actions.

This document is the **v0 contract**. Anything not listed here is out of scope until v0 ships and gets dogfooded.

---

## Frame

Syl is a personal operating system across two surfaces:

- **Action surface (Mac)** — this launcher. Keystroke-fast verbs.
- **Visualization surface (Web/PWA)** — the existing Syl web app at `https://homeservers-mbp.tailb2984e.ts.net/`. Read/scan/plan.

Both clients share **one backend**: the Syl FastAPI server on `127.0.0.1:3000`, exposed to the tailnet via Tailscale Serve. The launcher is a client of Syl — it never owns data.

---

## Vision recap

The launcher is **not** a generic app launcher. It's a tiny set of personal verbs:

- **Paste** from clipboard history
- **Go** to bookmarked URLs
- **AI templated actions** — `linear`, `read`, `todo`, `recipe`, `note`, `ask` — each with a typed prompt template, hydrated with your inline input, dispatched to one of three action targets

The point is friction-zero capture and action, not search.

---

## v0 Scope

### Ships

| Piece | Decision |
|---|---|
| Hotkey | `⌥ Space` (Option-Space) |
| Window | Centered borderless `NSPanel`, dismisses on Esc + blur |
| Host | Extends Command Shelf (same `.app` bundle, same menu bar entry) |
| Result providers | `GoLinkStore`, `PasteStore`, `TriggerStore` |
| Trigger source of truth | `~/Documents/K_and_A/Launcher/triggers.json` (in Obsidian vault) |
| Seed triggers | `linear`, `read`, `todo`, `recipe`, `note`, `ask` |
| Action types | `clipboard`, `syl_api`, `stream_inline` |
| Syl base URL | `127.0.0.1:3000` on Krunal's Mac (fallback: tailnet URL) |
| Identity | `X-User` from local prefs, default `Krunal`, toggleable in Setup |
| Ranking | Prefix > substring; trigger keyword match wins |

### Does **not** ship in v0

- Trigger editor UI (edit JSON in Obsidian)
- Web-app timeline / calendar / learning surface (separate milestones)
- Cross-Mac clipboard sync
- Custom fuzzy ranking
- Aarohi's Mac setup (defer until Tailscale is wired)

---

## Trigger DSL

Triggers are JSON in the vault. v0 supports three action types.

```json
{
  "triggers": [
    {
      "keyword": "linear",
      "label": "Linear — draft ticket",
      "prompt": "Draft a Linear ticket. Context:\n{input}",
      "action": { "type": "clipboard" }
    },
    {
      "keyword": "read",
      "label": "Reading — add to inbox",
      "action": {
        "type": "syl_api",
        "method": "POST",
        "endpoint": "/api/reading",
        "body": { "raw": "{input}" }
      }
    },
    {
      "keyword": "ask",
      "label": "Ask Claude",
      "prompt": "{input}",
      "action": { "type": "stream_inline", "context": "general" }
    }
  ]
}
```

- `keyword` — first token typed; routes the query to this trigger
- `prompt` — optional; if present, hydrated with `{input}` and sent to Claude
- `action.type`:
  - `clipboard` — Claude response → `NSPasteboard`
  - `syl_api` — POST to Syl endpoint with hydrated body
  - `stream_inline` — Claude SSE rendered into the palette

---

## Architecture (additive on top of Command Shelf)

```
CommandShelfApp
├── existing: GoLinkStore, PasteStore, ClipboardMonitor, HTTPServer, TLSServer
└── new:
    ├── GlobalHotKey            Carbon RegisterEventHotKey wrapper
    ├── PaletteController       Owns the NSPanel, show/hide lifecycle
    ├── PaletteView             SwiftUI: query field + results
    ├── PaletteResult           Unified result enum
    ├── TriggerStore            Loads + reloads triggers.json
    ├── TriggerDefinition       Decodable model
    ├── SylClient               URLSession + X-User header
    └── Identity                UserDefaults wrapper for active user
```

---

## Build order

1. **Hotkey + empty panel** — ⌥Space shows/dismisses a centered window. Prove the surface.
2. **Palette UI over existing stores** — query field, ranked list of GoLinks + Pastes, keyboard nav. Already useful at this point.
3. **TriggerStore + JSON loader** — read vault file, register trigger results.
4. **Syl client + identity** — HTTP wrapper, X-User from prefs, basic reachability.
5. **Action execution** — clipboard, then `syl_api`, then `stream_inline`.
6. **Dogfood for a week.** Then re-plan.

---

## Multi-Mac (forward-compat)

- Krunal's Mac: Syl server running, launcher hits `127.0.0.1:3000`.
- Aarohi's Mac (later): launcher hits `https://homeservers-mbp.tailb2984e.ts.net/`. Same triggers (shared vault). `X-User = Aarohi`.
- If Syl is unreachable, clipboard-only triggers still work; `syl_api` and `stream_inline` show "Syl unreachable" inline.
