cask "lbpssh" do
  version "v1.9.3"
  sha256 "5e03e9c0c4569d108976b671f9a3425b92f521fcf545d8e0aeac6fea4fb068f5"

  url "https://github.com/lbp0200/lbpssh/releases/download/#{version}/lbpSSH-macos-universal.zip"
  name "lbpSSH"
  desc "Cross-platform SSH terminal manager"
  homepage "https://github.com/lbp0200/lbpssh"

  app "lbpSSH.app"

  zap trash: [
    "~/Library/Application Support/lbpSSH",
    "~/Library/Preferences/com.lbpssh.app.plist",
  ]
end
