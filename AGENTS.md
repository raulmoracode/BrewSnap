# AGENTS.md

Context and conventions for AI coding agents (and humans) working on **BrewSnap**.
Read this first — it is written so a model can be productive in under a minute.

---

## 1. What this project is

BrewSnap is a **native macOS app** (SwiftUI, Swift 6, macOS 15+) that scans your
Homebrew environment, exports it as a **versioned JSON snapshot**, and syncs it to a
**private GitHub repository**. It replaces the `Brewfile` (Ruby DSL, not diffable) with
a clean, readable JSON, and lets you restore the environment on a new Mac.

- **No third-party dependencies.** Only Apple frameworks: `SwiftUI`, `Foundation`,
  `AppKit`, `Security` (Keychain), `ServiceManagement` (launch at login), `Observation`.
- **Two GitHub repositories** (a Homebrew requirement):
  1. `raulmoracode/brewsnap` — this repo: app code, releases (DMG), docs.
  2. `raulmoracode/homebrew-tap` — minimal tap with `Casks/brewsnap.rb` pointing to the DMG.
- **Brand:** orange `#FBB040`, navy `#1D3557`, red `#FF2C2C`. Bundle ID `com.raulmorasanchez.BrewSnap`.
- **Docs:** `README.md` (full product spec + roadmap), `CHANGELOG.md` (release history).

---

## 2. Build, run, lint

```bash
# Build (same command CI uses)
xcodebuild -project BrewSnap.xcodeproj -scheme BrewSnap -configuration Debug build

# Run in Xcode
open BrewSnap.xcodeproj      # then Cmd+R
```

- **Requirements:** macOS 15+, Xcode 16+, Homebrew installed.
- **Lint:** SwiftLint with `.swiftlint.yml` (run `swiftlint` if installed).
- **CI:** `.github/workflows/ci.yml` builds Debug on every push/PR to `main`.
- **Release:** `.github/workflows/release.yml` builds the DMG and publishes a release on `v*` tags.

> The Xcode target uses a **filesystem-synchronized group** for the `BrewSnap/` folder.
> Any `.swift` file you add under `BrewSnap/` is compiled automatically — **do not edit
> `project.pbxproj`** to register files.

---

## 3. Project map — where to touch what

| Path | Purpose |
| --- | --- |
| `BrewSnap/App/BrewSnapApp.swift` | Entry point: `WindowGroup` + `MenuBarExtra` + `Settings`. |
| `BrewSnap/App/AppState.swift` | `@Observable` global state (snapshot, profiles, token flags, repo settings). |
| `BrewSnap/Models/` | Codable models: `BrewSnapshot`, `BrewFormula`, `BrewCask`, `BrewTap`, `BrewService`, `BrewProfile`. |
| `BrewSnap/Services/HomebrewService.swift` | Scans Homebrew via CLI (timeouts + fallbacks) and restores a snapshot. |
| `BrewSnap/Services/GitHubService.swift` | GitHub REST v3 client: validate token, create/delete repo, read/write files. |
| `BrewSnap/Services/SnapshotService.swift` | Generate / save / load / diff snapshots. |
| `BrewSnap/Services/DiffService.swift` | Compare two snapshots. |
| `BrewSnap/Services/KeychainService.swift` | Secure GitHub token storage. |
| `BrewSnap/Utilities/ShellExecutor.swift` | `Process` wrapper (resolve `brew`, run `git`/commands safely). |
| `BrewSnap/Utilities/VersionHelper.swift` | Parse `brew` output and system info. |
| `BrewSnap/Views/MainView.swift` | Sidebar navigation between the tabs. |
| `BrewSnap/Views/*` | `Import`, `Export`, `Packages`, `Settings`, `General`, `Repository`, `MenuBar`. |
| `BrewSnap/Views/Components/` | Reusable UI: `PackageRow`, `StatusBadge`, `DiffView`, `HookSidebar`, `TokenAwareHover`, … |
| `BrewSnap/Resources/Assets.xcassets/` | Colors and app icon. |
| `.opencode/opencode.json` | Project config: loads the skills catalog the agents follow. |

**Common tasks → files**
- New screen → `Views/`, register it in `MainView.swift` tabs.
- Change Homebrew scanning → `Services/HomebrewService.swift` + `Utilities/VersionHelper.swift`.
- Change GitHub behavior → `Services/GitHubService.swift`.
- Persistence / settings → `App/AppState.swift` + `Services/KeychainService.swift`.

---

## 4. Architecture rules (do not violate)

- **Single source of truth:** `AppState` (`@Observable`). Views read it via `@Environment(AppState.self)`.
- **Token in Keychain only.** Never read the Keychain while rendering a view — that triggers
  the system password prompt. Use the `hasGithubToken` UserDefaults flag for UI, and read the
  Keychain only on explicit user action.
- **Injected dependencies:** `AppState` takes `UserDefaults` and the Keychain service in `init`
  for testability. Avoid scattered `UserDefaults.standard`.
- **Homebrew access** always goes through `ShellExecutor` (resolves the `brew` binary without
  relying on `PATH`, uses per-command timeouts and fallbacks, and never blocks the pipes).
- **Incomplete snapshots are blocked.** If a scan produces warnings, `isComplete == false` and
  both upload and restore are refused.
- **GitHub** uses `URLSession` directly against the REST API (no Octokit).
- **Concurrency:** Swift 6 strict checking — respect `Sendable`; hop to `@MainActor` for UI updates.

---

## 5. Coding conventions

**Follow the skills catalog loaded from `.opencode/opencode.json`** — it points to
`https://raulmoracode.github.io/raulmoracode-skills/` (the raulmoracode-skills catalog).
OpenCode loads this automatically; all skills declared there are active.

Highlights from the catalog:

- One type per file; the file name matches the main type.
- Group long files with `// MARK: -` sections; order: properties → init → public → private.
- Descriptive names; booleans read as questions (`isScanning`, `hasGithubToken`, `canSubmit`).
- Prefer `struct` unless reference identity is needed.
- No force unwraps (`!`), no force casts (`as!`), no `Any`. Use `guard let` / `as?`.
- Use `throws` and custom `Error` enums instead of returning `nil` silently.
- The file's top comment states its purpose; comment the **why**, not the **what**.

---

## 6. Git workflow

**All git operations (issues, branches, commits, pull requests) are governed by the `git-workflow` skill.**
That skill owns the full flow: issue → branch → implementation → verification → pull request,
with the 29-label policy. It never merges — merges go to `git-merge`.

Key points:
- **Every committed change goes through the full flow.** No direct commits to `main`.
- **Branch format:** `<type>/<issue-number>-<slug>` (e.g., `feat/123-menu-bar-sync`).
- **Commit format:** Conventional Commits — `<type>(<scope>): <summary>` (English, lowercase, no period).
- **PR title:** same as commit format; body includes `Closes #N`.
- **Labels:** 29-label policy per `git-workflow` (type, area, risk, marks).
- **Never merge a red PR.** All CI checks must pass.
- **No secrets in commits.** `brewsnap.json` and `*.json.bak` are gitignored.

For single-stage asks (issue only, branch only, PR only) use `git-issues`, `git-branch`, `git-pr` explicitly.
For read-only work, no git skill is needed.

---

## 7. Do not

- Add third-party dependencies or SwiftPM packages.
- Commit the GitHub token or any secret.
- Edit `project.pbxproj` to add source files (the synchronized group handles it).
- Rename or move files without a clear reason.
- Bypass the `git-workflow` flow for any change that will be committed.
