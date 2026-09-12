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
  sha256 "f3bd74561da423322b55803572dee3195f54bcb108729ae91a30ba62d3a22f5f"

  url "https://github.com/arthurbnhm/deploybar/releases/download/v#{version}/DeployBar.zip"
  name "DeployBar"
  desc "Menu bar app for monitoring Vercel production deployments"
  homepage "https://deploybar.com"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe
  depends_on arch: :arm64

  app "DeployBar.app"

  caveats <<~EOS
    For release signing status and first-launch instructions, see:
      https://deploybar.com/#install
  EOS

  zap trash: [
    "~/Library/Application Support/DeployBar",
    "~/Library/Preferences/com.deploybar.app.plist",
    "~/Library/Saved Application State/com.deploybar.app.savedState",
  ]
end
