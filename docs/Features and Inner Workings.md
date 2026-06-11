# Tree Builder — Features and Inner Workings

This document describes **how the app behaves today** and **where implementation lives**.
For a short, commit-adjacent summary of recent changes, see `source control log.md`.

---

## Product shape

- **Stack:** Flutter (Material 3), Dart 3.8+.
- **Persistence:** Single JSON file `tree_library.json` in app documents directory (`TreeStorageService`).
- **Navigation:** Home screen + pushed routes for **Library** and **Tree detail**.
- **Platforms:** Android (SAF-native scan), macOS/desktop/iOS (`file_picker` + `dart:io` scan), plus **SMB** and **SFTP** remote scan on all platforms.

| Concern | Package / mechanism |
|---------|---------------------|
| Directory pick (desktop) | `file_picker` `getDirectoryPath()` |
| Directory pick + scan (Android) | Custom `MethodChannel` + `EventChannel` in `MainActivity.kt` |
| Remote scan (SMB) | `smb_connect` — `SmbDirectoryScanner` |
| Remote scan (SFTP) | `dartssh2` — `SftpDirectoryScanner` |
| Local library | `path_provider` + JSON file |
| Export / import | `file_picker` save/open dialogs (platform-specific bytes vs path) |
| Tree rendering | `TreeRenderer` + `CollapsibleTreeView` |

---

## Home screen

**File:** `lib/screens/home_screen.dart`

### Choose directory source

Home screen **segmented control**: **Local** | **SMB** | **SFTP**.

| Source | Flow |
|--------|------|
| **Local** | System folder picker (Android SAF or `file_picker`) |
| **SMB** | Settings credentials → browse shares/folders → scan selected folder |
| **SFTP** | Settings credentials → browse remote folders → scan selected folder |

Remote credentials live in **Settings** (gear icon in app bar). Passwords are stored locally in `remote_settings.json` on the device — not in tree library exports.

### Choose Directory

1. User selects source and taps **Choose Directory**.
2. **Local — Android:** `DirectoryScanner.pickAndScan()` → SAF pick → background scan.
3. **Local — other:** `getDirectoryPath()` → `_scanWithIo()`.
4. **SMB/SFTP:** load settings → `RemoteDirectoryPickerScreen` → scan only the selected path.
5. Result saved to library; collapsible preview shown; **Open** → tree detail.

**Files:** `lib/screens/settings_screen.dart`, `lib/screens/remote_directory_picker_screen.dart`, `lib/services/remote_settings_service.dart`, `lib/services/smb_remote_browser.dart`, `lib/services/sftp_remote_browser.dart`

### Scan options (checkboxes, top to bottom)

| Option | Default | Effect |
|--------|---------|--------|
| **Expand all folders** | Off | When on, tree opens fully expanded; stored as `TreeBuild.expandAllFolders` |
| **Limit folder depth** | Off | When on, integer **Depth levels** field (min 1) caps folder recursion (`maxDepth`) |

### Scanning UX

`ScanLoadingOverlay` during scan: phases **Scanning** → **Building tree** → **Saving**; live folder/file counts.

**Key types:** `lib/widgets/scan_loading_overlay.dart`, `lib/models/scan_progress.dart`

### Tree preview

`CollapsibleTreeView` in `Expanded` below controls — same interactive tree as detail view.

---

## Library

**File:** `lib/screens/library_screen.dart`

- Lists `TreeBuild` entries (newest first): name, date, folder/file counts.
- **Import** / **Export all** (JSON).
- Tap → tree detail; delete from detail screen.

---

## Settings

**File:** `lib/screens/settings_screen.dart`

- App bar gear icon on home screen.
- **SMB:** host, domain (optional), username, password.
- **SFTP:** host, port, username, password.
- Persisted via `RemoteSettingsService` → `{appDocuments}/remote_settings.json`.

---

## Remote directory picker

**File:** `lib/screens/remote_directory_picker_screen.dart`

| Protocol | Browse behavior |
|----------|-----------------|
| **SMB** | Lists shares at root, then subfolders; **Select this folder** enabled inside a share |
| **SFTP** | Starts at `/`; navigate into subfolders; select any folder including root |

Browsers: `SmbRemoteBrowser`, `SftpRemoteBrowser`. Connection closed when picker is dismissed.

---

## Tree detail

**File:** `lib/screens/tree_view_screen.dart`

- Info card: path, folder/file counts.
- `CollapsibleTreeView` — tap folders to expand/collapse.
- App bar: **Expand all**, **Collapse all**, **Copy visible tree**, export menu (JSON/text), delete.
- Hint: copy and text export use visible tree only.

---

## Collapsible tree

**Files:** `lib/widgets/collapsible_tree_view.dart`, `lib/utils/tree_renderer.dart`

### Interaction

- Folders with children show chevron (`keyboard_arrow_right` / `keyboard_arrow_down`); tap toggles.
- Files and empty folders: no chevron, not tappable.
- Path keys: `folder/subfolder` (slash-separated from root children).

### Expansion state

| Source | Initial state |
|--------|----------------|
| `expandAllFolders: false` (default) | All folders collapsed — only root-level entries visible |
| `expandAllFolders: true` | All folder paths in `TreeRenderer.allFolderPaths(root)` expanded |
| User taps / app bar buttons | Updates in-memory only (not persisted until re-save) |

### Text rendering

- `TreeRenderer.renderFull()` — all folders expanded (used when building `treeText` at scan time).
- `TreeRenderer.renderVisible(rootName, children, expandedPaths)` — ASCII for current view.
- `CollapsibleTreeViewState.visibleTreeText` — used for copy and export.

---

## Directory scanning

**Entry point:** `DirectoryScanner.pickAndScan({maxDepth, path, onProgress})`

