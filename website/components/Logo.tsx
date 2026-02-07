export function LogoIcon({ className = "w-8 h-8" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      <rect x="4" y="6" width="24" height="4" rx="2" fill="currentColor" />
      <rect x="4" y="14" width="18" height="4" rx="2" fill="currentColor" opacity="0.4" />
      <rect x="4" y="22" width="12" height="4" rx="2" fill="currentColor" opacity="0.2" />
      <circle cx="27" cy="8" r="3" fill="#33C77A" />
      <circle cx="21" cy="16" r="3" fill="#F5A624" />
      <circle cx="15" cy="24" r="3" fill="#F05247" />
    </svg>
  );
}

export function LogoWordmark({
  className = "",
  iconClass = "w-7 h-7",
  textClass = "text-xl font-semibold",
}: {
  className?: string;
  iconClass?: string;
  textClass?: string;
}) {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <LogoIcon className={iconClass} />
      <span className={textClass}>DeployBar</span>
    </div>
  );
}
