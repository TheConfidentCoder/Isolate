#!/bin/bash
set -e

VERSION="${1:-v1.0.0}"
echo "=========================================================="
echo "⚡ PACKAGING ISOLATE RELEASE: ${VERSION}"
echo "=========================================================="

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/build/Release"
STAGING_DIR="$PROJECT_DIR/build/dmg_staging"
TMP_DMG="$DIST_DIR/tmp.dmg"
FINAL_DMG="$DIST_DIR/Isolate-${VERSION}.dmg"
FINAL_ZIP="$DIST_DIR/Isolate-${VERSION}-macOS.zip"
CHECKSUMS="$DIST_DIR/SHA256SUMS.txt"

# 1. Clean previous build artifacts
rm -rf "$DIST_DIR" "$PROJECT_DIR/build"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

# 2. Generate assets (Background & Icons)
echo "🎨 Step 1/6: Generating DMG assets..."
swift scripts/generate_assets.swift

# 3. Generate Xcode Project & Build Release App
echo "🔨 Step 2/6: Building Isolate.app (Release configuration)..."
xcodegen generate
xcodebuild -scheme Isolate \
  -configuration Release \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build

APP_BUNDLE="$BUILD_DIR/Isolate.app"

# 4. Embed CoreML Model & AppIcon into App Bundle Resources
echo "🧠 Step 3/6: Embedding Demucs Neural Engine CoreML model & AppIcon..."
MODEL_SOURCE="/Users/neokumar/Library/Application Support/Isolate/HTDemucs.mlmodelc"
if [ -d "$MODEL_SOURCE" ]; then
    cp -R "$MODEL_SOURCE" "$APP_BUNDLE/Contents/Resources/HTDemucs.mlmodelc"
    echo "   Embedded HTDemucs.mlmodelc (~287MB) into app bundle."
else
    echo "⚠️ Warning: $MODEL_SOURCE not found locally."
fi
if [ -f "$PROJECT_DIR/Assets/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "   Embedded AppIcon.icns into app bundle resources."
fi

# 5. Ad-Hoc Code Sign the App Bundle
echo "🔐 Step 4/6: Applying ad-hoc codesign to app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 6. Prepare Staging Folder for DMG
echo "📦 Step 5/6: Preparing DMG staging directory..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/Isolate.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Add One-Click First Run Quarantine Helper
cat <<'EOF' > "$STAGING_DIR/Open Isolate (First Run).command"
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$DIR/Isolate.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="/Applications/Isolate.app"
fi

echo "=========================================================="
echo "⚡ ISOLATE: INITIALIZING FIRST RUN"
echo "=========================================================="
if [ -d "$APP_PATH" ]; then
    echo "🔓 Removing macOS Gatekeeper quarantine from Isolate..."
    xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
    echo "🚀 Launching Isolate..."
    open "$APP_PATH"
else
    echo "⚠️ Isolate.app not found. Please drag Isolate.app into Applications."
fi
EOF
chmod +x "$STAGING_DIR/Open Isolate (First Run).command"

mkdir -p "$STAGING_DIR/.background"
cp "$PROJECT_DIR/Assets/dmg_background.png" "$STAGING_DIR/.background/dmg_background.png"
if [ -f "$PROJECT_DIR/Assets/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Assets/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
    SetFile -a C "$STAGING_DIR" 2>/dev/null || true
fi

# 7. Create and Format DMG
echo "💿 Step 6/6: Creating custom Nothing-themed DMG..."
rm -f "$TMP_DMG" "$FINAL_DMG"
hdiutil create -srcfolder "$STAGING_DIR" -volname "Isolate" -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" -format UDRW -size 680m "$TMP_DMG" -quiet

# Ensure clean unmount before attaching
hdiutil detach "/Volumes/Isolate" -force 2>/dev/null || true

# Mount the temporary DMG
MOUNT_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG")
MOUNT_DIR=$(echo "$MOUNT_OUT" | grep -o '/Volumes/.*' | head -n 1)
if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/Isolate"
fi
echo "   Mounted temporary DMG at $MOUNT_DIR"

# Configure Finder window layout using AppleScript
osascript <<EOF || true
tell application "Finder"
    tell disk "Isolate"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 560}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 110
        set background picture of theViewOptions to file ".background:dmg_background.png"
        
        try
            set position of item "Isolate.app" of container window to {165, 195}
        end try
        try
            set position of item "Applications" of container window to {495, 195}
        end try
        try
            set position of item "Open Isolate (First Run).command" of container window to {330, 310}
        end try
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Sync & Detach
sync
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet

# Convert to compressed read-only UDZO DMG
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

# 8. Create Standalone ZIP
echo "🗜 Creating standalone ZIP archive..."
cd "$BUILD_DIR"
zip -r -y -q "$FINAL_ZIP" "Isolate.app"
cd "$PROJECT_DIR"

# 9. Create macOS Installer Package (.pkg) with Postinstall Quarantine Stripper
echo "📦 Creating macOS Installer Package (.pkg)..."
FINAL_PKG="$DIST_DIR/Isolate-${VERSION}.pkg"
PKG_SCRIPTS="$DIST_DIR/pkg_scripts"
mkdir -p "$PKG_SCRIPTS"
cat <<'EOF' > "$PKG_SCRIPTS/postinstall"
#!/bin/bash
/usr/bin/xattr -dr com.apple.quarantine /Applications/Isolate.app 2>/dev/null || true
exit 0
EOF
chmod +x "$PKG_SCRIPTS/postinstall"

pkgbuild --component "$APP_BUNDLE" \
         --install-location /Applications \
         --scripts "$PKG_SCRIPTS" \
         --identifier com.isolate.Isolate \
         --version "$VERSION" \
         "$FINAL_PKG" --quiet
rm -rf "$PKG_SCRIPTS"

# 10. Compute Checksums
echo "🔒 Computing SHA256 checksums..."
cd "$DIST_DIR"
shasum -a 256 "Isolate-${VERSION}.dmg" "Isolate-${VERSION}.pkg" "Isolate-${VERSION}-macOS.zip" > "$CHECKSUMS"
cd "$PROJECT_DIR"

echo "=========================================================="
echo "✅ RELEASE PACKAGES BUILT SUCCESSFULLY!"
echo "=========================================================="
ls -lh "$DIST_DIR"
cat "$CHECKSUMS"