### Desktop / macOS / iOS (`dart:io`)

**File:** `lib/services/directory_scanner.dart`

- Non-directory entities → files; sort dirs first, then alpha.
- Progress every 25 entries.
- `treeText` = `TreeRenderer.renderFull(rootName, children)`.

### Android (SAF)

**Files:** `MainActivity.kt`, `lib/services/android_tree_scanner.dart`

| Channel | Purpose |
|---------|---------|
| `com.treebuilder/tree_scanner` | `pickDirectory`, `scanDirectory` |
| `com.treebuilder/scan_progress` | `{folders, files, current}` |

Background `DocumentFile` scan → `compute()` + `deepCastMap` → `TreeRenderer.renderFull`.

### SMB (Samba/CIFS)

**File:** `lib/services/smb_directory_scanner.dart`

- Connect via `SmbConnect.connectAuth(host, username, password, domain)`.
- Path format: `/share/folder/subfolder` — first segment is the SMB share name.
- `listFiles()` recursion with same depth limit and progress reporting as local scan.
- `rootPath` stored as `smb://host/share/path` (no credentials).

### SFTP

**File:** `lib/services/sftp_directory_scanner.dart`

- Connect via `SSHSocket` + `SSHClient` + `client.sftp()`.
- Password auth via `onPasswordRequest`.
- `listdir()` recursion; dirs first, then alpha.
- `rootPath` stored as `sftp://host[:port]/path`.

Shared progress helper: `lib/services/scan_counters.dart`.

---

## Export / import

**File:** `lib/services/tree_export_service.dart`

| Format | Visible tree? | Notes |
|--------|---------------|-------|
| Text export | Yes | `treeText` param = `visibleTreeText` |
| JSON export (single) | `treeText` only | Full `root` still included for re-import |
| JSON export (library) | Full builds | No collapse filter |
| Copy clipboard | Yes | From detail screen |

| Platform | Export | Import |
|----------|--------|--------|
| Android / iOS | `saveFile(bytes: utf8)` | `pickFiles(withData: true)` |
| Desktop | `saveFile` → `File.writeAsBytes` | `File(path).readAsString` |

---

## Data model

### `TreeNode` — `lib/models/tree_node.dart`

| Field | Type | Notes |
|-------|------|-------|
| `name` | String | File or folder name |
| `isDirectory` | bool | |
| `children` | List\<TreeNode\> | Empty for files |

### `TreeBuild` — `lib/models/tree_build.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | UUID v4 |
| `rootPath` | String | Local path, Android `content://` URI, or remote display URI (`smb://…`, `sftp://…`) |
| `rootName` | String | Display name |
| `root` | TreeNode | Full tree (always complete) |
| `treeText` | String | Full ASCII at scan time (`renderFull`) |
| `createdAt` | DateTime | ISO 8601 |
| `maxDepth` | int? | Scan depth limit; omitted if unlimited |
| `expandAllFolders` | bool | Default `false`; initial UI expansion |
| `scanSourceType` | enum | `local` (default), `smb`, or `sftp` |

### `ScanProgress` — `lib/models/scan_progress.dart`

`folders`, `files`, `currentName`, `phase` (`scanning` | `building` | `saving`).

---

## Storage

**File:** `lib/services/tree_storage_service.dart` — `{appDocuments}/tree_library.json`

---

## Android configuration

| Item | Location |
|------|----------|
| NDK | `27.0.12077973` in `android/app/build.gradle.kts` |
| INTERNET permission | `android/app/src/main/AndroidManifest.xml` (SMB/SFTP) |
| DocumentFile | `androidx.documentfile:documentfile:1.1.0` |
| macOS entitlements | `files.user-selected.read-write`, `network.client` |

---

## Key source files

| Area | Files |
|------|-------|
| Entry | `lib/main.dart` |
| Screens | `lib/screens/home_screen.dart`, `library_screen.dart`, `tree_view_screen.dart`, `settings_screen.dart`, `remote_directory_picker_screen.dart` |
| Scan | `directory_scanner.dart`, `android_tree_scanner.dart`, `smb_directory_scanner.dart`, `sftp_directory_scanner.dart`, `smb_remote_browser.dart`, `sftp_remote_browser.dart`, `remote_settings_service.dart`, `scan_counters.dart`, `MainActivity.kt` |
| Storage / export | `tree_storage_service.dart`, `tree_export_service.dart` |
| Tree UI | `lib/widgets/collapsible_tree_view.dart`, `tree_text_view.dart`, `scan_loading_overlay.dart` |
| Utils | `lib/utils/tree_renderer.dart`, `map_cast.dart` |
| Models | `tree_node.dart`, `tree_build.dart`, `scan_progress.dart`, `scan_source_type.dart`, `remote_settings.dart` |
| Tests | `directory_scanner_test.dart`, `map_cast_test.dart`, `tree_renderer_test.dart`, `widget_test.dart` |

---

## Known constraints / pitfalls

- **Android `rootPath`** — `content://` URI only; not for `dart:io`.
- **Remote credentials** — stored in app settings file locally; not included in tree library JSON exports.
- **SMB path** — must include share as first path segment (e.g. `/videos/games`).
- **Platform channel maps** — use `deepCastMap` before `fromJson`.
- **Mobile export** — `bytes` required on `saveFile` (BJ-007).
- **Depth limit** — leaf folders hide nested files (BJ-006).
- **`treeText` in library** — always full tree at scan; export/copy use visible state at export time.
- **Expansion toggles** — not auto-saved to library after manual collapse/expand.
- **Large trees** — 800+ files work; scroll may lag when fully expanded.
- **Hot reload** — insufficient after Kotlin changes; full restart required.

---

## Cross-reference

- **What changed lately:** `docs/source control log.md`
- **Bugs and fixes:** `docs/bug journal.md`
