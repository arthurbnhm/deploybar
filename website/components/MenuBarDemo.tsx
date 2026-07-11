"use client";

import { useEffect, useRef, useState } from "react";
import { MOCK_PROJECTS, type DeploymentStatus, type MockProject } from "@/lib/data";
import { MenuBarMockup } from "./MenuBarMockup";

/** Fired on window to open the demo from anywhere on the page. */
export const OPEN_DEMO_EVENT = "deploybar:open-demo";

/** The docs-site row cycles through a deploy forever, so the demo feels alive. */
const CYCLE: { status: DeploymentStatus; time: string; ms: number }[] = [
  { status: "building", time: "now", ms: 5200 },
  { status: "ready", time: "just now", ms: 6400 },
  { status: "queued", time: "now", ms: 1800 },
];

export function MenuBarDemo() {
  const [open, setOpen] = useState(false);
  const [cycleIndex, setCycleIndex] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const autoOpened = useRef(false);

  // Greet desktop visitors with the popover already open, like a fresh install.
  useEffect(() => {
    if (autoOpened.current) return;
    if (!window.matchMedia("(min-width: 768px)").matches) return;
    const timer = setTimeout(() => {
      autoOpened.current = true;
      setOpen(true);
    }, 1200);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    const onOpen = () => setOpen(true);
    window.addEventListener(OPEN_DEMO_EVENT, onOpen);
    return () => window.removeEventListener(OPEN_DEMO_EVENT, onOpen);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: MouseEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(event.target as Node)
      ) {
        setOpen(false);
      }
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const timer = setTimeout(
      () => setCycleIndex((index) => (index + 1) % CYCLE.length),
      CYCLE[cycleIndex].ms
    );
    return () => clearTimeout(timer);
  }, [open, cycleIndex]);

  const phase = CYCLE[cycleIndex];
  const projects: MockProject[] = MOCK_PROJECTS.map((project) =>
    project.name === "docs-site"
      ? { ...project, status: phase.status, time: phase.time }
      : project
  );

  return (
    <div ref={containerRef} className="relative inline-flex">
      {/* The DeployBar menu bar item — click it, just like on a Mac */}
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        aria-label="Toggle the DeployBar demo popover"
        className={`flex h-9 cursor-pointer items-center rounded-lg px-3 transition-colors ${
          open ? "bg-white/15" : "hover:bg-white/10"
        }`}
      >
        <svg
          className="h-4 w-4 text-white"
          viewBox="0 0 16 16"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M8 2.6c.4 0 .76.22.95.56l4.35 8.18c.18.33.18.78 0 1.1-.17.33-.5.53-.87.53H3.57c-.37 0-.7-.2-.87-.53a1.2 1.2 0 010-1.1L7.05 3.16c.19-.34.55-.56.95-.56z" />
        </svg>
      </button>

      {open && (
        <div className="absolute right-0 top-full z-50 mt-3 w-[min(380px,calc(100vw-2rem))] animate-slide-up">
          {/* Ambient light behind the panel so the glass has something to bend */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute -inset-10"
            style={{
              background:
                "radial-gradient(55% 45% at 22% 18%, rgba(94,92,230,0.22), transparent 70%), radial-gradient(50% 42% at 80% 85%, rgba(233,161,63,0.18), transparent 70%)",
              filter: "blur(28px)",
            }}
          />
          <div className="relative">
            <MenuBarMockup animated projects={projects} />
          </div>
        </div>
      )}
    </div>
  );
}
