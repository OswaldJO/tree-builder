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
| **Symptom** | ASCII tree listed folders but no game files (`.iso`, `.chd`, `.cci`, `.3ds`, etc.). |
| **Cause** | Dart type filtering skipped files; Android SAF paths incompatible with `dart:io` file listing. |
| **Fix** | Desktop: non-directory = file. Android: `DocumentFile` scan via platform channels. |
| **Commit** | *Not committed yet* |

### BJ-002 — Scan crash: `Map<Object?, Object?>` is not a subtype of `Map<String, dynamic>`
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | Android scan failed with map cast error after folder pick. |
| **Cause** | Nested `MethodChannel` maps not `Map<String, dynamic>`. |
| **Fix** | `lib/utils/map_cast.dart` → `deepCastMap()`. |
| **Commit** | *Not committed yet* |

### BJ-003 — Black screen / app frozen during tree generation
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | Black screen; UI frozen on large folder scans. |
| **Cause** | Main-thread scan; UI isolate parse; empty body during scan. |
| **Fix** | Background scan, `EventChannel` progress, `compute()`, `ScanLoadingOverlay`. |
| **Commit** | *Not committed yet* |

---

## UI / layout

### BJ-004 — Column overflow when depth keyboard opens
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | `RenderFlex overflowed` when IME open for depth field. |
| **Cause** | Fixed `Column` + `Spacer` with keyboard reduced height. |
| **Fix** | Scrollable controls; `Stack` overlay; separate `Expanded` for tree. |
| **Commit** | *Not committed yet* |

---

## Export / import

### BJ-007 — Export fails on Android: bytes required
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | `Export failed: Invalid argument(s): Bytes are required on Android & iOS when saving a file.` |
| **Cause** | `saveFile` without `bytes`; attempted `File(path)` write on mobile. |
| **Fix** | UTF-8 `Uint8List` to `saveFile` on mobile; `withData: true` on import. |
| **Commit** | *Not committed yet* |

---

## Android build

### BJ-005 — NDK version mismatch warning
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | Plugins require NDK 27.0.12077973; project used 26.3.x. |
| **Cause** | `ndkVersion = flutter.ndkVersion` lagged. |
| **Fix** | Pinned `ndkVersion = "27.0.12077973"`. |
| **Commit** | *Not committed yet* |

---

## Design / limitations (not bugs)

### BJ-006 — Depth limit hides files inside leaf folders
| | |
|---|---|
| **When** | 2026-06-11 |
| **Symptom** | At `maxDepth`, subfolders show as leaves without inner files. |
| **Cause** | By design — no recursion past depth limit. |
| **Fix** | Increase depth or disable limit. |
| **Commit** | N/A |

### BJ-008 — Manual expand/collapse not persisted to library
| | |
|---|---|
| **When** | 2026-06-11 (collapsible tree feature) |
| **Symptom** | User collapses folders in detail view; reopening from library resets to `expandAllFolders` default. |
| **Cause** | Expansion state is in-memory in `CollapsibleTreeViewState` only; library stores `expandAllFolders` from scan options, not live UI state. |
| **Fix** | None planned — use **Expand all folders** at scan time or re-toggle manually. Future: persist expansion paths. |
| **Commit** | N/A (by design) |

---

## Open / known issues

| ID | Issue | Notes |
|----|--------|--------|
| BJ-007 | Export on Android | Fix shipped; **pending device re-test**. |
| — | Import JSON on Android | `withData: true`; not device-verified. |
| — | Collapsible tree on 800+ files | Works; full expand may be slow to scroll. |
| — | iOS directory scan | `dart:io` only; no SAF parity. |

---

## How to add entries

1. Assign the next **BJ-###** id (**BJ-009** next).
2. Include **symptom**, **cause**, **fix**, and **commit** (or *in progress* / *Not committed yet*).
3. Add a line to `source control log.md` **Updates** when the fix ships.
4. Update `Features and Inner Workings.md` if behavior or architecture changed.
