"use client";

import { useEffect, useRef, useState } from "react";
import { MenuBarMockup } from "@/components/MenuBarMockup";

export function DeployBarButton() {
  const [isOpen, setIsOpen] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    function handleClick(event: MouseEvent) {
      if (
        popoverRef.current &&
        !popoverRef.current.contains(event.target as Node) &&
        buttonRef.current &&
        !buttonRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }

    if (!isOpen) {
      return;
    }

    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [isOpen]);

  return (
    <div className="relative inline-flex">
      <button
        ref={buttonRef}
        onClick={() => setIsOpen((open) => !open)}
        className="inline-flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-colors bg-[#EDE6DF] text-[#1A1A1A] hover:bg-[#E5DDD4] whitespace-nowrap"
      >
        See it in action
      </button>

      {isOpen && (
        <div
          ref={popoverRef}
          className="absolute top-full right-0 mt-4 z-50 animate-slide-up"
          style={{ animationDuration: "0.25s" }}
        >
          <div className="absolute inset-0 -inset-x-8 -inset-y-6 bg-[#E8927C]/15 blur-3xl rounded-3xl pointer-events-none" />
          <div className="relative">
            <MenuBarMockup animated className="shadow-2xl" />
          </div>
        </div>
      )}
    </div>
  );
}
