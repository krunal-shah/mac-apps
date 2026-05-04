# mac-apps

This repository contains small macOS apps.

## Apps

| App | Description |
|---|---|
| [Go Links](apps/go-links) | Menu bar app for local `go/...` shortcuts. |

## Build

Run commands from the repo root to work with the default app:

```bash
make build
make open
make install
```

The root Makefile delegates to `apps/go-links`. You can also work from the app
directory directly:

```bash
cd apps/go-links
make open
```
