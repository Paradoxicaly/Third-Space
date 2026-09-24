"use client";

import { useEffect, useRef } from "react";

type VantaEffect = { destroy: () => void };

export function VantaScene() {
  const sceneRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const scene = sceneRef.current;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!scene || reduced || process.env.NODE_ENV === "test") return;

    let effect: VantaEffect | undefined;
    let cancelled = false;

    Promise.all([import("three"), import("vanta/dist/vanta.fog.min")])
      .then(([three, fogModule]) => {
        if (cancelled || !sceneRef.current) return;
        effect = fogModule.default({
          el: sceneRef.current,
          THREE: three,
          mouseControls: true,
          touchControls: true,
          gyroControls: false,
          minHeight: 320,
          minWidth: 320,
          highlightColor: 0xffa987,
          midtoneColor: 0x4f887f,
          lowlightColor: 0x183d3a,
          baseColor: 0xf4eadc,
          blurFactor: 0.72,
          speed: 1.25,
          zoom: 0.78,
        });
      })
      .catch(() => {
        scene.dataset.vantaFallback = "true";
      });

    return () => {
      cancelled = true;
      effect?.destroy();
    };
  }, []);

  return (
    <div
      ref={sceneRef}
      className="vanta-scene"
      data-motion-library="vanta"
      aria-hidden="true"
    />
  );
}
