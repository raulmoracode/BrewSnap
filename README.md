# BrewSnap

**Your Homebrew environment, synced and protected.**

Native macOS app (SwiftUI) that exports your Homebrew state to JSON and automatically syncs it to a private GitHub repository.

---

## Problem

When you switch Macs or reinstall macOS, you lose your entire Homebrew environment:
- You don't know which packages you had installed
- `brew bundle` generates a Brewfile (Ruby DSL) that is not readable or diffable
- You don't remember the exact versions you had
- There's no convenient way to manage backups without touching the terminal

## Solution

BrewSnap is a native macOS app that:
1. Scans your Homebrew environment (formulae, casks, taps, services)
2. Generates a clean, versioned JSON
3. Syncs it to a private GitHub repository — one click, no git commands

---

## Architecture

### Stack
- **Swift 6** / **SwiftUI** / **macOS 15+ (Sequoia)**
- **GitHub API v3** (octokit.swift or direct URLSession) to create repos and push
- **Keychain** to securely store the GitHub token
- **Process** to run `brew` commands internally
- **Combine** / **@Observable** for data flow

### Project Structure

```
BrewSnap/
├── App/
│   ├── BrewSnapApp.swift           # Entry point, menu bar + window
│   ├── AppState.swift              # Global observable state
├── Views/
│   ├── MainView.swift              # Main window with tabs
│   ├── MenuBarView.swift           # Menu bar extra (icon + quick actions)
│   ├── ExportView.swift            # Export / create snapshot view
│   ├── ImportView.swift            # Import view (local or GitHub)
│   ├── PackagesView.swift          # Packages view (All / Formulae / Casks)
│   ├── SyncView.swift              # GitHub sync status
│   ├── RepositoryView.swift        # Public repo links
│   ├── SettingsView.swift          # Settings (token, repo, etc.)
│   └── Components/
│       ├── PackageRow.swift        # Package row with name + version
│       ├── StatusBadge.swift       # Status badge (synced, out of sync, etc.)
│       └── DiffView.swift          # Diff view between snapshots
├── Models/
│   ├── BrewSnapshot.swift          # Main JSON model
│   ├── BrewFormula.swift           # Formula model
│   ├── BrewCask.swift              # Cask model
│   ├── BrewTap.swift               # Tap model
│   ├── BrewService.swift           # Service model
│   └── BrewProfile.swift           # Profile model
├── Services/
│   ├── HomebrewService.swift       # Brew CLI interface (scan, install, etc.)
│   ├── GitHubService.swift         # GitHub API: create repo, commit, push
│   ├── SnapshotService.swift       # JSON snapshot generation and reading
│   ├── DiffService.swift           # Comparison between two snapshots
│   └── KeychainService.swift       # Secure token storage
├── Utilities/
│   ├── ShellExecutor.swift         # Wrapper for Process (run brew/git)
│   ├── Color+Hex.swift             # Brand colors centralized in Assets
│   ├── JSONEncoder+Pretty.swift    # Pretty JSON encoder
│   └── VersionHelper.swift         # Brew version parsing
└── Resources/
    └── Assets.xcassets/
        ├── AccentColor.colorset/   # BrewOrange #FBB040
        ├── BrewNavy.colorset/      # BrewNavy #1D3557
        ├── BrewRed.colorset/       # BrewRed #FF2C2C
        └── AppIcon.appiconset/
```

### Data Model (JSON)

```json
{
  "version": 1,
  "createdAt": "2026-09-15T12:00:00Z",
  "hostname": "MacBook-Pro-de-Raul",
  "macOS": "15.7",
  "arch": "arm64",
  "homebrew": "7.0.0",
  "formulae": [
    {
      "name": "git",
      "version": "2.47.0",
      "tap": null,
      "pinned": false,
      "kegOnly": false,
      "installedOnRequest": true
    },
    {
      "name": "python@3.13",
      "version": "3.13.7",
      "tap": null,
      "pinned": true,
      "kegOnly": false,
      "installedOnRequest": true
    }
  ],
  "casks": [
    {
      "name": "visual-studio-code",
      "version": "1.93.0",
      "tap": null,
      "autoUpdate": true
    }
  ],
  "taps": [
    {
      "name": "hashicorp/tap",
      "remote": "https://github.com/hashicorp/homebrew-tap",
      "trusted": true
    }
  ],
  "services": [
    {
      "name": "postgresql@16",
      "status": "started",
      "restart": true
    }
  ],
  "formulaeCount": 67,
  "casksCount": 23,
  "totalDiskUsage": "4.2 GB"
}
```

