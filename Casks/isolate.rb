cask "isolate" do
  version "1.0.0"
  sha256 "03fc6f9fb136cd27589c0b2db30be8eb152252c191b3170cd17a95a1f907272e"

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
