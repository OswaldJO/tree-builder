This log will change with every commit in version control.

The purpose of this is to give a brief description of what happened since the last commit.

For the **living product and architecture handbook**, see `Features and Inner Workings.md`.

---

current release: 1

## Updates

- **Initial app — Tree Builder (Jun 11 2026):** Flutter app that picks a directory, generates an ASCII folder/file tree, saves builds to a local library, and supports export/import (JSON and plain text). **Action:** `flutter run` on target platform.

- **File visibility — scanner fixes (Jun 11 2026):** Desktop/macOS scanner treats any non-directory entity as a file (fixes `.iso`, `.chd`, `.cci`, `.3ds`, etc.). Android uses Storage Access Framework (`DocumentFile`) via native platform channels instead of `dart:io` alone. **Action:** Full restart after pull; rescan folders on Android.

- **Depth limit — integer field (Jun 11 2026):** Replaced depth dropdown with a numeric text field under **Limit folder depth** so any depth ≥ 1 can be entered. **Action:** Hot restart.

- **Home screen — layout overflow (Jun 11 2026):** Controls card is scrollable; tree preview uses remaining space. Fixes yellow/black overflow when keyboard opens for depth field. **Action:** Hot restart.

- **Android — platform channel map cast (Jun 11 2026):** Fixed crash `type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>'` when parsing native scan results. **Action:** Full restart on Android.

- **Android — NDK alignment (Jun 11 2026):** Set `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts` to match `file_picker`, `path_provider_android`, and `flutter_plugin_android_lifecycle`. **Action:** Rebuild if NDK warning reappears.

- **Scan UX — loading overlay & background scan (Jun 11 2026):** Full-screen progress overlay with folder/file counts and phase labels (Scanning → Building tree → Saving). Android scan runs on a background thread; tree parse/render runs in a Dart isolate. Overlay appears after folder pick, not during the system picker. **Action:** Full restart on Android (native code changed).

- **Export/import — mobile bytes (Jun 11 2026):** Android/iOS export passes UTF-8 `Uint8List` bytes to `file_picker` `saveFile`; desktop uses returned path + `File.writeAsBytes`. Import uses `withData: true` and `deepCastMap` for JSON parsing on mobile. **Action:** Hot restart; retry export as JSON or text.

## Focus for next release

- Confirm export/import round-trip on device after BJ-007 fix (JSON + text).
- Profile memory on very large trees (1000+ files) during save and scroll.
- iOS: smoke-test SAF-equivalent flows if/when iOS directory scan is added.

## Minimum for next release

- Smoke test: Pick folder → tree shows both folders and files on Android — (**passed** Jun 11 2026, e.g. `Video Games` — 215 folders, 851 files including `.cci` / `.3ds`).
- Smoke test: Limit depth to 3 → nested folders truncate, files at allowed depth visible — (**not verified** on device).
- Smoke test: Scan shows loading overlay with live counts, no black freeze — (**passed** Jun 11 2026, overlay shipped; user confirmed scan completes).
- Smoke test: Library save, open, delete — (**passed** Jun 11 2026, tree visible in library/detail).
- Smoke test: Export JSON/text from tree detail on Android — (**failed** Jun 11 2026 pre-fix; **pending** re-test after BJ-007 fix).
- Smoke test: Import JSON from library toolbar — (**not verified**).
- Smoke test: macOS/desktop pick directory → full tree with files — (**passed** Jun 11 2026, unit tests).

## Future plans

- Optional filters (hide `node_modules`, dotfiles, etc.).
- Search within generated tree.
- Cancel button for long scans.
- Persist Android tree URI bookmarks for re-scan without re-picking folder.
- Progress percentage when total entry count is known.
- Share sheet export (Android `ACTION_SEND`) as alternative to save dialog.
