import brandTokens from "../../design/brand-tokens.json";

export type DeploymentStatus = "ready" | "building" | "failed" | "queued" | "canceled";

// Sourced from design/brand-tokens.json — the single source of truth shared
// with the Swift app (see DeployBarTests/BrandTokensTests.swift).
export const STATUS_COLORS: Record<DeploymentStatus, string> = {
  ready: brandTokens.statusColors.ready.hex,
  building: brandTokens.statusColors.building.hex,
  failed: brandTokens.statusColors.failed.hex,
  queued: brandTokens.statusColors.queued.hex,
  canceled: brandTokens.statusColors.canceled.hex,
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
    description: "Connects directly to Vercel's API. Optional update checks use GitHub. No analytics or tracking.",
  },
  {
    title: "Three polling modes",
    description: "Balanced, Aggressive, or Eco — choose how often DeployBar checks for updates.",
  },
];

export const SITE_URL = "https://deploybar.com";
export const GITHUB_REPO_URL = "https://github.com/arthurbnhm/deploybar";
export const RELEASE_URL = `${GITHUB_REPO_URL}/releases/latest`;
export const MAC_DOWNLOAD_URL = `${GITHUB_REPO_URL}/releases/latest/download/DeployBar.zip`;
