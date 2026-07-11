"use client";

import { useState } from "react";
import {
  MOCK_PROJECTS,
  STATUS_COLORS,
  STATUS_LABELS,
  type DeploymentStatus,
  type MockProject,
} from "@/lib/data";
import { StatusDot } from "./StatusDot";

function StatusPill({ status }: { status: DeploymentStatus }) {
  const color = STATUS_COLORS[status];
  const label = STATUS_LABELS[status];

  const icons: Record<DeploymentStatus, React.ReactNode> = {
    ready: (
      <svg className="w-2.5 h-2.5" viewBox="0 0 16 16" fill={color}>
        <path d="M8 0a8 8 0 110 16A8 8 0 018 0zm3.41 5.29L7 9.71 4.59 7.29a1 1 0 00-1.42 1.42l3 3a1 1 0 001.42 0l5-5a1 1 0 00-1.42-1.42z" />
      </svg>
    ),
    building: (
      <svg className="w-2.5 h-2.5 animate-spin" viewBox="0 0 16 16" fill={color}>
        <path d="M8 1a7 7 0 100 14A7 7 0 008 1zm0 2a5 5 0 110 10A5 5 0 018 3z" opacity="0.3" />
        <path d="M8 1a7 7 0 017 7h-2a5 5 0 00-5-5V1z" />
      </svg>
    ),
    failed: (
      <svg className="w-2.5 h-2.5" viewBox="0 0 16 16" fill={color}>
        <path d="M8 0a8 8 0 110 16A8 8 0 018 0zM5.35 5.35a.5.5 0 00-.002.71L7.3 8l-1.95 1.94a.5.5 0 10.7.71L8 8.71l1.95 1.94a.5.5 0 00.71-.71L8.71 8l1.95-1.94a.5.5 0 00-.71-.71L8 7.29 6.05 5.35a.5.5 0 00-.7 0z" />
      </svg>
    ),
    queued: (
      <svg className="w-2.5 h-2.5" viewBox="0 0 16 16" fill={color}>
        <path d="M8 0a8 8 0 110 16A8 8 0 018 0zm-.5 4a.5.5 0 00-.5.5v4a.5.5 0 00.5.5h3a.5.5 0 000-1H8V4.5a.5.5 0 00-.5-.5z" />
      </svg>
    ),
    canceled: (
      <svg className="w-2.5 h-2.5" viewBox="0 0 16 16" fill={color}>
        <circle cx="8" cy="8" r="8" opacity="0.5" />
        <rect x="4" y="7.25" width="8" height="1.5" rx="0.75" />
      </svg>
    ),
  };

  return (
    <span
      className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-medium"
      style={{
        backgroundColor: `${color}22`,
        color: color,
      }}
    >
      {icons[status]}
      {label}
    </span>
  );
}

function ProjectRow({
  name,
  commit,
  status,
  time,
  animated,
  onSelect,
}: {
  name: string;
  commit: string;
  status: DeploymentStatus;
  time: string;
  animated: boolean;
  onSelect?: () => void;
}) {
  const selectable = status === "ready" || status === "failed";

  return (
    <button
      type="button"
      onClick={selectable ? onSelect : undefined}
      className={`w-full text-left flex items-center gap-2.5 px-2.5 py-2 rounded-lg transition-colors ${
        selectable ? "hover:bg-white/[0.08] cursor-pointer" : "cursor-default"
      }`}
    >
      <StatusDot status={status} animated={animated} />
      <div className="flex-1 min-w-0">
        <div className="text-[13px] font-medium text-white truncate">{name}</div>
        <div className="text-[11px] text-white/45 truncate mt-0.5">{commit}</div>
      </div>
      <div className="flex flex-col items-end gap-1 shrink-0">
        <StatusPill status={status} />
        <span className="text-[10px] text-white/35">{time}</span>
      </div>
      {/* Fixed slot so pills stay trailing-aligned across rows, like the app */}
      <svg
        className={`w-2.5 h-2.5 shrink-0 ${selectable ? "text-white/30" : "opacity-0"}`}
        viewBox="0 0 16 16"
        fill="currentColor"
      >
        <path d="M6.22 3.22a.75.75 0 011.06 0l4.25 4.25a.75.75 0 010 1.06l-4.25 4.25a.75.75 0 01-1.06-1.06L9.94 8 6.22 4.28a.75.75 0 010-1.06z" />
      </svg>
    </button>
  );
}

function ActionsTray({ name, onClose }: { name: string; onClose: () => void }) {
  return (
    <div
      className="rounded-[10px] bg-white/[0.06] p-2.5 animate-slide-up"
      style={{ animationDuration: "0.2s" }}
    >
      <button
        type="button"
        onClick={onClose}
        className="w-full flex items-center justify-between gap-2 cursor-pointer"
      >
        <span className="text-[13px] font-semibold text-white truncate">{name}</span>
        <span className="w-[18px] h-[18px] rounded-full bg-white/10 flex items-center justify-center shrink-0">
          <svg className="w-2 h-2 text-white/60" viewBox="0 0 16 16" fill="currentColor">
            <path d="M3.72 3.72a.75.75 0 011.06 0L8 6.94l3.22-3.22a.75.75 0 111.06 1.06L9.06 8l3.22 3.22a.75.75 0 11-1.06 1.06L8 9.06l-3.22 3.22a.75.75 0 01-1.06-1.06L6.94 8 3.72 4.78a.75.75 0 010-1.06z" />
          </svg>
        </span>
      </button>
      <div className="mt-2.5 flex gap-2">
        <span className="flex-1 h-7 rounded-full bg-[#0A84FF]/85 text-white text-[11px] font-semibold flex items-center justify-center gap-1.5">
          Logs
        </span>
        <span className="flex-1 h-7 rounded-full bg-white/10 text-white/85 text-[11px] font-semibold flex items-center justify-center gap-1.5">
          Online
        </span>
        <span className="flex-1 h-7 rounded-full bg-white/10 text-white/85 text-[11px] font-semibold flex items-center justify-center gap-1.5">
          Dashboard
        </span>
      </div>
    </div>
  );
}

