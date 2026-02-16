import { DeployBarButton } from "@/components/DeployBarButton";
import { LogoWordmark } from "@/components/Logo";
import {
  FEATURES,
  GITHUB_REPO_URL,
  MAC_DOWNLOAD_URL,
  STATUS_COLORS,
  STATUS_LABELS,
} from "@/lib/data";
import type { DeploymentStatus } from "@/lib/data";

const HERO_STATUSES: { status: DeploymentStatus; delay: string }[] = [
  { status: "ready", delay: "0s" },
  { status: "building", delay: "0.15s" },
  { status: "failed", delay: "0.3s" },
  { status: "queued", delay: "0.45s" },
];

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#F5F0EB] text-[#1A1A1A]">
      <nav className="flex items-center justify-between px-6 md:px-12 py-5 max-w-7xl mx-auto w-full">
        <div className="flex items-center gap-3">
          <LogoWordmark textClass="text-xl font-semibold text-[#1A1A1A]" />
        </div>
        <div className="flex items-center gap-3">
          <DeployBarButton />
          <a
            href={MAC_DOWNLOAD_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-[#EDE6DF] text-[#1A1A1A] text-sm font-medium hover:bg-[#E5DDD4] transition-colors"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            Download for Mac
          </a>
        </div>
      </nav>

      <section className="max-w-5xl mx-auto text-center pt-24 md:pt-32 pb-16 px-6">
        <h1 className="text-6xl md:text-7xl lg:text-8xl font-extrabold leading-[1.05] tracking-tight">
          Never miss a <span className="text-[#E8927C]">broken</span> deploy.
        </h1>

        <p className="mt-6 text-lg md:text-xl text-[#1A1A1A]/60 max-w-2xl mx-auto leading-relaxed">
          Real-time Vercel deployment monitoring, right in your macOS menu bar.
          Know instantly when things break.
        </p>

        <div className="mt-10 flex items-center gap-3 flex-wrap justify-center">
          {HERO_STATUSES.map(({ status, delay }) => (
            <span
              key={status}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium animate-slide-up"
              style={{
                backgroundColor: `${STATUS_COLORS[status]}18`,
                color: STATUS_COLORS[status],
                border: `1px solid ${STATUS_COLORS[status]}30`,
                animationDelay: delay,
                animationFillMode: "backwards",
              }}
            >
              <span
                className="w-2 h-2 rounded-full animate-pulse-dot"
                style={{ backgroundColor: STATUS_COLORS[status] }}
              />
              {STATUS_LABELS[status]}
            </span>
          ))}
        </div>

        <div className="mt-10 flex items-center justify-center gap-4 flex-wrap">
          <a
            href={MAC_DOWNLOAD_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-lg bg-[#1A1A1A] text-white text-sm font-medium hover:bg-[#2A2A2A] transition-colors"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            Download for Mac
          </a>
          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-lg bg-[#EDE6DF] text-[#1A1A1A] text-sm font-medium hover:bg-[#E5DDD4] transition-colors"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
            </svg>
            View on GitHub
          </a>
        </div>
      </section>

      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-extrabold text-center mb-20 tracking-tight">
            Everything you need
          </h2>

          <div className="space-y-8">
            {Array.from({ length: Math.ceil(FEATURES.length / 2) }).map((_, rowIndex) => {
              const leftFeature = FEATURES[rowIndex * 2];
              const rightFeature = FEATURES[rowIndex * 2 + 1];
              return (
                <div
                  key={rowIndex}
                  className="grid grid-cols-1 md:grid-cols-2 gap-8"
                >
                  <div className="bg-[#EDE6DF] rounded-2xl p-8 md:p-10 flex gap-6 items-start">
                    <span className="text-5xl font-black text-[#E8927C]/30 leading-none shrink-0 select-none">
                      {String(rowIndex * 2 + 1).padStart(2, "0")}
                    </span>
                    <div>
                      <h3 className="text-2xl font-bold tracking-tight mb-2">
                        {leftFeature.title}
                      </h3>
                      <p className="text-[#1A1A1A]/55 leading-relaxed">
                        {leftFeature.description}
                      </p>
                    </div>
                  </div>

                  {rightFeature && (
                    <div className="bg-[#EDE6DF] rounded-2xl p-8 md:p-10 flex gap-6 items-start">
                      <span className="text-5xl font-black text-[#E8927C]/30 leading-none shrink-0 select-none">
                        {String(rowIndex * 2 + 2).padStart(2, "0")}
                      </span>
                      <div>
                        <h3 className="text-2xl font-bold tracking-tight mb-2">
                          {rightFeature.title}
                        </h3>
                        <p className="text-[#1A1A1A]/55 leading-relaxed">
                          {rightFeature.description}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </section>

      <footer className="py-16 text-center overflow-hidden">
        <div
          className="text-[120px] font-black leading-none text-[#1A1A1A] opacity-[0.06] select-none"
          aria-hidden="true"
        >
          DEPLOYBAR
        </div>
        <p className="mt-4 text-sm text-[#1A1A1A]/40">
          Free and open source &middot; macOS 15+
        </p>
      </footer>
    </div>
  );
}
