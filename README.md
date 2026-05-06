# mac-apps

This repository contains small macOS apps.

## Apps

| App | Description |
|---|---|
| [Command Shelf](apps/command-shelf) | Menu bar utility shelf for local `go/...` shortcuts and clipboard-backed pastes. |

## Build

Run commands from the repo root to work with the default app:

```bash
make build
make test
make open
make install
```

The root Makefile delegates to `apps/command-shelf`. You can also work from the app
directory directly:

```bash
cd apps/command-shelf
make open
```

## Releases

Pushing a `command-shelf-v*` tag builds `CommandShelf.app.zip` on GitHub Actions and
attaches it to a GitHub Release:

```bash
git tag command-shelf-v1.0.0
git push origin command-shelf-v1.0.0
```

You can also run the `Command Shelf Release` workflow manually in GitHub Actions and
provide the release tag.
