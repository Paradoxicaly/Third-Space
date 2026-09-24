import {
  Binoculars,
  BookOpenText,
  Camera,
  Coffee,
  Footprints,
  Leaf,
  MessageCircleMore,
  Palette,
} from "lucide-react";

export const intents = [
  { name: "Focus", note: "Quiet corners, Wi-Fi, room to think", icon: BookOpenText },
  { name: "Meet", note: "Tables, conversation, community", icon: MessageCircleMore },
  { name: "Unwind", note: "Shade, calm, somewhere to exhale", icon: Leaf },
  { name: "Move", note: "Trails, parks, paths worth taking", icon: Footprints },
  { name: "Create", note: "Light, texture, scenes to capture", icon: Camera },
] as const;

export const places = [
  {
    name: "Carson Library",
    category: "Focus",
    location: "Carson · 0.8 mi",
    image: "/places/carson-library.jpg",
    alt: "Warm tables and pendant lights in a community café-style interior",
    meta: ["Free", "Quiet zones", "Wi-Fi"],
    note: "A calm public anchor for reading, research, and an afternoon reset.",
    accent: "coral",
    icon: BookOpenText,
  },
  {
    name: "Dominguez Rancho Adobe Museum",
    category: "Create",
    location: "Rancho Dominguez · 2.4 mi",
    image: "/places/adobe-museum.jpg",
    alt: "Sunlit path leading through trees toward an open landscape",
    meta: ["Historic", "Garden", "Photo-friendly"],
    note: "Layered history, quiet grounds, and the kind of afternoon light worth waiting for.",
    accent: "moss",
    icon: Palette,
  },
  {
    name: "Calas Park",
    category: "Move",
    location: "Carson · 1.9 mi",
    image: "/places/calas-park.jpg",
    alt: "Green parkland and a winding path viewed from above",
    meta: ["Free", "Outdoors", "Open space"],
    note: "An easy neighborhood pause for a walk, a bench, or time with friends.",
    accent: "gold",
    icon: Binoculars,
  },
] as const;

export const quickFacts = [
  { value: "30–50", label: "places in the Carson pilot" },
  { value: "5", label: "intent-led ways to explore" },
  { value: "100%", label: "community submissions reviewed" },
] as const;

export const useCases = [
  { label: "Study somewhere that doesn’t rush you", icon: Coffee },
  { label: "Find golden-hour photo spots", icon: Camera },
  { label: "Take the long way home", icon: Footprints },
] as const;
