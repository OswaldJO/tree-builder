# Tree Builder — Features and Inner Workings

This document describes **how the app behaves today** and **where implementation lives**.
For a short, commit-adjacent summary of recent changes, see `source control log.md`.

---

## Product shape

- **Stack:** Flutter (Material 3), Dart 3.8+.
- **Persistence:** Single JSON file `tree_library.json` in app documents directory (`TreeStorageService`).
- **Navigation:** Single home screen + pushed routes for **Library** and **Tree detail**.
- **Platforms:** Android (SAF-native scan), macOS/desktop/iOS ( `file_picker` + `dart:io` scan).

| Concern | Package / mechanism |
|---------|---------------------|
| Directory pick (desktop) | `file_picker` `getDirectoryPath()` |
| Directory pick + scan (Android) | Custom `MethodChannel` + `EventChannel` in `MainActivity.kt` |
| Local library | `path_provider` + JSON file |
| Export / import | `file_picker` save/open dialogs |

---

## Home screen

**File:** `lib/screens/home_screen.dart`

### Choose Directory

1. User taps **Choose Directory**.
2. **Android:** Native folder picker (`ACTION_OPEN_DOCUMENT_TREE`) via `pickDirectory`; then background scan via `scanDirectory`.
3. **Other platforms:** `FilePicker.platform.getDirectoryPath()`, then `dart:io` recursive scan.
4. Result is saved to library automatically and shown in a scrollable preview; **Open** navigates to full tree view.

### Limit folder depth

- Checkbox **Limit folder depth** (off = unlimited).
- When checked, integer field **Depth levels** (minimum 1).
- `maxDepth` = how many folder levels below root are expanded. At the limit, subfolders appear as leaves (`name/`) without their children; files at each listed level are still included.

### Scanning UX

While scanning, `ScanLoadingOverlay` covers the screen:

- Phases: **Scanning directory** → **Building tree** → **Saving to library**
- Live folder/file counts (Android via `EventChannel`; desktop via periodic reports every 25 entries)
- Current item name when available

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

- Info card: path, folder count, file count.
- Monospace selectable ASCII tree (`TreeTextView`).
- Copy to clipboard; export as JSON or plain text.

---

## Directory scanning

### Desktop / macOS / iOS (`dart:io`)

**File:** `lib/services/directory_scanner.dart` — `_scanWithIo`, `_buildNode`

- Lists with `directory.list(followLinks: false)`.
- **Directory:** `entity is Directory` or `FileSystemEntity.type` == directory.
- **File:** everything else (no extension filter).
- Sort: directories first, then alphabetical.
- ASCII render: `├──`, `└──`, `│` prefixes; folders suffixed with `/`.

### Android (Storage Access Framework)

**Files:** `android/.../MainActivity.kt`, `lib/services/android_tree_scanner.dart`

| Channel | Name | Purpose |
|---------|------|---------|
| MethodChannel | `com.treebuilder/tree_scanner` | `pickDirectory`, `scanDirectory` |
| EventChannel | `com.treebuilder/scan_progress` | `{folders, files, current}` during scan |

Flow:

1. `pickDirectory` → persistable URI string (not a plain filesystem path).
2. `scanDirectory` on `Executors` background thread → recursive `DocumentFile.listFiles()`.
3. Progress emitted every 25 entries on main thread.
4. Dart receives map → `compute()` → `deepCastMap` → `TreeNode.fromJson` → `renderTree`.

**Why SAF:** Android scoped storage blocks reliable `dart:io` file listing in user-picked trees; folders could list while `.iso` / `.chd` files were skipped.

**Key types:** `androidx.documentfile:documentfile`, `lib/utils/map_cast.dart`

---

## Export / import

**File:** `lib/services/tree_export_service.dart`

| Format | Contents |
|--------|----------|
| JSON (single) | Full `TreeBuild` including `root` tree node |
| JSON (library) | Array of `TreeBuild` |
| Text | `treeText` only |

Import accepts single object or array; merges by `id` (skips duplicates).

---

## Data model

### `TreeNode` — `lib/models/tree_node.dart`

| Field | Type | Notes |
|-------|------|-------|
| `name` | String | File or folder name (no path) |
| `isDirectory` | bool | |
| `children` | List\<TreeNode\> | Empty for files |

Computed: `fileCount`, `folderCount`.

### `TreeBuild` — `lib/models/tree_build.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | UUID v4 |
| `rootPath` | String | Filesystem path or Android content URI |
| `rootName` | String | Display name |
| `root` | TreeNode | Full tree |
| `treeText` | String | Pre-rendered ASCII |
| `createdAt` | DateTime | ISO 8601 in JSON |
| `maxDepth` | int? | Optional; depth used for scan |

---

## Android configuration

| Item | Location |
|------|----------|
| NDK version | `android/app/build.gradle.kts` → `27.0.12077973` |
| DocumentFile dependency | `androidx.documentfile:documentfile:1.1.0` |
| macOS file access | `com.apple.security.files.user-selected.read-write` in entitlements |

No extra Android storage permissions in manifest — SAF grants per-folder access.

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
| Models | `lib/models/tree_node.dart`, `lib/models/tree_build.dart`, `lib/models/scan_progress.dart` |
| Tests | `test/directory_scanner_test.dart`, `test/map_cast_test.dart` |

---

## Known constraints / pitfalls

- **Android `rootPath`** is a `content://` URI string — do not pass to `dart:io` `File` or `Directory`.
- **Platform channel maps** arrive as `Map<Object?, Object?>` — always use `deepCastMap` before `fromJson` (see BJ-002).
- **Depth limit:** subfolders at max depth are leaves; their files are not listed unless you increase depth or scan unlimited.
- **Large trees:** `treeText` and full `root` JSON are held in memory and on disk — very large ROM sets may be slow to save/render.
- **Hot reload** is insufficient after Kotlin or `MainActivity` changes — full restart required.
- **Scan overlay** only starts after folder selection on Android; system picker is unchanged.

---

## Cross-reference

- **What changed lately:** `docs/source control log.md`
- **Bugs and fixes:** `docs/bug journal.md`
