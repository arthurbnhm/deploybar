export type DeploymentStatus = "ready" | "building" | "failed" | "queued" | "canceled";

// Mirrors the macOS system palette the app uses (.green/.orange/.red/.indigo/.gray).
export const STATUS_COLORS: Record<DeploymentStatus, string> = {
  ready: "#30D158",
  building: "#FF9F0A",
  failed: "#FF453A",
  queued: "#5E5CE6",
  canceled: "#98989D",
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
  { name: "my-saas-app", commit: "fix: resolve auth redirect", status: "ready", time: "2 min. ago" },
  { name: "docs-site", commit: "docs: update API reference", status: "building", time: "now" },
  { name: "marketing-page", commit: "feat: add pricing section", status: "ready", time: "5 min. ago" },
  { name: "api-gateway", commit: "chore: bump dependencies", status: "failed", time: "12 min. ago" },
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
    description: "Built with SwiftUI and the macOS 26 Liquid Glass design language — a lightweight, truly native menu bar experience.",
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
