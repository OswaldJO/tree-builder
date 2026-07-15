#!/usr/bin/env bash
# Sync Flutter plugins and CocoaPods so Xcode's sandbox matches Podfile.lock.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> ios pod install"
(
  cd "$ROOT/ios"
  pod install --repo-update
)

if [[ -f "$ROOT/macos/Podfile" ]]; then
  echo "==> macos pod install"
  if (
    cd "$ROOT/macos"
    pod install --repo-update
  ); then
    echo "macos pods OK"
  else
    echo "warning: macos pod install failed (iOS is still OK)"
  fi
fi

echo "==> Done. Open ios/Runner.xcworkspace (not .xcodeproj) to build."
