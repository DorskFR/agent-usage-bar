#!/usr/bin/env bash
# Builds AgentMeter and packages it into a proper .app bundle (LSUIElement,
# so it lives only in the menu bar with no Dock icon).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="AgentMeter.app"
BUILD_DIR=".build/${CONFIG}"

echo "▸ swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "▸ assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BUILD_DIR}/AgentMeter" "${APP}/Contents/MacOS/AgentMeter"

cat > "${APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AgentMeter</string>
    <key>CFBundleDisplayName</key><string>AgentMeter</string>
    <key>CFBundleIdentifier</key><string>dev.dorsk.agentmeter</string>
    <key>CFBundleExecutable</key><string>AgentMeter</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc codesign so the keychain/network entitlements behave consistently.
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 || true

echo "✓ built ${APP}"
