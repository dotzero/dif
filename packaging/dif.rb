cask "dif" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/dotzero/dif/releases/download/v#{version}/Dif-#{version}.dmg"
  name "dif"
  desc "Dif is a small macOS app for comparing two pieces of text side by side"
  homepage "https://github.com/dotzero/dif"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "Dif.app"
  binary "#{appdir}/Dif.app/Contents/MacOS/Dif", target: "Dif"

  postflight_steps do
    on_macos do
      run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Dif.app"]
    end
  end

  zap trash: [
    "~/Library/Application Scripts/com.dotzero.Dif",
    "~/Library/Preferences/com.dotzero.Dif.plist",
    "~/Library/Containers/com.dotzero.Dif/Data/Library/Preferences/com.dotzero.Dif.plist",
  ]
end
