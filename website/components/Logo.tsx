export function LogoIcon({ className = "w-8 h-8" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 128 128"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <rect x="8" y="8" width="112" height="112" rx="26" fill="white" />
      <rect x="9" y="9" width="110" height="110" rx="25" stroke="#D9D9DE" strokeWidth="2" />
      <path
        d="M64 41.5C65.4 41.5 66.7 42.3 67.4 43.5L84.8 76.2C85.5 77.5 85.5 79.3 84.8 80.6C84.1 81.9 82.8 82.7 81.3 82.7H46.7C45.2 82.7 43.9 81.9 43.2 80.6C42.5 79.3 42.5 77.5 43.2 76.2L60.6 43.5C61.3 42.3 62.6 41.5 64 41.5Z"
        fill="#1F1F22"
      />
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
