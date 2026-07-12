# This is the SOURCE template for the DeployBar Homebrew cask.
# `scripts/package_release.sh` renders it to `packaging/homebrew/deploybar.rb`,
# filling in the release version and the zip's SHA256 from the build it just produced.
# Edit this file, not the rendered deploybar.rb (it gets overwritten every release).
#
# The rendered file must be copied into a real tap repo's `Casks/` directory
# (e.g. arthurbnhm/homebrew-deploybar) to be installable via `brew install --cask`
# and to pass `brew style` cleanly — Homebrew's style cops only relax
# FrozenStringLiteralComment for files that live under a `Casks/` directory.
cask "deploybar" do
  version "0.1.0"
  sha256 "e963cb39c5985236dfb239720689b96fdb1514e12d8e9aa310b1afd8e4d150a6"

  url "https://github.com/arthurbnhm/DeployBar/releases/download/v#{version}/DeployBar.zip",
      verified: "github.com/arthurbnhm/DeployBar/"
  name "DeployBar"
  desc "Menu bar app for monitoring Vercel production deployments"
  homepage "https://github.com/arthurbnhm/DeployBar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "DeployBar.app"

  zap trash: [
    "~/Library/Application Support/DeployBar",
    "~/Library/Preferences/com.deploybar.app.plist",
    "~/Library/Saved Application State/com.deploybar.app.savedState",
  ]
end
