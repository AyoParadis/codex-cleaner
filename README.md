# Codex Cleaner

A tiny native macOS app for keeping `~/.codex` fast.

It follows the cleanup system from the referenced tweet:

- scan first
- back up important local Codex state
- archive stale active chats
- move stale worktrees
- rotate oversized logs
- prune config project paths that no longer exist
- block cleanup while Codex is running

## Build The App

```sh
./Scripts/build-app.sh
```

The app bundle is created at:

```txt
.build/app/Codex Cleaner.app
```

Open it from Finder or with:

```sh
open ".build/app/Codex Cleaner.app"
```

## Safety

Cleanup moves files into archive folders under `~/.codex`; it does not delete
sessions, logs, or worktrees. The app also creates a timestamped backup in
`~/.codex/maintenance_backups` before changing anything.
