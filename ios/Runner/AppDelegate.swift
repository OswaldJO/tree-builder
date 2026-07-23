import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {
  private let channelName = "com.treebuilder/tree_scanner"
  private let progressChannelName = "com.treebuilder/scan_progress"

  private var pendingPickResult: FlutterResult?
  private var accessedDirectoryURL: URL?
  private var progressSink: FlutterEventSink?
  private let scanQueue = DispatchQueue(label: "com.treebuilder.scan", qos: .userInitiated)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupTreeScannerChannels()
    return ok
  }

  private func setupTreeScannerChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.setupTreeScannerChannels()
      }
      return
    }

    let messenger = controller.binaryMessenger

    FlutterEventChannel(name: progressChannelName, binaryMessenger: messenger)
      .setStreamHandler(ProgressStreamHandler { [weak self] sink in
        self?.progressSink = sink
      })

    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "unavailable", message: "AppDelegate gone", details: nil))
          return
        }

        switch call.method {
        case "pickDirectory":
          self.pickDirectory(result: result)
        case "scanDirectory":
          let args = call.arguments as? [String: Any]
          let maxDepth = args?["maxDepth"] as? Int
          self.scanDirectory(maxDepth: maxDepth, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private func pickDirectory(result: @escaping FlutterResult) {
    if let existing = accessedDirectoryURL {
      existing.stopAccessingSecurityScopedResource()
      accessedDirectoryURL = nil
    }

    pendingPickResult = result

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder], asCopy: false)
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"],
        in: .open
      )
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.modalPresentationStyle = .formSheet

    guard let controller = window?.rootViewController else {
      pendingPickResult = nil
      result(FlutterError(code: "no_presenter", message: "No root view controller", details: nil))
      return
    }
    controller.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    let callback = pendingPickResult
    pendingPickResult = nil

    guard let url = urls.first else {
      callback?(nil)
      return
    }

    let accessing = url.startAccessingSecurityScopedResource()
    if !accessing {
      // Still try — some on-device paths don't need scoped access.
    }
    accessedDirectoryURL = url
    callback?(url.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let callback = pendingPickResult
    pendingPickResult = nil
    callback?(nil)
  }

  private func scanDirectory(maxDepth: Int?, result: @escaping FlutterResult) {
    guard let rootURL = accessedDirectoryURL else {
      result(
        FlutterError(
          code: "no_directory",
          message: "Pick a directory before scanning.",
          details: nil
        )
      )
      return
    }

    scanQueue.async { [weak self] in
      guard let self else { return }
      do {
        let payload = try self.buildScanPayload(rootURL: rootURL, maxDepth: maxDepth)
        DispatchQueue.main.async {
          result(payload)
          rootURL.stopAccessingSecurityScopedResource()
          self.accessedDirectoryURL = nil
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(code: "scan_failed", message: error.localizedDescription, details: nil)
          )
          rootURL.stopAccessingSecurityScopedResource()
          self.accessedDirectoryURL = nil
        }
      }
    }
  }

  private func buildScanPayload(rootURL: URL, maxDepth: Int?) throws -> [String: Any] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue
    else {
      throw NSError(
        domain: "TreeBuilder",
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Directory does not exist or is not accessible: \(rootURL.path). "
            + "If this is an iCloud folder, open it once in the Files app so it downloads, then try again.",
        ]
      )
    }

    let counters = ScanCounters()
    emitProgress(folders: 0, files: 0, current: nil)
    let rootName = rootURL.lastPathComponent
    let rootNode = try buildNode(
      at: rootURL,
      name: rootName,
      currentDepth: 1,
      maxDepth: maxDepth,
      counters: counters
    )

    return [
      "rootName": rootName,
      "rootPath": rootURL.path,
      "root": rootNode,
    ]
  }

  private func buildNode(
    at url: URL,
    name: String,
    currentDepth: Int,
    maxDepth: Int?,
    counters: ScanCounters
  ) throws -> [String: Any] {
    var children: [[String: Any]] = []

    do {
      let keys: [URLResourceKey] = [
        .isDirectoryKey,
        .isRegularFileKey,
        .nameKey,
        .isHiddenKey,
      ]
      let contents = try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: keys,
        options: [.skipsPackageDescendants]
      )

      let sorted = contents.sorted { lhs, rhs in
        let lDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if lDir != rDir { return lDir && !rDir }
        return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent)
          == .orderedAscending
      }

      for childURL in sorted {
        let values = try childURL.resourceValues(forKeys: Set(keys))
        let childName = values.name ?? childURL.lastPathComponent
        let isDir = values.isDirectory ?? false

        if isDir {
          counters.folders += 1
          counters.maybeEmit { [weak self] in
            self?.emitProgress(
              folders: counters.folders,
              files: counters.files,
              current: childName
            )
          }

          if let maxDepth, currentDepth >= maxDepth {
            children.append([
              "name": childName,
              "isDirectory": true,
              "children": [],
            ])
          } else {
            children.append(
              try buildNode(
                at: childURL,
                name: childName,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                counters: counters
              )
            )
          }
        } else {
          counters.files += 1
          counters.maybeEmit { [weak self] in
            self?.emitProgress(
              folders: counters.folders,
              files: counters.files,
              current: childName
            )
          }
          children.append([
            "name": childName,
            "isDirectory": false,
            "children": [],
          ])
        }
      }
    } catch {
      children.append([
        "name": "[error: \(error.localizedDescription)]",
        "isDirectory": false,
        "children": [],
      ])
    }

    return [
      "name": name,
      "isDirectory": true,
      "children": children,
    ]
  }

  private func emitProgress(folders: Int, files: Int, current: String?) {
    DispatchQueue.main.async { [weak self] in
      self?.progressSink?(
        [
          "folders": folders,
          "files": files,
          "current": current as Any,
        ] as [String: Any]
      )
    }
  }
}

private final class ScanCounters {
  var folders = 0
  var files = 0
  private var itemsSinceEmit = 0

  func maybeEmit(_ emit: () -> Void) {
    itemsSinceEmit += 1
    if itemsSinceEmit >= 25 {
      itemsSinceEmit = 0
      emit()
    }
  }
}

private final class ProgressStreamHandler: NSObject, FlutterStreamHandler {
  private let onListen: (FlutterEventSink?) -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void) {
    self.onListen = onListen
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    onListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onListen(nil)
    return nil
  }
}
