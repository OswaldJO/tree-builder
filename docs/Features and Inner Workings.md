# Directory Tree Builder — Features and Inner Workings

This is the **living product and architecture handbook**. It describes **what the app does today** and **where that lives in code** — not a changelog, not a setup tutorial.

**Before digging through the repo**, start here. Use it for orientation (UI → files), intended behavior, and edge cases.

| Other docs | Role |
|------------|------|
| [`source control log.md`](source%20control%20log.md) | What changed recently (commit-adjacent) |
| [`bug journal.md`](bug%20journal.md) | What broke and how it was fixed |
| `pubspec.yaml` / `scripts/sync_pods.sh` | Version + CocoaPods sync after `flutter clean` |

---

## Product shape

| Concern | Today |
|---------|--------|
| **Package / version** | `tree_builder` / `1.0.2` (`pubspec.yaml`) |
| **Display name** | Directory Tree Builder |
| **App ID** | `com.funnybearapps.directorytreebuilder` (iOS, Android, macOS, Linux) |
| **Stack** | Flutter Material 3, Dart `^3.8.1` |
| **Theme** | Dark only (`themeMode: ThemeMode.dark`, green seed `#66BB6A`) |
| **Shell** | Single home screen; other areas via `Navigator.push` (no router package) |
| **Persistence** | App documents: `tree_library.json`, `remote_settings.json` |

**Entry:** `lib/main.dart` → `TreeBuilderApp` → `HomeScreen`.

**Pushed screens:** Settings, Library, Tree detail, Remote directory picker.

| Concern | Package / mechanism |
|---------|---------------------|
| Local pick (desktop / iOS) | Desktop: `file_picker`. **iOS:** native `UIDocumentPicker` + security-scoped scan (`IosTreeScanner`) |
| Local pick + scan (Android) | SAF via `MethodChannel` / `EventChannel` in `MainActivity.kt` |
| Remote SMB | `smb_connect` — browse + scan |
| Remote SFTP | `dartssh2` — browse + scan |
| Library / settings files | `path_provider` + JSON |
| Export / import | `file_picker` save/open (bytes on mobile) |
| App icon | `assets/app_icon.png` → `flutter_launcher_icons` |
| Tree rendering | `TreeRenderer` + `CollapsibleTreeView` |

---

## Home

**File:** `lib/screens/home_screen.dart`

### Source selector + Choose Directory

Segmented control: **Local** | **SMB** | **SFTP**. One primary button: **Choose Directory**.

| Source | Flow |
|--------|------|
| **Local (Android)** | SAF folder pick → native `DocumentFile` scan → Dart isolate parse |
| **Local (iOS)** | Native folder picker with security-scoped access → FileManager scan (required for iCloud Drive) |
| **SMB / SFTP** | Load Settings credentials → remote folder browser → scan **selected path only** |

If SMB/SFTP is selected without host+username configured → snackbar with **Settings** action; scan does not start.

After a successful scan: auto-save to library → show preview (`CollapsibleTreeView`) → **Open** opens tree detail.

### Scan options

| Option | Default | Effect |
|--------|---------|--------|
| **Expand all folders** | Off | Initial UI expansion; stored as `TreeBuild.expandAllFolders` |
| **Limit folder depth** | Off | Caps folder recursion (`maxDepth`); field min 1 when enabled |

### Scanning UX

`ScanLoadingOverlay` while scanning: phases **Scanning** → **Building tree** → **Saving**; live folder/file counts (progress every ~25 entries).

**Key types:** `ScanSourceType`, `ScanProgress`, `DirectoryScanner`, `SmbDirectoryScanner`, `SftpDirectoryScanner`, `TreeStorageService`, `RemoteSettingsService`

**Key widgets:** `lib/widgets/scan_loading_overlay.dart`

---

## Library

**File:** `lib/screens/library_screen.dart`

- Lists saved `TreeBuild`s: name, date, folder/file counts.
- **Sort** (app bar, session-only, default newest): A→Z, Z→A, newest first, oldest first.
- **Favorites:** heart on each row; favorited trees under **Favorites** at top, then **All trees**. Sort applies within each section.
- **Import** / **Export all** (JSON library file).
- Tap → tree detail (with delete). Pull-to-refresh.
- `scanSourceType` is stored on builds but **not** shown as a badge in the list UI.