---

## Features

### Phase 1 — MVP

#### 1. Snapshot (Export)
- **"Create Snapshot"** button
- Runs internally:
  - `brew list --formula --versions` → parse name + version
  - `brew list --cask --versions` → parse name + version
  - `brew tap` → list of taps
  - `brew tap-info --json` → remote URL, trusted status
  - `brew services list --json` → services status
  - `brew list --pinned` → pinned packages
  - `brew --cellar` → system info
- Generates JSON with full metadata
- Shows JSON preview in the app before uploading

#### 2. GitHub Integration
- **"Create Private Repo"** button
  - Uses GitHub API (`POST /user/repos`) to create private repository
  - Name: `brewsnap` (or configurable)
  - Stores token in Keychain
  - First time: asks for GitHub token with `repo` permissions
  - Flow:
    1. Ask user for token (with link to GitHub Settings > Tokens)
    2. Validate token with `GET /user`
    3. Create repo with `POST /user/repos { "private": true }`
    4. Save repo name in UserDefaults

#### 3. Sync (Automatic Update)
- **"Update"** button
  - Generates new snapshot automatically
  - Compares with previous JSON in the repo
  - If changes:
    1. `git add brewsnap.json`
    2. `git commit -m "snapshot: 67 formulae, 23 casks — $(date)"`
    3. `git push`
  - If no changes: shows "Already up to date"
  - No user intervention required
  - Technical flow: clone/pull repo in temp directory, generate JSON, compare, commit if diff, push

#### 4. Profiles
- Save multiple snapshots with names
- Example: `work.json`, `personal.json`, `dev.json`
- Each profile is a standalone JSON file in the repo
- Button to switch active profile

### Phase 2 — Import

#### 5. Import on New Machine
- **"Import from repo"** button
  - Downloads JSON from repo
  - Shows list of packages to install with checkboxes
  - Dry-run option (see what would be installed without installing)
  - Installs in order: taps → formulae → casks → services
  - Real-time progress (progress bar + log)
  - On finish: automatic snapshot of current state

#### 6. Diff Between Machines
- **"Compare"** button
  - Select two snapshots (or two profiles)
  - Shows differences:
    - Packages only on machine A
    - Packages only on machine B
    - Packages with different versions
    - Different taps
  - `git diff`-style view with colors

### Phase 3 — Extras

#### 7. Menu Bar
- Icon in the menu bar
- Shows status: number of packages, last sync
- Quick click: create snapshot, open main window
- Notifications: "Your snapshot is outdated" (if changes detected)

#### 8. History
- View repo commit history in the app
- Each snapshot is a commit with descriptive message
- Button to restore a previous snapshot (checkout + import)
- Visual timeline of changes

#### 9. Auto-snapshot
- Optional: automatically detect brew changes
- Example: after each `brew install` or `brew upgrade`
- Background service that watches brew state
- Ask before pushing changes

#### 10. Snapshot Markdown
- Generate a readable `SNAPSHOT.md` in the repo
- Package table with name, version, tap, size
- Change history with dates
- Stats: total packages, disk usage, trend

---

## User Flows

### First Time
```
1. Open BrewSnap
2. Enter GitHub token (with help link)
3. Click "Create Private Repo" → brewsnap is created on GitHub
4. Click "Create Snapshot" → scans brew → generates JSON → pushes to repo
5. Done. App stays in menu bar monitoring
```

### Daily Update
```
1. User installs/updates packages with brew normally
2. Click "Update" in BrewSnap (or auto-snapshot if enabled)
3. App detects changes, generates JSON and pushes to repo
4. Automatic commit: "snapshot: 69 formulae (+2), 23 casks — 2026-09-15"
```

