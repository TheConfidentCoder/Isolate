# 📦 Isolate Installation Guide

Welcome to **Isolate** — the raw 4-stem audio isolation workstation for macOS Apple Silicon.

Choose the installation method that fits your workflow:

---

## ⚡ Method 1: Instant 1-Line Terminal Install (Recommended)

This is the fastest method. It downloads the latest release, installs `Isolate.app` directly into `/Applications`, and automatically removes the macOS quarantine attribute so it opens with **0 warnings**.

```bash
curl -fsSL https://raw.githubusercontent.com/TheConfidentCoder/Isolate/main/install.sh | bash
```

---

## 🍺 Method 2: Homebrew Cask

Install via Homebrew:

```bash
brew install --cask TheConfidentCoder/isolate/isolate
```

Or tap the repository first:
```bash
brew tap TheConfidentCoder/isolate https://github.com/TheConfidentCoder/Isolate
brew install --cask isolate
```

---

## 💿 Method 3: DMG Installer (Drag & Drop)

1. Download **`Isolate.dmg`** from [GitHub Releases](https://github.com/TheConfidentCoder/Isolate/releases/latest).
2. Double-click the DMG to open the installer window.
3. Drag **`Isolate.app`** into your **`Applications`** folder.
4. Launch `Isolate.app` from `/Applications`.

> [!NOTE]  
> If macOS displays *"Apple could not verify Isolate.app is free of malware"*:
> 
> **Option A (Instant 1-Second Terminal Fix):**
> ```bash
> xattr -cr /Applications/Isolate.app
> ```
> 
> **Option B (macOS System Settings):**
> 1. Click **Done** on the alert.
> 2. Open **System Settings** → **Privacy & Security**.
> 3. Scroll to **Security** and click **Open Anyway** next to *"Isolate.app was blocked"*.
> 4. Enter your password and click **Open**.

---

## 🛠 Method 4: Build from Source

```bash
# Clone
git clone https://github.com/TheConfidentCoder/Isolate.git
cd Isolate

# Generate Xcode project with XcodeGen
xcodegen generate

# Build Release binary
xcodebuild -scheme Isolate -destination 'platform=macOS' build
open build/Release/Isolate.app
```
