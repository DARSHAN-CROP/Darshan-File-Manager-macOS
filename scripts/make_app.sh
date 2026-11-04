#!/bin/bash
# Builds "Darshan File Manager.app" (universal, ad-hoc signed) and zips it to build/DarshanFileManager-macOS.zip
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0}"
APP="build/Darshan File Manager.app"
rm -rf build && mkdir -p build

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DarshanFileManager"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DarshanFileManager"

# icon: assets/icon_mac_1024.png -> AppIcon.icns
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/icon_mac_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) assets/icon_mac_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Darshan File Manager</string>
  <key>CFBundleDisplayName</key><string>Darshan File Manager</string>
  <key>CFBundleIdentifier</key><string>com.darshancorp.filemanager</string>
  <key>CFBundleExecutable</key><string>DarshanFileManager</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 Darshankumar Savsani (Darshan Corporation). MIT License.</string>
  <key>NSDownloadsFolderUsageDescription</key><string>Darshan File Manager sorts the folder you choose.</string>
  <key>NSDesktopFolderUsageDescription</key><string>Darshan File Manager sorts the folder you choose.</string>
  <key>NSDocumentsFolderUsageDescription</key><string>Darshan File Manager sorts the folder you choose.</string>
</dict>
</plist>
PLIST

# ad-hoc signature (no developer account): macOS will ask you to right-click > Open the first time
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "ad-hoc signature OK"
lipo -archs "$APP/Contents/MacOS/DarshanFileManager"

ditto -c -k --keepParent "$APP" build/DarshanFileManager-macOS.zip
ls -l build/DarshanFileManager-macOS.zip