**Key types:** `LibrarySortOption`, `sortTreeBuilds()`, `TreeExportService`, `TreeStorageService`

---

## Settings

**File:** `lib/screens/settings_screen.dart`

Credentials for remote scan (not entered on Home):

| Protocol | Fields |
|----------|--------|
| **SMB** | Host, domain (optional), username, password |
| **SFTP** | Host, port (default 22), username, password |

Saved via **Save** to `{appDocuments}/remote_settings.json`. Passwords are **plaintext on device** and are **not** included in tree library exports. `isConfigured` = non-empty host + username.

**Key types:** `RemoteSettings`, `SmbSettings`, `SftpSettings`, `RemoteSettingsService`

---

## Remote directory picker

**File:** `lib/screens/remote_directory_picker_screen.dart`  
Helper: `pickRemoteDirectory(...)`

Opens after Choose Directory when source is SMB or SFTP.

| Protocol | Browse behavior |
|----------|-----------------|
| **SMB** | Share list at root (not selectable); open a share, then subfolders; **Select this folder** once inside a share. Hides IPC and shares ending in `$`. |
| **SFTP** | Starts at `/`; any folder (including `/`) can be selected; Up disabled at root |

Connection closed when the picker is dismissed.

**Key types:** `SmbRemoteBrowser`, `SftpRemoteBrowser`, `RemoteDirectoryEntry`, `RemotePath`

---

## Tree detail

**File:** `lib/screens/tree_view_screen.dart`

- Info: `rootPath`, folder/file counts.
- Interactive `CollapsibleTreeView`.
- App bar: **Expand all**, **Collapse all**, **Copy visible tree**, export JSON/text, delete (when opened from Library).
- Copy and text/JSON `treeText` use the **currently visible** (expanded/collapsed) ASCII. Full `root` structure is still in JSON for re-import.
- Manual expand/collapse is **in-memory only** until a new save; only `expandAllFolders` from scan is persisted.

---

## Collapsible tree

**Files:** `lib/widgets/collapsible_tree_view.dart`, `lib/utils/tree_renderer.dart`

### Interaction

- Folders **with children** show a chevron; tap toggles expand/collapse.
- Files and empty folders: no chevron.
- Path keys: slash-separated from root children (`folder/subfolder`).

### Expansion

| Source | Initial state |
|--------|----------------|
| `expandAllFolders: false` | Collapsed (top-level entries only) |
| `expandAllFolders: true` | All folder paths expanded |
| User / app bar | In-memory only |

### Text rendering

- `TreeRenderer.renderFull` — full ASCII at scan time → `TreeBuild.treeText`
- `TreeRenderer.renderVisible` — ASCII for current expansion
- `CollapsibleTreeViewState.visibleTreeText` — copy / export

---

## Directory scanning

### Local — Android (SAF)

**Files:** `lib/services/android_tree_scanner.dart`, `android/.../MainActivity.kt`

| Channel | Purpose |
|---------|---------|
| `com.treebuilder/tree_scanner` | `pickDirectory`, `scanDirectory` |
| `com.treebuilder/scan_progress` | `{folders, files, current}` |

`ACTION_OPEN_DOCUMENT_TREE` → background `DocumentFile` walk → Dart `compute()` + `deepCastMap` → `DirectoryScanner.fromScanResult`.

`rootPath` is a **`content://` URI** — not usable with `dart:io`.

### Local — iOS (security-scoped document picker)

**Files:** `lib/services/ios_tree_scanner.dart`, `ios/Runner/AppDelegate.swift`

| Channel | Purpose |
|---------|---------|
| `com.treebuilder/tree_scanner` | `pickDirectory`, `scanDirectory` (same names as Android) |
| `com.treebuilder/scan_progress` | `{folders, files, current}` |

`UIDocumentPicker` for folders → `startAccessingSecurityScopedResource` → FileManager walk → Dart `compute()` parse. Required for **iCloud Drive** paths under `Mobile Documents/com~apple~CloudDocs/…`.

### Local — desktop (`dart:io`)

**File:** `lib/services/directory_scanner.dart`

