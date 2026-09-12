import { HeroDemoButton } from "@/components/HeroDemoButton";
import { LogoIcon } from "@/components/Logo";
import { MenuBarDemo } from "@/components/MenuBarDemo";
import { AuroraBackdrop, EmberOrb } from "@/components/Shaders";
import { FEATURES, GITHUB_REPO_URL, MAC_DOWNLOAD_URL, RELEASE_URL } from "@/lib/data";

function AppleIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function GitHubIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
  );
}

function DownloadButton({ prominent = false }: { prominent?: boolean }) {
  return (
    <div className="inline-flex flex-col items-center gap-3">
      <a
        href={MAC_DOWNLOAD_URL}
        className={`inline-flex items-center gap-2.5 rounded-full bg-ink font-semibold text-night transition-colors hover:bg-white ${
          prominent ? "px-8 py-4 text-[15px]" : "px-6 py-3 text-sm"
        }`}
      >
        <AppleIcon />
        Download for Mac
      </a>
      <a href="#install" className="text-xs text-white/55 underline-offset-4 hover:text-white hover:underline">
        Unsigned preview · First-launch instructions
      </a>
    </div>
  );
}

export default function HomePage() {
  return (
    <div className="min-h-screen overflow-x-clip bg-night text-ink">
      {/* ——— Hero ——— */}
      <section className="relative">
        <AuroraBackdrop />

        <header className="relative z-30">
          <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-6">
            <div className="flex items-center gap-2.5">
              <LogoIcon className="h-7 w-7" />
              <span className="text-[17px] font-semibold tracking-tight">DeployBar</span>
            </div>
            <nav className="flex items-center gap-2">
              <a
                href={GITHUB_REPO_URL}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 rounded-full px-3.5 py-2 text-sm font-medium text-white/60 transition-colors hover:text-white"
              >
                <GitHubIcon />
                <span className="hidden sm:inline">GitHub</span>
              </a>
              <a
                href="#install"
                className="inline-flex items-center rounded-full border border-white/15 px-4 py-2 text-sm font-medium text-white/85 transition-colors hover:border-white/35 hover:text-white"
              >
                Install
              </a>
              <MenuBarDemo />
            </nav>
          </div>
        </header>

        <div className="relative z-10 mx-auto max-w-5xl px-6 pb-64 pt-16 text-center md:pb-80 md:pt-24">
          <p
            className="animate-rise font-mono text-[11px] uppercase tracking-[0.32em] text-white/40"
            style={{ animationDelay: "0.05s" }}
          >
            For Vercel · Lives in the macOS menu bar
          </p>

          <h1
            className="animate-rise mt-8 text-[clamp(3.25rem,9vw,7.25rem)] font-medium leading-[0.98] tracking-[-0.035em]"
            style={{ animationDelay: "0.15s" }}
          >
            Never miss a
            <br />
            <em
              className="font-serif text-[1.08em] font-normal"
              style={{
                background: "linear-gradient(100deg, #ff6f61 0%, #e9a13f 90%)",
                WebkitBackgroundClip: "text",
                backgroundClip: "text",
                color: "transparent",
              }}
            >
              broken deploy.
            </em>
          </h1>

          <p
            className="animate-rise mx-auto mt-8 max-w-xl text-balance text-base leading-relaxed text-white/55 md:text-lg"
            style={{ animationDelay: "0.28s" }}
          >
            DeployBar watches your Vercel production deployments from the menu
            bar — and taps you on the shoulder the moment one goes sideways.
            Native, tiny, open source.
          </p>

          <div
            className="animate-rise mt-10 flex flex-wrap items-start justify-center gap-4"
            style={{ animationDelay: "0.4s" }}
          >
            <DownloadButton />
            <HeroDemoButton />
          </div>

          <p
            className="animate-rise mt-6 font-mono text-[11px] uppercase tracking-[0.28em] text-white/30"
            style={{ animationDelay: "0.5s" }}
          >
            Free · MIT licensed · macOS 26+ · Apple Silicon
          </p>
        </div>
      </section>

      {/* ——— Features ——— */}
      <section className="mx-auto max-w-6xl px-6 py-28 md:py-36">
        <div className="border-b border-white/10 pb-8">
          <h2 className="text-4xl tracking-[-0.02em] md:text-5xl">
            Small app,{" "}
            <em className="font-serif font-normal text-white/90">sharp instincts.</em>
          </h2>
        </div>

        <div className="grid grid-cols-1 gap-x-12 md:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((feature, index) => (
            <div
              key={feature.title}
              className="group border-b border-white/[0.06] pb-12 pt-10"
            >
              <span className="font-mono text-xs text-white/25 transition-colors group-hover:text-ember">
                {String(index + 1).padStart(2, "0")}
              </span>
              <h3 className="mt-5 text-lg font-medium tracking-tight">
                {feature.title}
              </h3>
              <p className="mt-2.5 text-[15px] leading-relaxed text-white/50">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </section>

      <section id="install" className="mx-auto max-w-6xl scroll-mt-10 px-6 py-20">
        <div className="grid gap-10 border-y border-white/10 py-12 md:grid-cols-2 md:gap-16">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.22em] text-ember">Install DeployBar</p>
            <h2 className="mt-5 text-4xl tracking-tight">A small app.<br />One extra first step.</h2>
            <p className="mt-5 max-w-md text-[15px] leading-relaxed text-white/60">
              This preview is distributed directly and is not signed with an Apple Developer ID
              or notarized by Apple. macOS will ask you to approve it before its first launch.
            </p>
            <p className="mt-4 text-sm text-white/50">Requires macOS 26 or later and an Apple Silicon Mac.</p>
          </div>
          <div>
            <ol className="list-decimal space-y-4 pl-5 text-[15px] leading-relaxed text-white/75">
              <li>Download the zip, unzip it, and move DeployBar to Applications.</li>
              <li>Open DeployBar once. If macOS blocks it, dismiss the alert.</li>
              <li>In System Settings → Privacy &amp; Security, choose Open Anyway for DeployBar, then confirm Open.</li>
              <li>Connect your Vercel token and choose the projects you want to watch.</li>
            </ol>
            <p className="mt-5 text-sm leading-relaxed text-white/50">
              Only approve a copy you downloaded from this site or our GitHub releases.
              Your Mac’s other security protections stay enabled.
            </p>
            <div className="mt-6 flex flex-wrap gap-x-6 gap-y-3 text-sm">
              <a href={RELEASE_URL} className="text-ember underline-offset-4 hover:underline">Release notes &amp; checksum</a>
              <a href={`${GITHUB_REPO_URL}#build`} className="text-white/70 underline-offset-4 hover:underline">Build from source</a>
              <a href="https://support.apple.com/en-us/102445" className="text-white/70 underline-offset-4 hover:underline">Apple’s first-launch guide</a>
            </div>
          </div>
        </div>
      </section>

      {/* ——— Closing CTA ——— */}
      <section className="relative py-40 md:py-56">
        <EmberOrb />
        <div className="relative z-10 mx-auto max-w-3xl px-6 text-center">
          <h2 className="font-serif text-[clamp(2.75rem,7vw,5.25rem)] leading-[1.02] tracking-[-0.01em]">
            Deploy, <em>then breathe.</em>
          </h2>
          <p className="mx-auto mt-6 max-w-md text-balance text-base leading-relaxed text-white/55">
            One glance at the menu bar and you know. Green means go home.
          </p>
          <div className="mt-10">
            <DownloadButton prominent />
          </div>
        </div>
      </section>

      {/* ——— Footer ——— */}
      <footer className="relative border-t border-white/[0.06]">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-6 px-6 py-10">
          <div className="flex items-center gap-2.5">
            <LogoIcon className="h-6 w-6" />
            <span className="font-mono text-[11px] uppercase tracking-[0.22em] text-white/35">
              DeployBar · 2026
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-x-6 gap-y-4 font-mono text-[11px] uppercase tracking-[0.22em]">
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noreferrer"
              className="text-white/40 transition-colors hover:text-white"
            >
              GitHub
            </a>
            <a
              href={RELEASE_URL}
              target="_blank"
              rel="noreferrer"
              className="text-white/40 transition-colors hover:text-white"
            >
              Latest release
            </a>
            <a
              href={`${GITHUB_REPO_URL}/security/policy`}
              className="text-white/40 transition-colors hover:text-white"
            >
              Security
            </a>
            <a
              href={`${GITHUB_REPO_URL}/issues`}
              target="_blank"
              rel="noreferrer"
              className="text-white/40 transition-colors hover:text-white"
            >
              Issues
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
