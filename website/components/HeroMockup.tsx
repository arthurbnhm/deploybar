"use client";

import { useEffect, useState } from "react";
import { MOCK_PROJECTS, type DeploymentStatus, type MockProject } from "@/lib/data";
import { MenuBarMockup } from "./MenuBarMockup";

/** The docs-site row cycles through a deploy forever, so the mockup feels alive. */
const CYCLE: { status: DeploymentStatus; time: string; ms: number }[] = [
  { status: "building", time: "now", ms: 5200 },
  { status: "ready", time: "just now", ms: 6400 },
  { status: "queued", time: "now", ms: 1800 },
];

function MenuBarStrip() {
  return (
    <div
      className="flex h-9 items-center justify-end gap-1 rounded-xl px-2 backdrop-blur-2xl"
      style={{
        backgroundColor: "rgba(22,22,26,0.6)",
        boxShadow:
          "0 0 0 1px rgba(255,255,255,0.08), inset 0 1px 0 rgba(255,255,255,0.07), 0 12px 30px rgba(0,0,0,0.35)",
      }}
    >
      {/* DeployBar item — active, popover open below */}
      <span className="flex h-7 items-center rounded-md bg-white/15 px-2.5">
        <svg className="h-3.5 w-3.5 text-white" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
          <path d="M8 2.6c.4 0 .76.22.95.56l4.35 8.18c.18.33.18.78 0 1.1-.17.33-.5.53-.87.53H3.57c-.37 0-.7-.2-.87-.53a1.2 1.2 0 010-1.1L7.05 3.16c.19-.34.55-.56.95-.56z" />
        </svg>
      </span>
      {/* Wi-Fi */}
      <span className="flex h-7 items-center rounded-md px-2 text-white/85">
        <svg className="h-3.5 w-3.5" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
          <path d="M8 12.6a1.15 1.15 0 110 2.3 1.15 1.15 0 010-2.3zM8 9.2c1.3 0 2.48.5 3.36 1.33l-1.06 1.13A3.35 3.35 0 008 10.75c-.88 0-1.69.34-2.3.91l-1.06-1.13A4.85 4.85 0 018 9.2zm0-3.4c2.2 0 4.2.86 5.68 2.26l-1.05 1.12A6.7 6.7 0 008 7.35a6.7 6.7 0 00-4.63 1.83L2.32 8.06A8.2 8.2 0 018 5.8z" />
        </svg>
      </span>
      {/* Battery */}
      <span className="flex h-7 items-center rounded-md px-2 text-white/85">
        <svg className="h-3.5 w-6" viewBox="0 0 28 14" fill="none" aria-hidden="true">
          <rect x="1" y="1.5" width="22" height="11" rx="3.5" stroke="currentColor" strokeOpacity="0.4" />
          <path d="M25 5v4c1.1-.2 2-1 2-2s-.9-1.8-2-2z" fill="currentColor" fillOpacity="0.4" />
          <rect x="3" y="3.5" width="15" height="7" rx="2" fill="currentColor" />
        </svg>
      </span>
      {/* Clock */}
      <span className="flex h-7 items-center rounded-md px-2 text-[12px] font-medium text-white/85">
        Fri Jul 11&ensp;9:41
      </span>
    </div>
  );
}

export function HeroMockup() {
  const [cycleIndex, setCycleIndex] = useState(0);

  useEffect(() => {
    const timer = setTimeout(
      () => setCycleIndex((index) => (index + 1) % CYCLE.length),
      CYCLE[cycleIndex].ms
    );
    return () => clearTimeout(timer);
  }, [cycleIndex]);

  const phase = CYCLE[cycleIndex];
  const projects: MockProject[] = MOCK_PROJECTS.map((project) =>
    project.name === "docs-site"
      ? { ...project, status: phase.status, time: phase.time }
      : project
  );

  return (
    <div className="w-[420px] max-w-full">
      <MenuBarStrip />
      {/* The popover clamps to the screen edge, just like macOS */}
      <div className="mt-1.5 flex justify-end pr-1">
        <MenuBarMockup animated projects={projects} />
      </div>
    </div>
  );
}
