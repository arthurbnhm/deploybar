export function LogoIcon({ className = "w-8 h-8" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 128 128"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id="logo-tile" x1="18" y1="14" x2="110" y2="116" gradientUnits="userSpaceOnUse">
          <stop stopColor="#F7F8FA" />
          <stop offset="1" stopColor="#E9EDF3" />
        </linearGradient>
        <linearGradient id="logo-triangle" x1="43" y1="28" x2="94" y2="93" gradientUnits="userSpaceOnUse">
          <stop stopColor="#C7A3FF" />
          <stop offset="0.52" stopColor="#7B78FF" />
          <stop offset="1" stopColor="#3B57F4" />
        </linearGradient>
        <radialGradient id="logo-glow" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(60 46) rotate(32) scale(44 34)">
          <stop stopColor="#F8F0FF" stopOpacity="0.95" />
          <stop offset="1" stopColor="#F8F0FF" stopOpacity="0" />
        </radialGradient>
        <path id="logo-triangle-shape" d="M64 31L95 88H33L64 31Z" />
        <clipPath id="logo-triangle-clip">
          <use href="#logo-triangle-shape" />
        </clipPath>
      </defs>

      <rect x="6" y="6" width="116" height="116" rx="30" fill="url(#logo-tile)" />
      <rect x="6.5" y="6.5" width="115" height="115" rx="29.5" stroke="#D4DAE4" />

      <g transform="translate(0 2)">
        <ellipse cx="64" cy="89" rx="26" ry="9" fill="#4B5EED" fillOpacity="0.22" />
        <use href="#logo-triangle-shape" fill="url(#logo-triangle)" />
        <ellipse cx="57" cy="52" rx="30" ry="20" fill="url(#logo-glow)" clipPath="url(#logo-triangle-clip)" />
        <ellipse cx="66" cy="82" rx="24" ry="9" fill="#2739B8" fillOpacity="0.16" clipPath="url(#logo-triangle-clip)" />
        <use
          href="#logo-triangle-shape"
          fill="none"
          stroke="#EBDFFF"
          strokeOpacity="0.42"
          strokeWidth="2.2"
          strokeLinejoin="round"
        />
      </g>
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
