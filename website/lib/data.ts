export type DeploymentStatus = "ready" | "building" | "failed" | "queued" | "canceled";

export const STATUS_COLORS: Record<DeploymentStatus, string> = {
  ready: "#33C77A",
  building: "#F5A624",
  failed: "#F05247",
  queued: "#6B8CF0",
  canceled: "#8F8F93",
};

export const STATUS_LABELS: Record<DeploymentStatus, string> = {
  ready: "Ready",
  building: "Building",
  failed: "Failed",
  queued: "Queued",
  canceled: "Canceled",
};

export interface MockProject {
  name: string;
  commit: string;
  status: DeploymentStatus;
  time: string;
}

export const MOCK_PROJECTS: MockProject[] = [
  { name: "my-saas-app", commit: "fix: resolve auth redirect", status: "ready", time: "2m ago" },
  { name: "docs-site", commit: "docs: update API reference", status: "building", time: "just now" },
  { name: "marketing-page", commit: "feat: add pricing section", status: "ready", time: "5m ago" },
  { name: "api-gateway", commit: "chore: bump dependencies", status: "failed", time: "12m ago" },
];

export interface Feature {
  title: string;
  description: string;
}

export const FEATURES: Feature[] = [
  {
    title: "Real-time monitoring",
    description: "See deployment status updates as they happen with configurable polling intervals.",
  },
  {
    title: "Native macOS app",
    description: "Built with SwiftUI for a seamless, lightweight menu bar experience.",
  },
  {
    title: "Smart notifications",
    description: "Get notified when builds complete or fail. Never miss a broken deploy.",
  },
  {
    title: "Multiple projects",
    description: "Monitor up to 20 Vercel projects simultaneously from a single popover.",
  },
  {
    title: "Privacy-first",
    description: "Connects directly to Vercel's API. No analytics, no tracking, no third-party servers.",
  },
  {
    title: "Three polling modes",
    description: "Balanced, Aggressive, or Eco — choose how often DeployBar checks for updates.",
  },
];

export const GITHUB_REPO_URL = "https://github.com/arthurbnhm/DeployBar";
export const MAC_DOWNLOAD_URL = `${GITHUB_REPO_URL}/releases/latest`;
