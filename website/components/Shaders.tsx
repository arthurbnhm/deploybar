"use client";

import { getShaderNoiseTexture } from "@paper-design/shaders";
import { GrainGradient } from "@paper-design/shaders-react";
import { useEffect, useState } from "react";

/**
 * GrainGradient builds its noise texture from a data-URI Image during render
 * and the WebGL mount throws if that image hasn't finished decoding yet.
 * Decode it once up front so every later mount finds it ready.
 */
let noiseTextureReady: Promise<void> | null = null;
function ensureNoiseTextureDecoded(): Promise<void> {
  if (!noiseTextureReady) {
    noiseTextureReady = (async () => {
      try {
        await getShaderNoiseTexture()?.decode();
      } catch {
        // If decoding fails we mount anyway; the library falls back gracefully.
      }
    })();
  }
  return noiseTextureReady;
}

function useShaderReady() {
  const [mounted, setMounted] = useState(false);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    let active = true;
    ensureNoiseTextureDecoded().then(() => {
      if (active) setMounted(true);
    });
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(query.matches);
    const onChange = (event: MediaQueryListEvent) => setReduced(event.matches);
    query.addEventListener("change", onChange);
    return () => {
      active = false;
      query.removeEventListener("change", onChange);
    };
  }, []);

  return { mounted, reduced };
}

/**
 * Aurora bands for the hero — flowing grain-gradient waves in the colors of
 * a deploy pipeline (queued indigo, building ember, ready teal).
 */
export function AuroraBackdrop() {
  const { mounted, reduced } = useShaderReady();

  return (
    <div className="pointer-events-none absolute inset-0" aria-hidden="true">
      {/* CSS approximation shown until the canvas is live, so first paint has atmosphere */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(90% 55% at 50% 78%, rgba(61, 46, 158, 0.5), transparent 70%), radial-gradient(60% 40% at 30% 85%, rgba(19, 106, 83, 0.45), transparent 70%), radial-gradient(55% 35% at 72% 88%, rgba(196, 116, 46, 0.35), transparent 70%)",
        }}
      />
      {mounted && (
        <div className="absolute inset-0 animate-fade-in">
          <GrainGradient
            style={{ width: "100%", height: "100%" }}
            colorBack="#08080a"
            colors={["#2a2178", "#0e5243", "#a55a20", "#111632"]}
            softness={0.9}
            intensity={0.42}
            noise={0.4}
            shape="wave"
            speed={reduced ? 0 : 0.5}
          />
        </div>
      )}
      {/* Calm the top so the headline sits on near-black; fade the bottom into the page */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, #08080a 0%, rgba(8, 8, 10, 0.8) 30%, rgba(8, 8, 10, 0.25) 52%, rgba(8, 8, 10, 0.08) 66%, rgba(8, 8, 10, 0.6) 86%, #08080a 98%)",
        }}
      />
    </div>
  );
}

/**
 * A slow-breathing grainy orb for the closing call-to-action.
 */
export function EmberOrb() {
  const { mounted, reduced } = useShaderReady();

  return (
    <div
      className="pointer-events-none absolute left-1/2 top-1/2 aspect-square w-[min(46rem,120vw)] -translate-x-1/2 -translate-y-1/2"
      style={{
        maskImage: "radial-gradient(closest-side, black 55%, transparent)",
        WebkitMaskImage: "radial-gradient(closest-side, black 55%, transparent)",
      }}
      aria-hidden="true"
    >
      {mounted && (
        <div className="absolute inset-0 animate-fade-in">
          <GrainGradient
            style={{ width: "100%", height: "100%" }}
            colorBack="#08080a"
            colors={["#c2661f", "#5a2d14", "#173f36"]}
            softness={0.75}
            intensity={0.4}
            noise={0.45}
            shape="sphere"
            speed={reduced ? 0 : 0.35}
          />
        </div>
      )}
    </div>
  );
}
