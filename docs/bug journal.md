# Bug journal

Chronicle of bugs encountered in **Tree Builder** and how they were fixed.
For release notes style summaries, see `source control log.md`.
For architecture context, see `Features and Inner Workings.md`.

---

## Scanning / tree generation

### BJ-001 — Game files missing from tree; only folders shown
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | ASCII tree listed folder hierarchy (e.g. `PSP/GAME/`, `3DS/Games/`) but no game files (`.iso`, `.chd`, `.cci`, `.3ds`, etc.). |
| **Cause** | (1) Dart scanner only added entries when `FileSystemEntity.type` returned `file` or `link`, silently skipping other types. (2) On Android, SAF tree URIs are not plain paths; `dart:io` `Directory.list()` does not reliably enumerate files under scoped storage. |
| **Fix** | Desktop: treat any non-directory as a file; use `entity is File` / `entity is Directory` from `list()`. Android: native `DocumentFile` recursive scan via `MethodChannel` (`pickDirectory` + `scanDirectory`), persistable URI permission after pick. |
| **Commit** | *Not committed yet* |

### BJ-002 — Scan crash: `Map<Object?, Object?>` is not a subtype of `Map<String, dynamic>`
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | After picking folder on Android: `Failed to scan directory: type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>' in type cast`. |
| **Cause** | `MethodChannel` returns nested maps as `Map<Object?, Object?>`. `TreeNode.fromJson` cast children directly to `Map<String, dynamic>`. |
| **Fix** | Added `lib/utils/map_cast.dart` with `deepCastMap()` for recursive conversion before `fromJson`. |
| **Commit** | *Not committed yet* |

### BJ-003 — Black screen / app appears frozen during tree generation
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | After starting scan, screen went black; UI unresponsive for a long time on large folders (e.g. ROM libraries). |
| **Cause** | (1) Android `scanDirectory` ran synchronously on main thread in `onActivityResult`. (2) Large map parse + `renderTree` blocked UI isolate. (3) Home screen cleared tree preview while `_scanning` hid **Browse Library**, leaving nearly empty body. |
| **Fix** | Split Android pick (`pickDirectory`) from scan (`scanDirectory` on `Executors` thread); `EventChannel` for progress; `compute()` for parse; full-screen `ScanLoadingOverlay` with counts and phase labels. |
| **Commit** | *Not committed yet* |

---

## UI / layout

### BJ-004 — Column overflow when depth keyboard opens
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | `RenderFlex overflowed by X pixels on the bottom` — yellow/black stripes in `home_screen.dart` when IME visible for depth field. |
| **Cause** | Fixed-height `Column` with `Spacer` + depth `TextField`; keyboard reduced viewport below minimum content height. |
| **Fix** | Wrapped controls in `Flexible` + `SingleChildScrollView`; tree preview in separate `Expanded`; removed `Spacer`; overlay uses `Stack`. |
| **Commit** | *Not committed yet* |

---

## Export / import

### BJ-007 — Export fails on Android: bytes required
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | Snackbar on tree detail export: `Export failed: Invalid argument(s): Bytes are required on Android & iOS when saving a file.` |
| **Cause** | `TreeExportService` called `saveFile` without `bytes`, then attempted `File(path).writeAsString()` — mobile SAF save dialogs require in-memory bytes; returned path is not a writable filesystem path. |
| **Fix** | `exportAsJson`, `exportAsText`, `exportLibraryAsJson` encode content as UTF-8 `Uint8List` and pass `bytes:` to `saveFile` on Android/iOS. Desktop unchanged: `saveFile` → path → `File.writeAsBytes`. Import: `withData: true` + `deepCastMap` for JSON. |
| **Commit** | *Not committed yet* |

---

## Android build

### BJ-005 — NDK version mismatch warning
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | Build warning: project NDK 26.3.x but plugins require 27.0.12077973. |
| **Cause** | `ndkVersion = flutter.ndkVersion` in `build.gradle.kts` lagged plugin requirements. |
| **Fix** | Set `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts`. |
| **Commit** | *Not committed yet* |

---

## Design / limitations (not bugs)

### BJ-006 — Depth limit hides files inside leaf folders
| | |
|---|---|
| **When** | 2026-06-11 (identified during depth feature work) |
| **Symptom** | With **Limit folder depth** enabled, subfolders at max depth show as `name/` but files inside those folders do not appear. |
| **Cause** | By design: at `currentDepth >= maxDepth`, subdirectories are added as leaf nodes without recursing into them. |
| **Fix** | None planned — increase depth, disable limit, or accept truncated view. Documented in Features and Inner Workings. |
| **Commit** | N/A (by design) |

---

## Open / known issues

| ID | Issue | Notes |
|----|--------|--------|
| BJ-007 | Export on Android | Fix shipped; **pending device re-test** after hot restart. |
| — | Import JSON on Android | Uses `withData: true`; not device-verified yet. |
| — | Large scan memory / time | No cancel; 800+ file trees complete but may be slow to save/scroll. |
| — | iOS directory scan | Uses `dart:io` path flow; SAF parity not implemented. |

---

## How to add entries

1. Assign the next **BJ-###** id (BJ-008 next).
2. Include **symptom**, **cause**, **fix**, and **commit** (or *in progress* / *Not committed yet*).
3. Add a line to `source control log.md` **Updates** when the fix ships in a release.
4. Update `Features and Inner Workings.md` if user-visible behavior or architecture changed.
