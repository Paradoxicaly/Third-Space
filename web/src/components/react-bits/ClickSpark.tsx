// Adapted from React Bits ClickSpark by David Haz.
// License: MIT + Commons Clause. See THIRD_PARTY_NOTICES.md.
"use client";

import type { PropsWithChildren } from "react";
import { useCallback, useEffect, useRef } from "react";

type Spark = { x: number; y: number; angle: number; startTime: number };

type ClickSparkProps = PropsWithChildren<{
  sparkColor?: string;
  sparkCount?: number;
  duration?: number;
}>;

export function ClickSpark({
  children,
  sparkColor = "#ff6a4d",
  sparkCount = 10,
  duration = 460,
}: ClickSparkProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const sparks = useRef<Spark[]>([]);
  const reducedMotion = useRef(false);

  useEffect(() => {
    reducedMotion.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const canvas = canvasRef.current;
    const parent = canvas?.parentElement;
    if (!canvas || !parent || reducedMotion.current) return;

    const resize = () => {
      const bounds = parent.getBoundingClientRect();
      canvas.width = Math.max(1, Math.floor(bounds.width));
      canvas.height = Math.max(1, Math.floor(bounds.height));
    };
    const observer = new ResizeObserver(resize);
    observer.observe(parent);
    resize();
    return () => observer.disconnect();
  }, []);

  const animate = useCallback(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const draw = (timestamp: number) => {
      context.clearRect(0, 0, canvas.width, canvas.height);
      sparks.current = sparks.current.filter((spark) => {
        const progress = (timestamp - spark.startTime) / duration;
        if (progress >= 1) return false;
        const eased = progress * (2 - progress);
        const distance = eased * 28;
        const length = 10 * (1 - eased);
        context.strokeStyle = sparkColor;
        context.lineWidth = 2;
        context.beginPath();
        context.moveTo(
          spark.x + distance * Math.cos(spark.angle),
          spark.y + distance * Math.sin(spark.angle),
        );
        context.lineTo(
          spark.x + (distance + length) * Math.cos(spark.angle),
          spark.y + (distance + length) * Math.sin(spark.angle),
        );
        context.stroke();
        return true;
      });
      if (sparks.current.length) requestAnimationFrame(draw);
    };

    requestAnimationFrame(draw);
  }, [duration, sparkColor]);

  return (
    <div
      className="click-spark"
      data-react-bits="click-spark"
      onClick={(event) => {
        if (reducedMotion.current || !canvasRef.current) return;
        const bounds = canvasRef.current.getBoundingClientRect();
        const now = performance.now();
        sparks.current.push(
          ...Array.from({ length: sparkCount }, (_, index) => ({
            x: event.clientX - bounds.left,
            y: event.clientY - bounds.top,
            angle: (Math.PI * 2 * index) / sparkCount,
            startTime: now,
          })),
        );
        animate();
      }}
    >
      <canvas ref={canvasRef} className="click-spark__canvas" aria-hidden="true" />
      {children}
    </div>
  );
}
