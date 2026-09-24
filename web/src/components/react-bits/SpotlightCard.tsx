// Adapted from React Bits SpotlightCard by David Haz.
// License: MIT + Commons Clause. See THIRD_PARTY_NOTICES.md.
"use client";

import type { PropsWithChildren } from "react";
import { useRef, useState } from "react";

type SpotlightCardProps = PropsWithChildren<{
  className?: string;
  spotlightColor?: string;
}>;

export function SpotlightCard({
  children,
  className = "",
  spotlightColor = "rgba(255, 112, 78, 0.28)",
}: SpotlightCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [isFocused, setIsFocused] = useState(false);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [opacity, setOpacity] = useState(0);

  return (
    <div
      ref={ref}
      className={`spotlight-card ${className}`}
      data-react-bits="spotlight-card"
      onMouseMove={(event) => {
        if (!ref.current || isFocused) return;
        const bounds = ref.current.getBoundingClientRect();
        setPosition({ x: event.clientX - bounds.left, y: event.clientY - bounds.top });
      }}
      onFocus={() => {
        setIsFocused(true);
        setOpacity(0.7);
      }}
      onBlur={() => {
        setIsFocused(false);
        setOpacity(0);
      }}
      onMouseEnter={() => setOpacity(0.7)}
      onMouseLeave={() => setOpacity(0)}
    >
      <span
        className="spotlight-card__glow"
        aria-hidden="true"
        style={{
          opacity,
          background: `radial-gradient(circle at ${position.x}px ${position.y}px, ${spotlightColor}, transparent 72%)`,
        }}
      />
      {children}
    </div>
  );
}
