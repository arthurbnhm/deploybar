import { STATUS_COLORS, type DeploymentStatus } from "@/lib/data";

export function StatusDot({
  status,
  animated = true,
  size = 7,
}: {
  status: DeploymentStatus;
  animated?: boolean;
  size?: number;
}) {
  const color = STATUS_COLORS[status];
  const shouldPulse = animated && (status === "building" || status === "queued");

  return (
    <span
      className={`inline-block rounded-full shrink-0 ${shouldPulse ? "animate-pulse-dot" : ""}`}
      style={{
        width: size,
        height: size,
        backgroundColor: color,
      }}
    />
  );
}
