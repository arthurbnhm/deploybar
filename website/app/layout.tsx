import type { Metadata, Viewport } from "next";
import { Geist_Mono, Instrument_Serif, Schibsted_Grotesk } from "next/font/google";
import { SITE_URL } from "@/lib/data";
import "./globals.css";

const sans = Schibsted_Grotesk({
  subsets: ["latin"],
  variable: "--font-schibsted",
  display: "swap",
});

const serif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-instrument",
  display: "swap",
});

const mono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-geist-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "DeployBar — Vercel deploys, in your menu bar",
  description:
    "A native macOS menu bar app that watches your Vercel production deployments in real-time. Free and open source.",
  icons: { icon: "/favicon.svg" },
  alternates: { canonical: "/" },
  openGraph: {
    title: "DeployBar — Vercel deploys, in your menu bar",
    description: "A free, open-source macOS menu bar app for monitoring Vercel deployments.",
    url: SITE_URL,
    siteName: "DeployBar",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#08080a",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${sans.variable} ${serif.variable} ${mono.variable}`}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
