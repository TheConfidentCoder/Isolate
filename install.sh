#!/bin/bash
# ==============================================================================
#  ISOLATE INSTALLER (macOS)
#  Raw 4-Stem Audio Isolation for Apple Silicon
#  1-Line Zero-Quarantine Install Script
# ==============================================================================

set -e

RED='\033[0;31m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

echo ""
echo -e "${RED}  :::  .::::::.  .:::::::  :::            :::  .::::::::::.  .::::::::.${NC}"
echo -e "${RED}  :::  :::       :::   ::: :::          ::: :::     :::      :::       ${NC}"
echo -e "${WHITE}  :::  '::::::.  :::   ::: :::         :::::::::    :::      '::::::.  ${NC}"
echo -e "${WHITE}  :::       :::  :::   ::: :::        :::     :::   :::           :::  ${NC}"
echo -e "${WHITE}  :::  '::::::'  ':::::::  ::::::::: :::       :::  :::      '::::::'  ${NC}"
echo -e "${GRAY}  ───────────────────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}  ISOLATE v1.0.0 • 4-STEM DEMUCS NEURAL ENGINE ACCELERATOR FOR macOS${NC}"
echo -e "${GRAY}  ───────────────────────────────────────────────────────────────────${NC}"
echo ""

# 1. Architecture & Platform Verification
ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" != "Darwin" ]; then
    echo -e "${RED}❌ Error: Isolate is built exclusively for macOS.${NC}"
    exit 1
fi

if [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}⚠️ Note: Isolate is optimized for Apple Silicon (M1/M2/M3/M4) Neural Engines.${NC}"
fi

# 2. Preparation
INSTALL_DIR="/Applications"
APP_TARGET="$INSTALL_DIR/Isolate.app"
TEMP_DIR=$(mktemp -d /tmp/isolate_install.XXXXXX)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${WHITE}⚡ [1/4] Fetching latest release from GitHub...${NC}"
RELEASE_URL="https://github.com/TheConfidentCoder/Isolate/releases/latest/download/Isolate-v1.0.0-macOS.zip"
ZIP_FILE="$TEMP_DIR/Isolate.zip"

curl -fL "$RELEASE_URL" -o "$ZIP_FILE" --progress-bar

echo -e "${WHITE}📦 [2/4] Extracting Isolate.app...${NC}"
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

if [ ! -d "$TEMP_DIR/Isolate.app" ]; then
    echo -e "${RED}❌ Error: Could not extract Isolate.app bundle.${NC}"
    exit 1
fi

echo -e "${WHITE}📂 [3/4] Installing to /Applications...${NC}"
if [ -d "$APP_TARGET" ]; then
    echo -e "${GRAY}   Removing previous version from /Applications...${NC}"
    rm -rf "$APP_TARGET"
fi

cp -R "$TEMP_DIR/Isolate.app" "$INSTALL_DIR/"

echo -e "${WHITE}🔓 [4/4] Removing Gatekeeper quarantine attribute...${NC}"
xattr -cr "$APP_TARGET" 2>/dev/null || true

echo ""
echo -e "${RED}===================================================================${NC}"
echo -e "${WHITE}✅ ISOLATE INSTALLED SUCCESSFULLY!${NC}"
echo -e "${GRAY}   Location: /Applications/Isolate.app${NC}"
echo -e "${RED}===================================================================${NC}"
echo ""

# Prompt to launch immediately if interactive
if [ -t 0 ]; then
    read -p "🚀 Would you like to launch Isolate now? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${WHITE}Launching Isolate...${NC}"
        open "$APP_TARGET"
    fi
else
    echo -e "${WHITE}Run 'open /Applications/Isolate.app' to launch.${NC}"
fi
