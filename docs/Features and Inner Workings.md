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

---

## Home screen

**File:** `lib/screens/home_screen.dart`

### Choose Directory

1. User taps **Choose Directory**.
2. **Android:** `DirectoryScanner.pickAndScan()` → `AndroidTreeScanner.pickDirectory()` (native `ACTION_OPEN_DOCUMENT_TREE`) → `scanDirectory` on background thread.
3. **Other platforms:** `FilePicker.platform.getDirectoryPath()` → `DirectoryScanner._scanWithIo()`.
4. Result is saved to library automatically and shown in a scrollable preview; **Open** navigates to full tree view.

### Limit folder depth

- Checkbox **Limit folder depth** (off = unlimited).
- When checked, integer field **Depth levels** (minimum 1, digits only).
- `maxDepth` = how many folder levels below root are expanded.
- At the limit, subfolders appear as leaves (`name/`) without their children; files at each listed level are still included.
- Files inside folders beyond the depth cutoff are not listed (see BJ-006).

### Scanning UX

While scanning, `ScanLoadingOverlay` (`Stack` over home body) shows:

| Phase | When |
|-------|------|
| Scanning directory | Native/`dart:io` walk in progress |
| Building tree | `compute()` parse + `renderTree` |
| Saving to library | `TreeStorageService.save` |

- Live folder/file counts (Android: `EventChannel` every 25 entries; desktop: same interval in `_ScanCounters`).
- Current item name when available.
- Overlay starts **after** folder selection on Android (not during system picker).

**Key types:** `lib/widgets/scan_loading_overlay.dart`, `lib/models/scan_progress.dart`

---

## Library

**File:** `lib/screens/library_screen.dart`

- Lists saved `TreeBuild` entries (newest first): name, date, folder/file counts.
- **Import** (toolbar): JSON file — single tree or array (full library export).
- **Export all** (toolbar): entire library as JSON.
- Tap entry → tree detail; delete available from detail screen.

---

## Tree detail

**File:** `lib/screens/tree_view_screen.dart`

- Info card: `rootPath` (filesystem path or Android `content://` URI), folder count, file count.
- Monospace selectable ASCII tree (`TreeTextView`).
- App bar actions: copy to clipboard; export menu (JSON / text); delete (with confirmation).

---

## Directory scanning

**Entry point:** `DirectoryScanner.pickAndScan({maxDepth, path, onProgress})`

### Desktop / macOS / iOS (`dart:io`)

**File:** `lib/services/directory_scanner.dart` — `_scanWithIo`, `_buildNode`

- Lists with `directory.list(followLinks: false)`.
- **Directory:** `entity is Directory` or `FileSystemEntity.type` == directory.
- **File:** everything else (no extension filter).
- Sort: directories first, then alphabetical (case-insensitive).
- ASCII render: `├──`, `└──`, `│` prefixes; folders suffixed with `/`.
- Progress: `_ScanCounters.maybeReport` every 25 entries + `Future.delayed(Duration.zero)` to yield to UI.

### Android (Storage Access Framework)

**Files:** `android/.../MainActivity.kt`, `lib/services/android_tree_scanner.dart`

| Channel | Name | Methods / events |
|---------|------|------------------|
| MethodChannel | `com.treebuilder/tree_scanner` | `pickDirectory` → URI string; `scanDirectory` → tree map |
| EventChannel | `com.treebuilder/scan_progress` | `{folders, files, current}` |

Flow:

1. `pickDirectory` → `ACTION_OPEN_DOCUMENT_TREE` → `takePersistableUriPermission` → return URI string.
2. `scanDirectory` on `Executors.newSingleThreadExecutor()` → recursive `DocumentFile.listFiles()`.
3. Progress emitted every 25 entries via `EventChannel` on main `Handler`.
4. Dart: subscribe to progress stream → `invokeMethod('scanDirectory')` → `compute(_parseScanResult)` → `deepCastMap` → `TreeNode.fromJson` → `renderTree`.

**Why SAF:** Android scoped storage prevents reliable `dart:io` file listing in user-picked trees; folders could appear while game files (`.iso`, `.chd`, `.cci`, `.3ds`, etc.) were skipped.

**Key types:** `androidx.documentfile:documentfile:1.1.0`, `lib/utils/map_cast.dart`

---

## Export / import

**File:** `lib/services/tree_export_service.dart`

