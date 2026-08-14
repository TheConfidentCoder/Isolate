cask "isolate" do
  version "1.0.0"
  sha256 "e46c5a1ab3f43c8bf4cc744e569f254ccf691bc8da4192de32dc775e3c298b88"

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
