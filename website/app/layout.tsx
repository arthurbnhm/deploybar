import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], display: "swap" });

export const metadata: Metadata = {
  title: "DeployBar — Vercel Deploys in Your Menu Bar",
  description:
    "A native macOS menu bar app that monitors your Vercel production deployments in real-time. Free and open source.",
  icons: { icon: "/favicon.svg" },
};

export const viewport: Viewport = {
  themeColor: "#F5F0EB",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased bg-[#F5F0EB]`}>{children}</body>
    </html>
  );
}