| Format | Contents | Where |
|--------|----------|-------|
| JSON (single) | Full `TreeBuild` including `root` | Tree detail menu |
| JSON (library) | Array of `TreeBuild` | Library toolbar |
| Text | `treeText` only | Tree detail menu |

### Platform behavior

| Platform | Export | Import |
|----------|--------|--------|
| Android / iOS | `saveFile(bytes: utf8)` — bytes **required** | `pickFiles(withData: true)` → read `file.bytes` |
| Desktop | `saveFile` → path → `File.writeAsBytes` | `pickFiles` → `File(path).readAsString` |

Import accepts single JSON object or array; `TreeStorageService.importBuilds` merges by `id` (skips duplicates). Uses `deepCastMap` before `TreeBuild.fromJson`.

---

## Data model

### `TreeNode` — `lib/models/tree_node.dart`

| Field | Type | Notes |
|-------|------|-------|
| `name` | String | File or folder name (no path) |
| `isDirectory` | bool | |
| `children` | List\<TreeNode\> | Empty for files |

Computed: `fileCount`, `folderCount`. JSON via `toJson` / `fromJson`.

### `TreeBuild` — `lib/models/tree_build.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | UUID v4 |
| `rootPath` | String | Filesystem path or Android `content://` URI |
| `rootName` | String | Display name (folder name) |
| `root` | TreeNode | Full tree structure |
| `treeText` | String | Pre-rendered ASCII for display/export |
| `createdAt` | DateTime | ISO 8601 in JSON |
| `maxDepth` | int? | Depth limit used for scan; omitted when unlimited |

### `ScanProgress` — `lib/models/scan_progress.dart`

| Field | Type | Notes |
|-------|------|-------|
| `folders` | int | Folders encountered so far |
| `files` | int | Files encountered so far |
| `currentName` | String? | Last-read entry name |
| `phase` | ScanPhase | `scanning`, `building`, `saving` |

---

## Storage

**File:** `lib/services/tree_storage_service.dart`

- Path: `{appDocuments}/tree_library.json`
- `loadAll()` — sorted newest first
- `save(build)` — upsert by `id`
- `delete(id)`, `importBuilds(list)` — merge without duplicate ids

---

## Android configuration

| Item | Location |
|------|----------|
| NDK version | `android/app/build.gradle.kts` → `27.0.12077973` |
| DocumentFile | `androidx.documentfile:documentfile:1.1.0` |
| macOS file access | `com.apple.security.files.user-selected.read-write` in Debug/Release entitlements |

No broad storage permissions in `AndroidManifest.xml` — SAF grants per-folder read access.

---

## Key source files

| Area | Files |
|------|-------|
| Entry | `lib/main.dart` |
| Home | `lib/screens/home_screen.dart` |
| Library | `lib/screens/library_screen.dart` |
| Tree view | `lib/screens/tree_view_screen.dart` |
| Scan (Dart) | `lib/services/directory_scanner.dart`, `lib/services/android_tree_scanner.dart` |
| Scan (Kotlin) | `android/app/src/main/kotlin/com/treebuilder/tree_builder/MainActivity.kt` |
| Storage | `lib/services/tree_storage_service.dart` |
| Export | `lib/services/tree_export_service.dart` |
| Widgets | `lib/widgets/scan_loading_overlay.dart`, `lib/widgets/tree_text_view.dart` |
| Utils | `lib/utils/map_cast.dart` |
| Models | `lib/models/tree_node.dart`, `lib/models/tree_build.dart`, `lib/models/scan_progress.dart` |
| Tests | `test/directory_scanner_test.dart`, `test/map_cast_test.dart`, `test/widget_test.dart` |

---

## Known constraints / pitfalls

- **Android `rootPath`** is a `content://` URI — never pass to `dart:io` `File` or `Directory`.
- **Platform channel maps** arrive as `Map<Object?, Object?>` — use `deepCastMap` before any `fromJson` (scan results and import).
- **Mobile export** requires `bytes` on `saveFile`; desktop requires writing to returned path (see BJ-007).
- **Depth limit:** subfolders at `maxDepth` are leaves; files inside those subfolders are not listed.
- **Large trees:** full `root` + `treeText` stored in memory and JSON — 800+ file trees work but save/scroll may lag.
- **Hot reload** insufficient after `MainActivity.kt` changes — full restart required.
- **No scan cancel** — user must wait for completion on large directories.

---

## Cross-reference

- **What changed lately:** `docs/source control log.md`
- **Bugs and fixes:** `docs/bug journal.md`
