import { MOCK_PROJECTS, STATUS_COLORS, STATUS_LABELS, type DeploymentStatus } from "@/lib/data";
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
        backgroundColor: `${color}18`,
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
}: {
  name: string;
  commit: string;
  status: DeploymentStatus;
  time: string;
  animated: boolean;
}) {
  return (
    <div className="flex items-center gap-2.5 px-2.5 py-2 rounded-lg transition-colors hover:bg-white/[0.08]">
      <StatusDot status={status} animated={animated} />
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <span className="text-[13px] font-medium text-white truncate">
            {name}
          </span>
          <StatusPill status={status} />
        </div>
        <div className="flex items-center justify-between gap-2 mt-0.5">
          <span className="text-[11px] text-white/50 truncate">{commit}</span>
          <span className="text-[10px] text-white/30 shrink-0">{time}</span>
        </div>
      </div>
    </div>
  );
}

export function MenuBarMockup({
  animated = true,
  className = "",
}: {
  animated?: boolean;
  className?: string;
}) {
  return (
    <div
      className={`w-[420px] rounded-xl overflow-hidden ${className}`}
      style={{
        backgroundColor: "#1C1C1E",
        border: "0.5px solid rgba(255,255,255,0.08)",
        boxShadow: "0 25px 50px rgba(0,0,0,0.25)",
      }}
    >
      {/* Header */}
      <div className="px-3.5 pt-3 pb-2.5 flex items-center justify-between border-b border-white/[0.06]">
        <div>
          <span className="text-[13px] font-semibold text-white">
            DeployBar
          </span>
          <span className="text-[11px] text-white/40">
            @developer · just now
          </span>
        </div>
      </div>

      {/* Project List */}
      <div className="px-2 py-2 space-y-1 max-h-[340px]">
        {MOCK_PROJECTS.map((project) => (
          <ProjectRow
            key={project.name}
            {...project}
            animated={animated}
          />
        ))}
      </div>
    </div>
  );
}
