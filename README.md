# mac-apps

This repository contains small macOS apps.

## Apps

| App | Description |
|---|---|
| [Go Links](apps/go-links) | Menu bar app for local `go/...` shortcuts and `go/paste/...` snippets. |

## Build

Run commands from the repo root to work with the default app:

```bash
make build
make test
make open
make install
```

The root Makefile delegates to `apps/go-links`. You can also work from the app
directory directly:

```bash
cd apps/go-links
make open
```

## Releases

Pushing a `go-links-v*` tag builds `GoLinks.app.zip` on GitHub Actions and
attaches it to a GitHub Release:

```bash
git tag go-links-v1.0.0
git push origin go-links-v1.0.0
```

You can also run the `Go Links Release` workflow manually in GitHub Actions and
provide the release tag.
