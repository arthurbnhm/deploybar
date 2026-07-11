"use client";

import { OPEN_DEMO_EVENT } from "./MenuBarDemo";

export function HeroDemoButton() {
  return (
    <button
      type="button"
      onClick={() => {
        window.scrollTo({ top: 0, behavior: "smooth" });
        window.dispatchEvent(new Event(OPEN_DEMO_EVENT));
      }}
      className="inline-flex cursor-pointer items-center gap-2.5 rounded-full border border-white/15 px-6 py-3 text-sm font-medium text-white/80 transition-colors hover:border-white/35 hover:text-white"
    >
      See it in action
      <span aria-hidden="true" className="text-white/50">
        ↗
      </span>
    </button>
  );
}
