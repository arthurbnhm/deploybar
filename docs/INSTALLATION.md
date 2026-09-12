# Install DeployBar

DeployBar is a direct-download app for **macOS 26+ on Apple Silicon**. Using it
does not require the Mac App Store, Xcode, or Apple Developer membership.

## Download and first launch

1. Download `DeployBar.zip` from the project's
   [GitHub release](https://github.com/arthurbnhm/deploybar/releases/latest).
2. Unzip it and move `DeployBar.app` to your Applications folder.
3. Open DeployBar once. This preview is **unsigned and not notarized**, so macOS
   may block it because Apple cannot verify the developer.
4. If blocked, open **System Settings → Privacy & Security**, find DeployBar's
   message, and choose **Open Anyway**. Confirm **Open** when prompted.
5. Use the DeployBar menu bar icon to open Settings, connect a Vercel access
   token, and choose your projects. Allow notifications if you want build alerts.

Only approve a copy downloaded from this project. The approval applies to
DeployBar; keep your Mac's other security protections enabled. Managed Macs may
prevent this approval. See Apple's [first-launch guide](https://support.apple.com/en-us/102445).

## Verify the download

Save `DeployBar.zip.sha256` from the same release beside `DeployBar.zip`, then run:

```bash
shasum -a 256 -c DeployBar.zip.sha256
```

The result should be `DeployBar.zip: OK`. This checks file integrity; it does
not provide Developer ID verification or Apple notarization.

## Homebrew

```bash
brew install --cask arthurbnhm/deploybar/deploybar
```

This installs the same unsigned release and verifies its SHA256. Follow the
first-launch steps above if macOS blocks it.

## Updates and Keychain

Quit DeployBar before replacing the app with a newer release. Keep one installed
copy. Settings and cached data live under
`~/Library/Application Support/DeployBar`; the Vercel token stays in Keychain.
Because previews use ad-hoc signatures, macOS may ask you to approve Keychain
access again after an update. If the token is unavailable, reconnect it in
Settings. Disconnect clears local account data but does not revoke the token
at Vercel.

Developers who build frequently can use a stable local development identity as
described in the [README](../README.md#install-locally).
