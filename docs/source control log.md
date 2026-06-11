This log will change with every commit in version control.

The purpose of this is to give a brief description of what happened since the last commit.

For the **living product and architecture handbook**, see `Features and Inner Workings.md`.

---

current release: 1

## Updates

- **Initial app — Tree Builder (Jun 11 2026):** Flutter app that picks a directory, generates an ASCII folder/file tree, saves builds to a local library, and supports export/import (JSON and plain text). **Action:** `flutter run` on target platform.

- **File visibility — scanner fixes (Jun 11 2026):** Desktop/macOS scanner now treats any non-directory entity as a file (fixes `.iso`, `.chd`, and other extensions). Android uses Storage Access Framework (`DocumentFile`) instead of `dart:io` alone. **Action:** Full restart after pull; rescan ROM folders on Android.

- **Depth limit — integer field (Jun 11 2026):** Replaced depth dropdown with a numeric text field under **Limit folder depth** so any depth ≥ 1 can be entered. **Action:** Hot restart.

- **Home screen — layout overflow (Jun 11 2026):** Controls card is scrollable; tree preview uses remaining space. Fixes yellow/black overflow when keyboard opens for depth field. **Action:** Hot restart.

- **Android — platform channel map cast (Jun 11 2026):** Fixed crash `type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>'` when parsing native scan results. **Action:** Full restart on Android.

- **Android — NDK alignment (Jun 11 2026):** Set `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts` to match `file_picker`, `path_provider_android`, and `flutter_plugin_android_lifecycle`. **Action:** Rebuild if NDK warning reappears.

- **Scan UX — loading overlay & background scan (Jun 11 2026):** Full-screen progress overlay with folder/file counts and phase labels. Android scan runs on a background thread; tree parse/render runs in a Dart isolate. Overlay appears after folder pick, not during system picker. **Action:** Full restart on Android (native code changed).

## Focus for next release

- Smoke-test large ROM libraries on Android (thousands of files) for scan time and memory.
- Verify export/import round-trip for trees built on Android (content URIs in `rootPath`).
- Desktop/iOS: confirm `file_picker` directory access on all target platforms.

## Minimum for next release

- Smoke test: Pick folder → tree shows both folders and files (including `.iso` / `.chd`) on Android — (**not verified**).
- Smoke test: Limit depth to 3 → nested folders truncate, files at allowed depth visible — (**not verified**).
- Smoke test: Scan shows loading overlay with live counts, no black freeze — (**not verified**).
- Smoke test: Library save, open, delete, export JSON/text, import JSON — (**not verified**).
- Smoke test: macOS/desktop pick directory → full tree with files — (**passed** Jun 11 2026, unit tests).

## Future plans

- Optional filters (hide `node_modules`, dotfiles, etc.).
- Search within generated tree.
- Resume or cancel long scans.
- Persist Android tree URI bookmarks for re-scan without re-picking folder.
- Progress percentage when total entry count is known.
