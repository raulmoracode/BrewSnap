# Changelog

All notable changes to BrewSnap are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Keep the native sidebar toggle and preserve the sidebar width when resizing the window ([#17](https://github.com/raulmoracode/brewsnap/pull/17)).

## [0.1.0] - 2026-09-19

First tagged MVP: snapshot, sync and restore of a Homebrew environment.

### Added
- Snapshot generation: scans Homebrew formulae, casks, taps and services and writes a versioned JSON.
- Private GitHub repository sync (`brewsnap-config`) with one-click commit and push.
- Packages view with `All` / `Formulae` / `Casks` columns and search.
- Import from a local JSON file (drag & drop) and from the private GitHub repository.
- Homebrew restore in order (taps → formulae → casks → services) with live progress and a dry-run guard.
- `isComplete` flag that blocks upload and restore of incomplete snapshots.
- Menu bar extra with Sync, Settings, Open and Quit actions.
- Settings: token validation and masking, fixed `brewsnap-config` repo, create/delete repo, launch at login.
- Token-aware hover feedback (cursor + tooltip) on GitHub action buttons.
- Scripted DMG installer (`install.sh`).
- `good-practices` skill with Codex / OpenCode / Claude integration.
- GitHub Actions workflows: CI build and Release (DMG publish on `v*` tags).

### Changed
- Renamed the created repository to `brewsnap-config` and set the homepage to `brewsnap.raulmoracode.com`.
- Translated the entire project to English.
- Refined the sidebar (footer, cursor behavior) and let the Packages columns resize with the window.

### Fixed
- Snapshot returning 0 formulae/casks caused by the Homebrew path and sandbox.
- Infinite scanning: added a scan timeout plus per-command timeouts with fallbacks.
- Packages columns shrinking when searching or resizing.
- Validate the repository before uploading and before importing from GitHub.

### Removed
- Removed the `SyncView` (folded into the menu bar).
- Removed the dedicated Profiles tab (profiles remain supported in the model).
- Removed `BUENAS_PRACTICAS.md` (moved into the `good-practices` skill).

[Unreleased]: https://github.com/raulmoracode/brewsnap/compare/v.0.1.0...HEAD
[0.1.0]: https://github.com/raulmoracode/brewsnap/releases/tag/v.0.1.0