function FooterButton({ label, icon }: { label: string; icon: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md text-[12px] text-white/60 hover:text-white/90 hover:bg-white/[0.08] transition-colors cursor-default">
      {icon}
      {label}
    </span>
  );
}

export function MenuBarMockup({
  animated = true,
  className = "",
  projects = MOCK_PROJECTS,
}: {
  animated?: boolean;
  className?: string;
  projects?: MockProject[];
}) {
  const [expandedProject, setExpandedProject] = useState<string | null>(null);

  const anyDeploying = projects.some(
    (project) => project.status === "building" || project.status === "queued"
  );

  return (
    <div
      className={`relative w-[380px] max-w-full rounded-[22px] overflow-hidden ${className}`}
      style={{
        background:
          "linear-gradient(180deg, rgba(46,46,54,0.52) 0%, rgba(26,26,31,0.6) 100%)",
        backdropFilter: "blur(36px) saturate(180%)",
        WebkitBackdropFilter: "blur(36px) saturate(180%)",
        boxShadow: [
          "0 0 0 1px rgba(255,255,255,0.08)", // hairline
          "inset 0 1px 0 rgba(255,255,255,0.16)", // specular top rim
          "inset 0 -1px 0 rgba(255,255,255,0.05)", // bottom rim
          "inset 1px 0 0 rgba(255,255,255,0.04)", // side rims
          "inset -1px 0 0 rgba(255,255,255,0.04)",
          "0 24px 60px rgba(0,0,0,0.55)",
          "0 6px 18px rgba(0,0,0,0.35)",
        ].join(", "),
      }}
    >
      {/* Specular sheen falling from the top edge, like light on glass */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 rounded-[22px]"
        style={{
          background:
            "linear-gradient(180deg, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0.02) 32%, transparent 55%)",
        }}
      />
      {/* Header */}
      <div className="px-4 pt-3.5 pb-2 flex items-center justify-between">
        <div>
          <div className="text-[13px] font-semibold text-white">DeployBar</div>
          <div className="text-[11px] text-white/50 mt-0.5">@developer · just now</div>
        </div>
        {anyDeploying ? (
          <div className="flex items-center gap-1.5">
            <span className="text-[11px] font-medium text-white/50">Deploying</span>
            <svg
              className="w-4 h-4 animate-spin"
              style={{ color: STATUS_COLORS.building, animationDuration: "2.5s" }}
              viewBox="0 0 16 16"
              fill="currentColor"
            >
              <path d="M8 1a7 7 0 100 14A7 7 0 008 1zm0 2a5 5 0 110 10A5 5 0 018 3z" opacity="0.3" />
              <path d="M8 1a7 7 0 017 7h-2a5 5 0 00-5-5V1z" />
            </svg>
          </div>
        ) : (
          <div className="flex items-center gap-1.5">
            <span className="text-[11px] font-medium text-white/50">Live</span>
            <span
              className="w-2 h-2 rounded-full"
              style={{ backgroundColor: STATUS_COLORS.ready }}
            />
          </div>
        )}
      </div>

      {/* Project List */}
      <div className="px-2 py-1.5 space-y-1">
        {projects.map((project) =>
          expandedProject === project.name ? (
            <ActionsTray
              key={project.name}
              name={project.name}
              onClose={() => setExpandedProject(null)}
            />
          ) : (
            <ProjectRow
              key={project.name}
              {...project}
              animated={animated}
              onSelect={() =>
                setExpandedProject((current) =>
                  current === project.name ? null : project.name
                )
              }
            />
          )
        )}
      </div>

      {/* Footer */}
      <div className="px-2.5 pb-2.5 pt-1 flex items-center justify-between">
        <FooterButton
          label="Refresh"
          icon={
            <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
              <path d="M8 3a5 5 0 104.9 6h-1.53A3.5 3.5 0 118 4.5V7l3.5-3L8 1v2z" />
            </svg>
          }
        />
        <div className="flex items-center gap-0.5">
          <FooterButton
            label="Settings"
            icon={
              <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
                <path d="M8 5.5A2.5 2.5 0 105.5 8 2.5 2.5 0 008 5.5zm0 4A1.5 1.5 0 119.5 8 1.5 1.5 0 018 9.5z" transform="translate(0 .5)" />
                <path d="M13.3 8.5a5.6 5.6 0 000-1l1.4-1.1-1.3-2.3-1.7.5a5.3 5.3 0 00-.9-.5L10.5 2h-2.7l-.3 1.8a5.3 5.3 0 00-.9.5l-1.7-.6-1.3 2.3L5 7.2a5.6 5.6 0 000 1L3.6 9.3l1.3 2.3 1.7-.5a5.3 5.3 0 00.9.5l.3 1.7h2.7l.3-1.7a5.3 5.3 0 00.9-.5l1.7.5 1.3-2.3z" opacity="0.9" />
              </svg>
            }
          />
          <FooterButton
            label="Quit"
            icon={
              <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
                <path d="M7.25 1.5h1.5v6h-1.5z" />
                <path d="M4.2 3.6A5.5 5.5 0 108 13.5 5.5 5.5 0 0011.8 3.6l-.9 1.2a4 4 0 11-5.8 0z" />
              </svg>
            }
          />
        </div>
      </div>
    </div>
  );
}
