"use client";

import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Lenis from "lenis";
import type { PropsWithChildren } from "react";
import { useEffect } from "react";

export function MotionProvider({ children }: PropsWithChildren) {
  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) {
      document.documentElement.dataset.motion = "reduced";
      return;
    }

    document.documentElement.dataset.motion = "full";
    gsap.registerPlugin(ScrollTrigger);

    const lenis = new Lenis({
      duration: 1.18,
      easing: (value) => Math.min(1, 1.001 - 2 ** (-10 * value)),
      smoothWheel: true,
      syncTouch: false,
      prevent: (node) => node.closest("[data-lenis-prevent]") !== null,
    });

    const update = (time: number) => lenis.raf(time * 1000);
    lenis.on("scroll", ScrollTrigger.update);
    gsap.ticker.add(update);
    gsap.ticker.lagSmoothing(0);

    return () => {
      gsap.ticker.remove(update);
      lenis.off("scroll", ScrollTrigger.update);
      lenis.destroy();
      delete document.documentElement.dataset.motion;
    };
  }, []);

  return <div data-motion-library="lenis">{children}</div>;
}