### New Machine
```
1. Install BrewSnap from DMG (github release) or `brew install raulmoracode/tap/brewsnap`
2. Enter GitHub token (or use same one if you already have it)
3. Click "Import from repo"
4. Select profile (work/personal)
5. See package list → click "Install"
6. BrewSnap installs everything in order with visual progress
7. Automatic snapshot of final state
```

---

## Brew Data Required

```bash
# System info
brew --prefix          # /opt/homebrew
brew --version         # Homebrew version
uname -m               # arm64 or x86_64
sw_vers -ProductVersion  # macOS version

# Formulae
brew list --formula --versions    # name + version
brew list --formula               # names only
brew outdated --formula           # which are outdated
brew list --pinned                # pinned packages
brew missing                      # broken dependencies

# Casks
brew list --cask --versions       # name + version
brew list --cask                  # names only
brew outdated --cask              # which are outdated

# Taps
brew tap                            # installed taps
brew tap-info --json                # detailed info per tap

# Services
brew services list                  # services status
brew services list --json           # JSON

# Disk Usage
du -sh $(brew --cellar)             # total space
du -sh $(brew --prefix)/Caskroom   # casks space
```

---

## GitHub API Used

```
POST /user/repos                    # Create private repo
GET  /user                          # Validate token
GET  /repos/{owner}/{repo}/contents/{path}  # Read file from repo
PUT  /repos/{owner}/{repo}/contents/{path}  # Create/update file
GET  /repos/{owner}/{repo}/commits          # Commit history
DELETE /repos/{owner}/{repo}                # Delete repo (optional)
```

Each "sync" is a `PUT /contents/{path}` that creates an automatic commit.

---

## Name and Branding

- **Name**: BrewSnap
- **Tagline**: "Your Homebrew environment, synced and protected"
- **Icon**: A faucet with a circular arrow → represents "snap" of the state
- **Colors**: Brew orange (#FBB040) + dark blue (#1D3557) — centralized in `Assets.xcassets` (`AccentColor`, `BrewNavy`, `BrewRed` #FF2C2C) and `Utilities/Color+Hex.swift`
- **Bundle ID**: `com.raulmorasanchez.BrewSnap`

---

## Minimum Requirements

- macOS 15.0 (Sequoia) or later
- Homebrew installed
- GitHub token with `repo` permissions (private)
- ~20 MB disk space

---

## Repositories (important for any AI with context)

BrewSnap is distributed with **2 separate repositories**. This is a Homebrew restriction:
`brew install raulmoracode/tap/brewsnap` obligatorily resolves to `github.com/raulmoracode/homebrew-tap`
(see `docs.brew.sh/Taps`: `brew tap <user>/<repo>` clones `homebrew-<repo>`).

1. **`raulmoracode/brewsnap`** — this repository. All app code, releases (DMG) and this documentation.
2. **`raulmoracode/homebrew-tap`** — minimal repo that only contains `Casks/brewsnap.rb` (the cask pointing to the DMG).

Do not use the official Homebrew tap (`homebrew/cask`): it requires apps signed and notarized by Apple, which needs the Apple Developer Program ($99/year).
This project does NOT use it. In a personal tap this requirement does not apply, so the cask works without Developer Program (although macOS will show a Gatekeeper alert on first launch: Right click → Open).

### Recommended Automation

A GitHub Actions workflow in this repo (triggered by a release) that:
1. Builds the DMG and uploads it as a release asset.
2. Updates `Casks/brewsnap.rb` in `raulmoracode/homebrew-tap`.

---

## Build and Distribution

### Install from a GitHub release

Download `BrewSnap.dmg` and `install.sh` from the same GitHub release, then run these commands from the directory containing both files:

```bash
chmod +x install.sh
./install.sh BrewSnap.dmg
```

The script mounts the DMG, installs `BrewSnap.app` in `/Applications`, removes the quarantine attribute when possible, unmounts the DMG, and launches BrewSnap.

```bash
# Development
open BrewSnap.xcodeproj
# Cmd+R to run

# Distribution (without Apple Developer Program, source distribution)
# Option 1: DMG from Xcode → upload as release asset to raulmoracode/brewsnap
# Option 2: brew install raulmoracode/tap/brewsnap (requires tap documented above)
```

---

## License

MIT — free to use, modify and distribute.
