# Go Links – macOS Menu Bar App

A lightweight macOS menu bar app that brings Google-style **go links** to your
personal machine. Type `go/mylink` in **any browser** and get redirected to
whatever URL you've mapped it to.

```
go/gh      →  https://github.com
go/meet    →  https://meet.google.com
go/docs    →  https://docs.google.com/…
go/jira    →  https://yourcompany.atlassian.net
```

---

## Features

- **Menu bar app** – lives in the menu bar, no Dock icon
- **Universal** – works in Safari, Chrome, Firefox, Arc, Edge, and more
- **Instant redirects** – 302 redirect with query-string passthrough (`go/search?q=foo`)
- **Clean UI** – add, edit, delete links; search/filter; copy link to clipboard
- **Persistent** – links stored in `UserDefaults`; survive reboots
- **Index page** – browse all your go links at `http://go/`

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

# Or install to /Applications:
make install
```

You can also run the same commands from the app directory:

```bash
cd apps/go-links
make open
```

---

## One-time System Setup

After launching the app, click the **Setup** button in the footer.
This will prompt for your admin password **once** and perform two operations:

| Step | What it does |
|---|---|
| `/etc/hosts` entry | Adds `127.0.0.1 go` so browsers resolve the `go` hostname locally |
| pf port-forwarding | Redirects TCP port 80 → 9876 (the app's server port) — persists across reboots via `/etc/pf.conf` |

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
      GoLinks HTTP server (port 9876)
              │
        302 redirect → https://example.com
```

---

## Project Structure

```
mac-apps/
├── Makefile                       Delegates common commands to apps/go-links
├── README.md                      Repository overview
└── apps/go-links/
    ├── Package.swift              Swift Package Manager manifest
    ├── Makefile                   Build / install helpers
    ├── Resources/
    │   └── Info.plist             App bundle metadata
    └── Sources/GoLinks/
        ├── GoLinksApp.swift       @main – App + AppDelegate
        ├── GoLinkStore.swift      Data model + UserDefaults persistence
        ├── HTTPServer.swift       BSD-socket HTTP server (no deps)
        ├── SetupManager.swift     /etc/hosts + pf setup via AppleScript
        └── Views/
            ├── MenuBarView.swift      Main popover UI
            ├── GoLinkRow.swift        Per-link row with hover actions
            ├── AddEditLinkView.swift  Add / edit sheet
            └── SetupView.swift        One-time setup sheet
```

---

## Removing Go Links

Open **Setup** → **Remove Setup**. This removes the `/etc/hosts` entry and the
pf rule, fully cleaning up the system changes.
