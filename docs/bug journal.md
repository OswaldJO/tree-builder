# Bug journal

Chronicle of bugs encountered in **Tree Builder** and how they were fixed.
For release notes style summaries, see `source control log.md`.
For architecture context, see `Features and Inner Workings.md`.

---

## Scanning / tree generation

### BJ-001 — Game files (.iso, .chd) missing from tree; only folders shown
| | |
|---|---|
| **When** | 2026-06-11 (**in progress** → fixed same session) |
| **Symptom** | ASCII tree listed folder hierarchy (e.g. `PSP/GAME/`) but no `.iso` or `.chd` files anywhere. |
| **Cause** | Two layers: (1) Dart scanner only added entries when `FileSystemEntity.type` returned `file` or `link`, silently skipping `notFound` and other types. (2) On Android, `file_picker` returns SAF tree URIs; `dart:io` `Directory.list()` does not reliably enumerate files under scoped storage — directories could appear while files did not. |
| **Fix** | Desktop: treat any non-directory entity as a file; prefer `entity is File` / `entity is Directory` from `list()`. Android: native `DocumentFile` recursive scan via `MethodChannel`, with persistable URI permission after pick. |
| **Commit** | *Not committed yet* |

### BJ-002 — Scan crash: `Map<Object?, Object?>` is not a subtype of `Map<String, dynamic>`
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | After picking folder on Android, snackbar: `Failed to scan directory: type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>' in type cast`. |
| **Cause** | `MethodChannel` returns nested maps as `Map<Object?, Object?>`. `TreeNode.fromJson` cast `children` entries directly to `Map<String, dynamic>`. |
| **Fix** | Added `lib/utils/map_cast.dart` `deepCastMap()` for recursive conversion before `fromJson`. |
| **Commit** | *Not committed yet* |

### BJ-003 — Black screen / app appears frozen during tree generation
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | After starting scan, screen went black; UI unresponsive for a long time on large ROM folders. |
| **Cause** | (1) Android `scanDirectory` ran synchronously on main thread in `onActivityResult`. (2) Large map parse + `renderTree` on UI isolate. (3) Home screen cleared tree preview while `_scanning` hid **Browse Library**, leaving nearly empty body with only a small button spinner. |
| **Fix** | Split Android pick vs scan; scan on `Executors` background thread; `EventChannel` progress; `compute()` for parse; full-screen `ScanLoadingOverlay` with counts and phase labels. |
| **Commit** | *Not committed yet* |

---

## UI / layout

### BJ-004 — Column overflow when depth keyboard opens
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | `RenderFlex overflowed by X pixels on the bottom` — yellow/black stripes; `Column` in `home_screen.dart` when IME visible. |
| **Cause** | Fixed-height `Column` with `Spacer` + depth `TextField`; keyboard reduced viewport below minimum content height. |
| **Fix** | Wrapped controls in `Flexible` + `SingleChildScrollView`; tree preview in separate `Expanded`; removed `Spacer`. |
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

## Open / known issues

| ID | Issue | Notes |
|----|--------|--------|
| BJ-006 | Depth limit hides files inside leaf folders | At `maxDepth`, subfolders show as `name/` without listing contents. By design; increase depth or disable limit. |
| — | Large scan memory / time | No cancel; very large trees may stress JSON save and preview scroll. Monitor on device. |
| — | Android smoke tests not device-verified | Unit tests pass on desktop; ROM-folder scenarios need on-device confirmation. |

---

## How to add entries

1. Assign the next **BJ-###** id.
2. Include **symptom**, **cause**, **fix**, and **commit** (or *in progress* / *Not committed yet*).
3. Add a line to `source control log.md` **Updates** when the fix ships in a release.
4. Update `Features and Inner Workings.md` if user-visible behavior or architecture changed.