- `FilePicker.getDirectoryPath` then `_scanWithIo`.
- `list(followLinks: false)`; non-directories treated as files.
- Sort: directories first, then case-insensitive name.
- Permission errors → placeholder node `[permission denied: …]`.

### SMB

**Files:** `lib/services/smb_directory_scanner.dart`, `smb_remote_browser.dart`

- Auth: `SmbConnect.connectAuth(host, username, password, domain)`.
- Path: `/share/folder/...` (first segment = share name).
- `rootPath` stored as `smb://host/path` (no credentials).
- List/scan errors under a folder → `[error: …]` child node.

### SFTP

**Files:** `lib/services/sftp_directory_scanner.dart`, `sftp_remote_browser.dart`

- `SSHSocket` + `SSHClient` + `sftp()`; password via `onPasswordRequest`.
- `rootPath` stored as `sftp://host[:port]/path`.

### Shared scan rules

- Progress helper: `lib/services/scan_counters.dart` (report every 25 items, yield to UI).
- When `currentDepth >= maxDepth`, directory children are empty — **nested files under that leaf are omitted**.
- Skip `.` / `..` on remote listings.

---

## Export / import

**File:** `lib/services/tree_export_service.dart`

| Format | Visible tree? | Notes |
|--------|---------------|-------|
| Text export | Yes | Uses `visibleTreeText` when provided |
| JSON (single) | `treeText` field may be visible ASCII | Full `root` still present for re-import |
| JSON (library) | Full builds as stored | Array of `TreeBuild` |
| Copy clipboard | Yes | From detail |

| Platform | Export | Import |
|----------|--------|--------|
| Android / iOS | `saveFile(bytes: utf8)` | `pickFiles(withData: true)` |
| Desktop | Write path from `saveFile` | Read file path |

**Storage:** `lib/services/tree_storage_service.dart` — `{documents}/tree_library.json`.  
`save`: update by id or insert at index 0.  
`importBuilds`: skip duplicate ids.

---

## Data model

### `TreeNode` — `lib/models/tree_node.dart`

| Field | Notes |
|-------|--------|
| `name` | File or folder name |
| `isDirectory` | |
| `children` | Empty for files |
| `fileCount` | Files only |
| `folderCount` | **Includes this directory** + descendants |

### `TreeBuild` — `lib/models/tree_build.dart`

| Field | Notes |
|-------|--------|
| `id` | UUID v4 |
| `rootPath` | Local path, Android `content://`, or `smb://` / `sftp://` display URI |
| `rootName` | Display name |
| `root` | Full tree (always complete) |
| `treeText` | Full ASCII at scan (`renderFull`) |
| `createdAt` | ISO 8601 |
| `maxDepth` | Omitted in JSON if unlimited |
| `expandAllFolders` | Default `false`; JSON only if true |
| `scanSourceType` | `local` (default), `smb`, `sftp`; JSON only if non-local |
| `isFavorite` | Default `false`; JSON only if true |

### Other models

| Type | File | Role |
|------|------|------|
| `ScanSourceType` | `scan_source_type.dart` | Local / SMB / SFTP |
| `ScanProgress` | `scan_progress.dart` | Counts + phase |
| `LibrarySortOption` | `library_sort_option.dart` | Library sort + `sortTreeBuilds` |
| `RemoteSettings` / SMB / SFTP | `remote_settings.dart` | Credentials + `RemotePath` helpers |

---

## Platform configuration

### Android

| Item | Location |
|------|----------|
| Application ID / namespace | `com.funnybearapps.directorytreebuilder` |
| Label | Directory Tree Builder |
| INTERNET | `AndroidManifest.xml` (SMB/SFTP) |
| NDK | `27.0.12077973` in `app/build.gradle.kts` |
| DocumentFile | `androidx.documentfile:documentfile:1.1.0` |
| Native scan | `MainActivity.kt` under `com/funnybearapps/directorytreebuilder/` |

### iOS

