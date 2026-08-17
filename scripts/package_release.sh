#!/bin/bash
set -e

VERSION="${1:-v1.2.5}"
echo "=========================================================="
echo "⚡ PACKAGING ISOLATE RELEASE: ${VERSION}"
echo "=========================================================="

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/build/Release"
STAGING_DIR="$PROJECT_DIR/build/dmg_staging"
TMP_DMG="$DIST_DIR/tmp.dmg"
FINAL_DMG="$DIST_DIR/Isolate.dmg"
VERSIONED_DMG="$DIST_DIR/Isolate-${VERSION}.dmg"
FINAL_ZIP="$DIST_DIR/Isolate-${VERSION}-macOS.zip"
CHECKSUMS="$DIST_DIR/SHA256SUMS.txt"

# 1. Clean previous build artifacts
hdiutil detach "/Volumes/Isolate" -force 2>/dev/null || true
rm -rf "$DIST_DIR" "$PROJECT_DIR/build"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

# 2. Generate assets (DMG background & Icons)
echo "🎨 Step 1/7: Generating DMG assets & icons..."
swift scripts/generate_assets.swift

# 3. Generate Xcode Project & Build Release App
echo "🔨 Step 2/7: Building Isolate.app (Release configuration)..."
xcodegen generate
xcodebuild -scheme Isolate \
  -configuration Release \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build

APP_BUNDLE="$BUILD_DIR/Isolate.app"

# 4. Embed CoreML Model & AppIcon into App Bundle Resources
echo "🧠 Step 3/7: Embedding Demucs Neural Engine CoreML model & AppIcon..."
MODEL_SOURCE="$HOME/Library/Application Support/Isolate/HTDemucs.mlmodelc"
if [ ! -d "$MODEL_SOURCE" ]; then
    MODEL_SOURCE="/Users/neokumar/Library/Application Support/Isolate/HTDemucs.mlmodelc"
fi
if [ -d "$MODEL_SOURCE" ]; then
    cp -R "$MODEL_SOURCE" "$APP_BUNDLE/Contents/Resources/HTDemucs.mlmodelc"
    echo "   Embedded HTDemucs.mlmodelc into app bundle."
fi
if [ -f "$PROJECT_DIR/Assets/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "   Embedded AppIcon.icns into app bundle resources."
fi

# 5. Ad-Hoc Code Sign the App Bundle
echo "🔐 Step 4/7: Applying ad-hoc codesign to app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 6. Prepare Staging Folder for DMG
echo "📦 Step 5/7: Preparing DMG staging directory..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/Isolate.app"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$STAGING_DIR/.background"
cp "$PROJECT_DIR/Assets/dmg_background.png" "$STAGING_DIR/.background/dmg_background.png"
if [ -f "$PROJECT_DIR/Assets/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Assets/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
fi
if [ -f "$PROJECT_DIR/Assets/dmg_ds_store" ]; then
    cp "$PROJECT_DIR/Assets/dmg_ds_store" "$STAGING_DIR/.DS_Store"
fi

SetFile -a C "$STAGING_DIR" 2>/dev/null || true
SetFile -a V "$STAGING_DIR/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a V "$STAGING_DIR/.background" 2>/dev/null || true

# 7. Create Read-Write DMG & Layout Finder Window
echo "💿 Step 6/7: Creating and styling DMG installer window..."
rm -f "$TMP_DMG" "$FINAL_DMG" "$VERSIONED_DMG"
hdiutil create -srcfolder "$STAGING_DIR" -volname "Isolate" -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" -format UDRW -size 680m "$TMP_DMG" -quiet

# Mount temporary DMG
MOUNT_INFO=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG")
DEV_NODE=$(echo "$MOUNT_INFO" | grep Apple_HFS | awk '{print $1}')
MOUNT_DIR=$(mount | grep "$DEV_NODE" | sed 's/.*on \(.*\) (.*/\1/')
if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/Isolate"
fi
echo "   Mounted temporary DMG at $MOUNT_DIR ($DEV_NODE)"

# Ensure volume icon and invisibility attributes
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true

# Configure Finder window layout using AppleScript
osascript <<EOF || true
tell application "Finder"
    tell disk "Isolate"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to true
        set the bounds of container window to {400, 150, 1060, 550}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 140
        set background picture of theViewOptions to file ".background:dmg_background.png"
        
        try
            set position of item "Isolate.app" of container window to {170, 160}
        end try
        try
            set position of item "Applications" of container window to {490, 160}
        end try
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Sync & save .DS_Store to Assets for CI reproducibility
sync
sleep 1
if [ -f "$MOUNT_DIR/.DS_Store" ]; then
    cp "$MOUNT_DIR/.DS_Store" "$PROJECT_DIR/Assets/dmg_ds_store"
fi

# Detach
hdiutil detach "$DEV_NODE" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet

# Convert to compressed read-only UDZO DMG
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet
cp "$FINAL_DMG" "$VERSIONED_DMG"
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

# 8. Create Standalone ZIP
echo "🗜 Step 7/7: Creating standalone ZIP archive..."
cd "$BUILD_DIR"
zip -r -y -q "$FINAL_ZIP" "Isolate.app"
cd "$PROJECT_DIR"

# 9. Compute Checksums
echo "🔒 Computing SHA256 checksums..."
cd "$DIST_DIR"
shasum -a 256 "Isolate.dmg" "Isolate-${VERSION}.dmg" "Isolate-${VERSION}-macOS.zip" > "$CHECKSUMS"
cd "$PROJECT_DIR"

echo "=========================================================="
echo "✅ RELEASE PACKAGES BUILT SUCCESSFULLY!"
echo "=========================================================="
ls -lh "$DIST_DIR"
cat "$CHECKSUMS"
