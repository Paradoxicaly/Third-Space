// Adapted from React Bits BlurText by David Haz.
// License: MIT + Commons Clause. See THIRD_PARTY_NOTICES.md.
"use client";

import { motion, type Easing, type Transition } from "motion/react";
import { useEffect, useMemo, useRef, useState } from "react";

type BlurTextProps = {
  text: string;
  delay?: number;
  className?: string;
  animateBy?: "words" | "letters";
  direction?: "top" | "bottom";
};

const buildKeyframes = (
  from: Record<string, string | number>,
  steps: Array<Record<string, string | number>>,
) => {
  const keys = new Set([...Object.keys(from), ...steps.flatMap((step) => Object.keys(step))]);
  return Object.fromEntries(
    [...keys].map((key) => [key, [from[key], ...steps.map((step) => step[key])]]),
  );
};

export function BlurText({
  text,
  delay = 75,
  className = "",
  animateBy = "words",
  direction = "bottom",
}: BlurTextProps) {
  const elements = animateBy === "words" ? text.split(" ") : text.split("");
  const [inView, setInView] = useState(false);
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 },
    );
    observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);

  const from = useMemo(
    () => ({
      filter: "blur(16px)",
      opacity: 0,
      y: direction === "top" ? -44 : 44,
    }),
    [direction],
  );
  const to = useMemo(
    () => [
      { filter: "blur(7px)", opacity: 0.55, y: direction === "top" ? 7 : -7 },
      { filter: "blur(0px)", opacity: 1, y: 0 },
    ],
    [direction],
  );
  const keyframes = buildKeyframes(from, to);
  const ease: Easing = [0.22, 1, 0.36, 1];

  return (
    <span ref={ref} className={`blur-text ${className}`} data-react-bits="blur-text">
      {elements.map((segment, index) => {
        const transition: Transition = {
          duration: 0.78,
          times: [0, 0.45, 1],
          delay: (index * delay) / 1000,
          ease,
        };
        return (
          <motion.span
            key={`${segment}-${index}`}
            initial={from}
            animate={inView ? keyframes : from}
            transition={transition}
            aria-hidden="true"
          >
            {segment}
            {animateBy === "words" && index < elements.length - 1 ? "\u00A0" : null}
          </motion.span>
        );
      })}
      <span className="sr-only">{text}</span>
    </span>
  );
}
