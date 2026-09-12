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

## Direct-download release

1. Complete the source checks and app QA, including Keychain, account changes,
   delayed responses during disconnect, logs, notifications, and sleep/wake.
2. Set `VERSION` and explicitly choose the distribution path:
   - **Unsigned preview:** `./scripts/package_release.sh --unsigned` uses an
     ad-hoc signature and needs no Apple Developer membership. Disclose that it
     is unsigned and not notarized in the website and release notes, with a
     link to `docs/INSTALLATION.md`.
   - **Developer ID:** `NOTARY_PROFILE=deploybar-notary ./scripts/package_release.sh`
     requires a Developer ID Application certificate, successful notarization,
     stapling, and Gatekeeper assessment.
3. Verify bundle signature and zip integrity. `SKIP_NOTARIZATION=1` remains a
   local dry run; do not publish it as a signed/notarized release.
4. Test first launch, token save, monitoring, and upgrades on macOS 26+ Apple
   Silicon. For unsigned releases, record Gatekeeper's expected rejection and
   the per-app approval requirement. State explicitly when clean-machine or
   full upgrade testing has not been performed.
5. Publish `DeployBar.zip` and `DeployBar.zip.sha256` in the matching GitHub
   release, then verify README/website downloads and the in-app update check.
6. Copy the generated cask into `Casks/deploybar.rb` in the Homebrew tap,
   verify the checksum, and test installation. Homebrew uses the same artifact
   and signing status; it must not disable Gatekeeper or strip quarantine.

## Website deployment

The Vercel `deploybar` project in `arthurbnhm-gtm` connects to
`arthurbnhm/deploybar`. Set `website` as its root directory and enable source
files outside the root so `design/brand-tokens.json` is available.
Deploy from Git, verify the demo and installation links, then attach
`deploybar.com` to production. `www.deploybar.com` redirects to the apex.
Verify HTTPS, the release download, `/robots.txt`, `/sitemap.xml`, and the
security-reporting link after deployment.

## Licensing and bundled material

DeployBar's original source and project assets are provided under MIT. Third-party
packages retain their own licenses; preserve their notices when redistributing
bundled copies. Apple frameworks and SF Symbols remain subject to Apple's terms.
DeployBar is an independent project and is not affiliated with or endorsed by
Vercel or Apple.