| Item | Location |
|------|----------|
| Bundle ID | `com.funnybearapps.directorytreebuilder` |
| Display name | `CFBundleDisplayName` in `Info.plist` |
| Minimum iOS | 13.0 (`Podfile`) |
| Local network | `NSLocalNetworkUsageDescription` |
| Photo library | `NSPhotoLibraryUsageDescription` (required by `file_picker` / DKImagePickerController) |
| SPM | Disabled (`pubspec.yaml` → `enable-swift-package-manager: false`) |
| UIScene | Disabled for this project — classic `AppDelegate` (BJ-009 blank screen on iOS 26 devices) |
| Pod sync | `./scripts/sync_pods.sh` |

### macOS

| Item | Location |
|------|----------|
| Bundle ID | `com.funnybearapps.directorytreebuilder` |
| PRODUCT_NAME | `DirectoryTreeBuilder` (`Configs/AppInfo.xcconfig`) |
| Display name | `CFBundleDisplayName` |
| Entitlements | user-selected files R/W; `network.client` (Debug also network.server + JIT) |

---

## Key source files

| Area | Files |
|------|-------|
| Entry | `lib/main.dart` |
| Screens | `home_screen.dart`, `library_screen.dart`, `settings_screen.dart`, `tree_view_screen.dart`, `remote_directory_picker_screen.dart` |
| Scan | `directory_scanner.dart`, `android_tree_scanner.dart`, `ios_tree_scanner.dart`, `smb_directory_scanner.dart`, `sftp_directory_scanner.dart`, `smb_remote_browser.dart`, `sftp_remote_browser.dart`, `scan_counters.dart`, `MainActivity.kt`, `AppDelegate.swift` |
| Storage / export | `tree_storage_service.dart`, `tree_export_service.dart`, `remote_settings_service.dart` |
| Tree UI | `collapsible_tree_view.dart`, `tree_text_view.dart`, `scan_loading_overlay.dart` |
| Utils | `tree_renderer.dart`, `map_cast.dart` |
| Models | `tree_node.dart`, `tree_build.dart`, `scan_progress.dart`, `scan_source_type.dart`, `remote_settings.dart`, `library_sort_option.dart` |
| Tests | `directory_scanner_test.dart`, `map_cast_test.dart`, `tree_renderer_test.dart`, `library_sort_test.dart`, `widget_test.dart` |
| Scripts | `scripts/sync_pods.sh` |

---

## Known pitfalls

- **Android `rootPath`** is `content://` only — do not open with `dart:io`.
- **Platform channel maps** — use `deepCastMap` / isolate parse before `fromJson` (see bug journal).
- **Mobile export** — `bytes` required on `saveFile`.
- **Depth limit** — leaf folders hide nested files when at max depth.
- **`treeText` in library** — full tree at scan; copy/export may be collapsed view.
- **Expansion toggles** — not auto-saved after manual collapse/expand.
- **Library sort** — not persisted across app launches.
- **Remote credentials** — plaintext in `remote_settings.json`; not in library JSON.
- **SMB** — must enter a share before selecting a folder; admin `$` shares filtered.
- **Symlinks** — local IO scan uses `followLinks: false`.
- **Channel / Kotlin changes** — need full app restart, not hot reload.
- **Large trees** — fully expanded UI may scroll slowly.
- **Release signing** — Android release still uses debug signing until a real config is added.
- **iOS pods after `flutter clean`** — run `./scripts/sync_pods.sh` or Xcode reports Podfile.lock sandbox mismatch.
- **Physical iOS blank white screen (iOS 26)** — UIScene / implicit engine migration can leave a white storyboard with no Flutter pixels on device while simulator works (BJ-009). Keep classic AppDelegate; do not re-add `UIApplicationSceneManifest` until Flutter fixes the device path.
- **Launch flash** — iOS `LaunchScreen.storyboard` + `Main.storyboard` and Android `launch_background` use dark `#121412` with centered app icon (`SplashIcon` / `splash_icon`) so the pre-Flutter frame matches dark theme.
- **iOS iCloud / Files folders** — must use security-scoped picker URL (BJ-010); plain `dart:io` on `file_picker` paths fails with “Directory does not exist”.

---

## Cross-reference

- **What changed lately:** [`docs/source control log.md`](source%20control%20log.md)
- **Bugs and fixes:** [`docs/bug journal.md`](bug%20journal.md)
- **Agent rule:** `.cursor/rules/docs-sync.mdc` — update this handbook when behavior or architecture changes
