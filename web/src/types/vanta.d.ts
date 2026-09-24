declare module "vanta/dist/vanta.fog.min" {
  import type * as THREE from "three";

  type VantaEffect = {
    destroy: () => void;
    resize?: () => void;
  };

  type VantaOptions = {
    el: HTMLElement;
    THREE: typeof THREE;
    mouseControls?: boolean;
    touchControls?: boolean;
    gyroControls?: boolean;
    minHeight?: number;
    minWidth?: number;
    highlightColor?: number;
    midtoneColor?: number;
    lowlightColor?: number;
    baseColor?: number;
    blurFactor?: number;
    speed?: number;
    zoom?: number;
  };

  const fog: (options: VantaOptions) => VantaEffect;
  export default fog;
}
