# Publishing DeployBar

Publishing source and distributing a signed app are separate steps. This
checklist does not publish the repository, upload an artifact, or enable a tap.

## Source publication

- Include `LICENSE` (MIT), `SECURITY.md`, `CONTRIBUTING.md`, the full source,
  tests, `design/brand-tokens.json`, and `website/package-lock.json` in the same
  reviewed commit. Both the website and the brand tests use the design file.
- Review the complete Git history for credentials and private data before
  changing repository visibility. Use a maintained secret scanner as well as
  manual review; rotate any credential found, even if removed from the latest tree.
- From a fresh clone of that exact commit, run `swift build`, `swift test
  --parallel`, `./scripts/lint.sh`, then `npm ci`, `npm audit
  --audit-level=moderate`, `npm run typecheck`, and `npm run build` in `website/`.
  Swift tests require full Xcode 26+; Command Line Tools alone do not supply XCTest.
- Verify that CI succeeds for the exact commit being published, not an older run.
- When the repository is made public, enable **Private vulnerability reporting**
  under Settings → Advanced Security. Verify that Security → Advisories exposes
  **Report a vulnerability**, and that the link in `SECURITY.md` reaches the
  private form. Do not announce the repository before this intake works.
- Ensure maintainers receive GitHub security notifications and remove the
  pre-publication note in `SECURITY.md` once the intake has been verified.

GitHub documents this feature for public repositories:
[Configure private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository).

## Binary release

1. Complete the source checks and app QA, including Keychain, account changes,
   delayed responses during disconnect, logs, notifications, and sleep/wake.
2. Set `VERSION`, then run `NOTARY_PROFILE=deploybar-notary
   ./scripts/package_release.sh` with a Developer ID Application certificate.
3. Require successful notarization, stapling, and Gatekeeper assessment. Never
   publish an artifact made with `SKIP_NOTARIZATION=1` or ad-hoc signing.
4. Install the produced zip on a clean macOS 26+ Apple Silicon environment and
   verify first launch, token save, monitoring, and upgrading an existing install.
5. Publish the verified `DeployBar.zip` and checksum in the matching GitHub
   release, then verify the README, website download link, and in-app update check.
6. If distributing with Homebrew, publish the generated cask in a real tap,
   verify its checksum matches the release asset, and test an installation.

No signed release or Homebrew tap is implied by the presence of packaging scripts.

## Licensing and bundled material

DeployBar's original source and project assets are provided under MIT. Third-party
packages retain their own licenses; preserve their notices when redistributing
bundled copies. Apple frameworks and SF Symbols remain subject to Apple's terms.
DeployBar is an independent project and is not affiliated with or endorsed by
Vercel or Apple.
