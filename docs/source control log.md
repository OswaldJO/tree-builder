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

- **Android — NDK alignment (Jun 11 2026):** Set `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts`. **Action:** Rebuild if NDK warning reappears.

- **Scan UX — loading overlay & background scan (Jun 11 2026):** Full-screen progress overlay with folder/file counts and phase labels. Android scan on background thread; parse in Dart isolate. **Action:** Full restart on Android.

- **Export/import — mobile bytes (Jun 11 2026):** Android/iOS export passes UTF-8 bytes to `saveFile`; import uses `withData: true`. **Action:** Hot restart.

- **Collapsible tree UI (Jun 11 2026):** Interactive folder expand/collapse in home preview and tree detail. Tap folders with chevrons; **Expand all** / **Collapse all** in detail app bar. Default: all folders collapsed (top level only). **Action:** Hot restart.

- **Export visible tree only (Jun 11 2026):** Copy, text export, and JSON `treeText` field reflect the currently expanded/collapsed view, not the full tree. Full `root` JSON structure is still exported for re-import. **Action:** Hot restart.

- **Expand all folders checkbox (Jun 11 2026):** New home-screen option above **Limit folder depth**. When checked, generated trees start fully expanded; saved as `expandAllFolders` on `TreeBuild`. Default unchecked (collapsed). **Action:** Hot restart.

- **Remote scan — SMB & SFTP (Jun 11 2026):** Home screen source selector: **Local**, **SMB**, or **SFTP**. Remote sources open a connection dialog (host, credentials, path); pure-Dart scanners via `smb_connect` and `dartssh2`. `TreeBuild.scanSourceType` and display URI stored in library (passwords never saved). Android `INTERNET` permission added. **Action:** Full restart; macOS rebuild for network client entitlement.

- **Settings + remote directory picker (Jun 11 2026):** Gear icon in app bar opens **Settings** for SMB/SFTP credentials (saved to `remote_settings.json`). **Choose Directory** is unified for all sources; SMB/SFTP browse shares/folders in a picker before scanning the selected folder only. **Action:** Hot restart; configure remote connections in Settings first.

- **Library — sort & favorites (Jun 11 2026):** Sort menu (A→Z, Z→A, newest, oldest). Heart trees to pin them in a **Favorites** section at the top; `isFavorite` on `TreeBuild`. **Action:** Hot restart.

- **iOS & Android build fixes (Jul 8 2026):** Disabled Swift Package Manager (CocoaPods only). iOS `platform :ios, '13.0'`, `pod install`, `NSLocalNetworkUsageDescription` for SMB/SFTP. Verified `flutter build apk --debug` and `flutter build ios --simulator`. **Action:** Free disk space if builds fail with “No space left on device”; run `flutter clean` then `cd ios && pod install`.

- **App icon (Jul 9 2026):** Custom “Data Tree Builder” artwork as launcher icon on iOS and Android via `flutter_launcher_icons` (`assets/app_icon.png`). **Action:** Full restart to see new icon on device/simulator.

- **Theme — force dark mode (Jul 9 2026):** App always uses `darkTheme` (`themeMode: ThemeMode.dark`). iOS simulator was showing pale light theme when system appearance was light; Android used dark when system was dark. **Action:** Hot restart.

- **Bundle ID (Jul 10 2026):** Changed app ID to `com.funnybearapps.datatreebuilder` (iOS, Android, macOS, Linux). **Action:** Uninstall old app before reinstalling; full rebuild.

- **iOS Info.plist — photo library purpose string (Jul 10 2026):** Added `NSPhotoLibraryUsageDescription` to fix App Store ITMS-90683 (`file_picker` / DKImagePickerController references photo library APIs). **Action:** Rebuild and resubmit.

- **Pod sync script (Jul 15 2026):** Added `scripts/sync_pods.sh` (`flutter pub get` + `pod install`) for CocoaPods sandbox / Podfile.lock mismatches after `flutter clean`. Command noted under `version` in `pubspec.yaml`. **Action:** `./scripts/sync_pods.sh` then open `ios/Runner.xcworkspace`.

- **Rename — Directory Tree Builder (Jul 15 2026):** Display name → **Directory Tree Builder**; bundle/app ID → `com.funnybearapps.directorytreebuilder` (iOS, Android, macOS, Linux). **Action:** Uninstall old app; full rebuild; App Store Connect may need the new bundle ID if creating a new app listing.

- **Features handbook rewrite (Jul 15 2026):** Rebuilt `docs/Features and Inner Workings.md` as the living product + architecture map (screens, scan paths, models, pitfalls). **Action:** Open `docs/Features and Inner Workings.md`.

- **iOS physical device blank screen (Jul 22 2026):** White screen on real iPad (iOS 26) while simulator worked. Caused by Flutter UIScene / `FlutterImplicitEngineDelegate` migration. Reverted to classic `AppDelegate` + removed `UIApplicationSceneManifest`. **Action:** Delete app from iPad, full rebuild: `flutter clean && ./scripts/sync_pods.sh && flutter run -d <ipad>`.

- **Dark splash / launch screen (Jul 22 2026):** Default white `LaunchScreen` + `Main.storyboard` (and Android launch drawable) looked like a blank white pause before first Flutter frame / permission prompts. Set dark green `#121412` backgrounds with centered app icon. **Action:** Full rebuild on device.

- **iOS iCloud folder scan (Jul 22 2026):** Fixed BJ-010 — Local pick on iOS uses security-scoped `UIDocumentPicker` + native FileManager scan (`IosTreeScanner`) so iCloud Drive folders work. **Action:** Full restart on device; pick folder again.

## Focus for next release

- Confirm export/import round-trip on Android after BJ-007 fix.
- Smoke-test SMB/SFTP scan against a real server.
- Profile collapsible tree scroll performance on 800+ file trees.
- iOS: smoke-test directory scan and mobile export.

## Minimum for next release

- Smoke test: Pick folder → folders and files on Android — (**passed** Jun 11 2026, `Video Games` — 215 folders, 851 files).
- Smoke test: Limit depth to 3 — (**not verified** on device).
- Smoke test: Loading overlay, no black freeze — (**passed** Jun 11 2026).
- Smoke test: Library save, open, delete — (**passed** Jun 11 2026).
- Smoke test: Collapse/expand folders; export matches visible tree — (**not verified**).
- Smoke test: **Expand all folders** checkbox → fully expanded on generate — (**not verified**).
- Smoke test: SMB connect & scan — (**not verified**).
- Smoke test: SFTP connect & scan — (**not verified**).
- Smoke test: Export JSON/text on Android — (**pending** re-test after BJ-007 fix).
- Smoke test: Import JSON — (**not verified**).
- Smoke test: macOS/desktop scan — (**passed** Jun 11 2026, unit tests).

## Future plans

- Optional filters (hide `node_modules`, dotfiles, etc.).
- Search within generated tree.
- Cancel button for long scans.
- Persist Android tree URI bookmarks for re-scan.
- Progress percentage when total entry count is known.
- Share sheet export (Android `ACTION_SEND`).
