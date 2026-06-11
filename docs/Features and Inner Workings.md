# Tree Builder — Features and Inner Workings

This document describes **how the app behaves today** and **where implementation lives**.
For a short, commit-adjacent summary of recent changes, see `source control log.md`.

---

## Product shape

- **Stack:** Flutter (Material 3), Dart 3.8+.
- **Persistence:** Single JSON file `tree_library.json` in app documents directory (`TreeStorageService`).
- **Navigation:** Home screen + pushed routes for **Library** and **Tree detail**.
- **Platforms:** Android (SAF-native scan), macOS/desktop/iOS (`file_picker` + `dart:io` scan).

| Concern | Package / mechanism |
|---------|---------------------|
| Directory pick (desktop) | `file_picker` `getDirectoryPath()` |
| Directory pick + scan (Android) | Custom `MethodChannel` + `EventChannel` in `MainActivity.kt` |
| Local library | `path_provider` + JSON file |
| Export / import | `file_picker` save/open dialogs (platform-specific bytes vs path) |
| Tree rendering | `TreeRenderer` + `CollapsibleTreeView` |

---

## Home screen

**File:** `lib/screens/home_screen.dart`

### Choose Directory

1. User taps **Choose Directory**.
2. **Android:** `DirectoryScanner.pickAndScan()` → `pickDirectory` → background `scanDirectory`.
3. **Other platforms:** `getDirectoryPath()` → `_scanWithIo()`.
4. Result saved to library with scan options; collapsible preview shown; **Open** → tree detail.

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
| `rootPath` | String | Path or Android `content://` URI |
| `rootName` | String | Display name |
| `root` | TreeNode | Full tree (always complete) |
| `treeText` | String | Full ASCII at scan time (`renderFull`) |
| `createdAt` | DateTime | ISO 8601 |
| `maxDepth` | int? | Scan depth limit; omitted if unlimited |
| `expandAllFolders` | bool | Default `false`; initial UI expansion |

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
| DocumentFile | `androidx.documentfile:documentfile:1.1.0` |
| macOS entitlements | `files.user-selected.read-write` |

---

## Key source files

| Area | Files |
|------|-------|
| Entry | `lib/main.dart` |
| Screens | `lib/screens/home_screen.dart`, `library_screen.dart`, `tree_view_screen.dart` |
| Scan | `lib/services/directory_scanner.dart`, `android_tree_scanner.dart`, `MainActivity.kt` |
| Storage / export | `tree_storage_service.dart`, `tree_export_service.dart` |
| Tree UI | `lib/widgets/collapsible_tree_view.dart`, `tree_text_view.dart`, `scan_loading_overlay.dart` |
| Utils | `lib/utils/tree_renderer.dart`, `map_cast.dart` |
| Models | `tree_node.dart`, `tree_build.dart`, `scan_progress.dart` |
| Tests | `directory_scanner_test.dart`, `map_cast_test.dart`, `tree_renderer_test.dart`, `widget_test.dart` |

---

## Known constraints / pitfalls

- **Android `rootPath`** — `content://` URI only; not for `dart:io`.
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
