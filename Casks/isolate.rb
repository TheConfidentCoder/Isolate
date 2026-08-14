cask "isolate" do
  version "1.0.0"
  sha256 "47ed5354cdc17af6e64fb1c2ce57b1b8d07844841be64de108e5f106fc25f2e2"

  url "https://github.com/TheConfidentCoder/Isolate/releases/download/v#{version}/Isolate-v#{version}.dmg"
  name "Isolate"
  desc "Raw 4-stem audio isolation powered by Demucs v4 Neural Engine CoreML"
  homepage "https://github.com/TheConfidentCoder/Isolate"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Isolate.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Isolate.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Isolate",
    "~/Library/Preferences/com.isolate.Isolate.plist",
    "~/Library/Caches/com.isolate.Isolate",
  ]
end
