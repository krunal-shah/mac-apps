# Command Shelf – macOS Menu Bar App

Command Shelf is a lightweight macOS menu bar utility shelf. It currently brings
Google-style **go links** and automatic clipboard-backed pastebin snippets to
your machine. Type `go/mylink` in **any browser** to redirect, or open
`go/paste` to browse copied text.

```
go/gh      →  https://github.com
go/meet    →  https://meet.google.com
go/docs    →  https://docs.google.com/…
go/search/openai → https://www.google.com/search?q=openai
go/jira    →  https://yourcompany.atlassian.net
go/paste   →  paste index
go/paste/abc123/raw → raw snippet text
```

---

## Features

- **Menu bar app** – lives in the menu bar, no Dock icon
- **Universal** – works in Safari, Chrome, Firefox, Arc, Edge, and more
- **Instant redirects** – 302 redirect with query-string passthrough (`go/search?q=foo`)
- **Nested shortcuts** – exact paths and longest-prefix matching (`go/team/wiki`)
- **Path templates** – use `{path}` when a shortcut should consume the remaining path (`go/search/foo` → `...?q=foo`)
- **Pastebin** – automatically saves copied text snippets; edit, search, open, and copy them
- **Keyboard-first paste history** – opens on pastes; arrow through items, preview, and copy from the menu
- **Clean UI** – tool switcher, embedded settings, inline forms, search/filter, copy actions
- **Persistent** – links and pastes stored in `UserDefaults`; survive reboots
- **Index pages** – browse links at `http://go/` and pastes at `https://go/paste`

---

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)

---

## Build & Install

```bash
git clone <repo>
cd mac-apps

# Build and open the default app bundle:
make open

# Run tests:
make test

# Or install to /Applications:
make install

# Or create a distributable zip:
make release-zip
```

You can also run the same commands from the app directory:

```bash
cd apps/command-shelf
make open
```

## GitHub Releases

The repo includes a GitHub Actions workflow that builds this app and uploads
`CommandShelf.app.zip` to the Releases tab whenever a `command-shelf-v*` tag is
pushed:

```bash
git tag command-shelf-v1.0.0
git push origin command-shelf-v1.0.0
```

---

## One-time System Setup

After launching the app, click the **Setup** button in the header.
This will prompt for your admin password **once** and perform two operations:

| Step | What it does |
|---|---|
| `/etc/hosts` entry | Adds `127.0.0.1 go` so browsers resolve the `go` hostname locally |
| pf port-forwarding | Redirects TCP port 80 → 9876 and 443 → 9877 — persists across reboots via `/etc/pf.conf` |

The app itself never runs as root.

---

## How it works

```
Browser:  http://go/mylink
              │
       /etc/hosts: go → 127.0.0.1
              │
         pf NAT rule: :80 → :9876
              │
      Command Shelf HTTP server (port 9876)
              │
        302 redirect → https://example.com
```

Pastebin routes use the same local hostname:

```
Browser:  https://go/paste/abc123
              │
      Command Shelf HTTPS server (port 9877)
              │
        HTML paste page or /raw text response
```

---

## Project Structure

```
mac-apps/
├── Makefile                       Delegates common commands to apps/command-shelf
├── README.md                      Repository overview
└── apps/command-shelf/
    ├── Package.swift              Swift Package Manager manifest
    ├── Makefile                   Build / install helpers
    ├── Resources/
    │   ├── AppIcon.icns           Dock/Finder app icon
    │   ├── MenuBarIconTemplate.png Monochrome menu bar icon
    │   └── Info.plist             App bundle metadata
    └── Sources/CommandShelf/
        ├── AppConfig.swift        Shared app constants and routes
        ├── CommandShelfApp.swift  @main – App + AppDelegate
        ├── GoLinkStore.swift      Link model + UserDefaults persistence
        ├── PasteStore.swift       Paste model + UserDefaults persistence
        ├── GoLinkRouter.swift     Local HTTP/HTTPS route handling
        ├── HTTPServer.swift       HTTP server
        ├── TLSServer.swift        HTTPS server
        ├── SetupManager.swift     /etc/hosts + pf + certificate setup
        └── Views/
            ├── MenuBarView.swift        Tool shell and switcher
            ├── LinksToolView.swift      Go-links tool
            ├── PastesToolView.swift     Pastebin tool
            ├── SharedToolViews.swift    Shared menu controls
            └── SetupView.swift          One-time setup panel
```

---

## Removing Command Shelf

Open **Setup** → **Remove Setup**. This removes the `/etc/hosts` entry and the
pf rule, fully cleaning up the system changes.
