---
version: alpha
name: Third Spaces
description: Community Field Guide — native, evidence-led discovery with calm geography and dated practical context.
colors:
  primary: "#285A2D"
  brand.forest: "#488C42"
  brand.moss: "#698C46"
  brand.leaf: "#428C56"
  brand.olive: "#868C42"
  brand.teal: "#428C6F"
  background.canvas: "#F7F5EC"
  background.surface: "#FFFDF7"
  text.primary: "#20291F"
  text.secondary: "#576252"
  action.strong: "#285A2D"
  text.onAction: "#FFFFFF"
  text.community: "#235C48"
  status.warning: "#705D16"
  status.destructive: "#A63232"
  border.control: "#798572"
  border.divider: "#D7DDCF"
  surface.selected: "#E6EDDE"
  dark.canvas: "#151C17"
  dark.surface: "#202B23"
  dark.text.primary: "#F2F3E9"
  dark.text.secondary: "#B5C0AF"
  dark.action: "#A8D49C"
  dark.community: "#98CEB4"
  dark.warning: "#E4CE83"
  dark.destructive: "#FFB4AB"
  dark.border.control: "#7E8976"
typography:
  page-title:
    fontFamily: system
    fontSize: 34px
    fontWeight: 700
  place-title:
    fontFamily: system
    fontSize: 28px
    fontWeight: 600
  section-title:
    fontFamily: system
    fontSize: 22px
    fontWeight: 600
  card-title:
    fontFamily: system
    fontSize: 17px
    fontWeight: 600
  body:
    fontFamily: system
    fontSize: 17px
    fontWeight: 400
  practical:
    fontFamily: system
    fontSize: 15px
    fontWeight: 400
  provenance:
    fontFamily: system
    fontSize: 13px
    fontWeight: 400
spacing:
  xxs: 4pt
  xs: 8pt
  sm: 12pt
  md: 16pt
  lg: 24pt
  xl: 32pt
  xxl: 48pt
rounded:
  thumbnail: 8px
  control: 12px
  editorial: 16px
components:
  primary-action:
    backgroundColor: "{colors.action.strong}"
    textColor: "{colors.text.onAction}"
    rounded: "{rounded.control}"
    padding: "{spacing.md}"
  primary-action-dark:
    backgroundColor: "{colors.dark.action}"
    textColor: "{colors.dark.canvas}"
    rounded: "{rounded.control}"
    padding: "{spacing.md}"
  place-card:
    backgroundColor: "{colors.background.surface}"
    textColor: "{colors.text.primary}"
    rounded: "{rounded.control}"
    padding: "{spacing.md}"
  place-card-dark:
    backgroundColor: "{colors.dark.surface}"
    textColor: "{colors.dark.text.primary}"
    rounded: "{rounded.control}"
    padding: "{spacing.md}"
---

## Overview

**Community Field Guide.** “Find somewhere you can spend time—and know what to expect before you go.” Grammar: **place → practical evidence → dated community context**. Geography is an index, community explains why a visit may fit, editorial selection is explicit and expiring, and unknown coverage is honest. Are.na inspires deliberate collecting, not its brand/grid/content; Google Maps inspires geographic muscle memory, not provider data, pin assets or layout. Native iOS navigation, system type and assistive technology outrank both. No promotional hero, engagement scoreboard, paid placement, automatic Carson center or synthetic listing presented as a real place.

This document specifies future native implementation; the current app has not adopted these tokens. The five raw greens are brand identity, **not** interchangeable functional text colors. `ThirdSpace/Views/DesignSystem.swift` will eventually map these to native semantic/adaptive assets; this file is the intended token definition. `docs/design/contrast-pairs.json` contains token-name test pairs, not a second palette.

## Colors

The YAML values are exact opaque sRGB primitives/semantic variants. Light: cream `background.canvas`, raised `background.surface`, dark-green `text.primary`, separate `text.secondary`; deep `action.strong` for links/buttons, `text.community` for underlined discussion links, amber `status.warning` for pending/stale and red `status.destructive` for error/removal. Dark: `dark.canvas` and `dark.surface` with `dark.text.*`, `dark.action`, `dark.community`, `dark.warning`, `dark.destructive`, `dark.border.control`. System appearance is default; system/light/dark user choice is MVP. Increased Contrast strengthens boundaries; Reduce Transparency substitutes opaque planes. Native basemap follows system appearance but overlay text stays on opaque app surfaces.

The five exact brand colors—forest `#488C42`, moss `#698C46`, leaf `#428C56`, olive `#868C42`, teal `#428C6F`—are nontext accents only. All fail normal text contrast on white, canvas and surface; white labels on their fills also fail 4.5:1. Even dark primary ink on those fills reaches only 3.65–4.18:1. **No normal text on raw brand fills and no raw brand as normal text, even behind an alias.** Forest is the single recognizable discovery accent; teal marks community; moss/olive are sparse editorial accents, leaf reinforces positive evidence, not a universal verification seal. Do not distribute five greens equally across tabs/categories.

Measured examples (rounded for display only): primary ink/canvas 13.75:1, primary ink/surface 14.76; secondary/canvas 5.87, secondary/surface 6.31; white/deep action 8.11; action text/canvas 7.42; community text/surface 7.66; warning text/surface 6.32; destructive text/surface 6.61. Essential control border/canvas 3.55, border/surface 3.82, border/selected plane 3.24; dark control border/dark surface 4.00. Dark primary/dark surface 13.12, secondary/dark surface 7.77, canvas label/dark action 10.38. All actual composited normal text ≥4.5:1 and essential nontext icons/boundaries ≥3:1, compared **without rounding** using WCAG sRGB linear luminance. Check `python3 scripts/verify-design-contrast.py`; rendered state/opacity tests remain necessary. `border.divider` is decorative, not an input boundary. No opacity tricks, shadows or rounded-threshold passes; image/map text requires an opaque panel.

Status always has a word and icon: Draft pencil + secondary; Pending clock + warning; Needs changes exclamation + warning; Approved check + action strong; Rejected x + destructive; Hidden/private lock + secondary; Expired/stale clock + warning. Approval never implies safe or recently verified. Selected chips use `surface.selected` with deep text, check and 2 pt action outline, not tint alone.

## Typography

The YAML spec accepts `px` but not `pt` for typography and rounded dimensions: those values are **1:1 nominal default-category native point proxies**, not CSS pixel rules or fixed SwiftUI frames. SwiftUI semantic styles and Dynamic Type remain authoritative: page `.largeTitle` 34 pt bold; place/guide `.title` 28 pt semibold; section `.title2` 22 pt semibold; card `.headline` 17 pt semibold; body/form/button `.body` 17 pt (button semibold); practical `.subheadline` 15 pt; provenance `.footnote` 13 pt. Use semantic SwiftUI text styles and Dynamic Type, not a bundled font; local scripts use system fallback, no Latin tracking forced on Arabic/CJK. Long original names, authors and metadata wrap; essential access restrictions never live only in tiny captions. Avoid all-caps metadata paragraphs, text in photos, shrink-to-fit or fixed-height text containers. On iPad body measure roughly 55–70 characters, not a full-width paragraph.

## Layout

4 pt rhythm; tokens 4/8/12/16/24/32/48 pt. iPhone side margin 16 (20 if space), cards 16 padding, group gap 16, section gap 24/32. iPad margins 24/32, detail column ≤720 pt; resizable results nominal 320–420 pt next to map in regular width. Compact multitasking reuses iPhone layout. Observe safe areas, keyboard and map attribution. Minimum hit target 44×44 pt, ideally 48 for map controls; scale action height as text grows. Map and Explore list are separate tabs (2026-10-13 decision) over one shared filter query, never two independent searches; sheets offer accessible buttons for collapsed/medium/expanded states and can grow to full screen at AX sizes.

## Elevation & Depth

Flat cards use 1 pt decorative dividers and 1–1.5 pt **contrast-tested** functional borders instead of heavy stacked shadows. Only floating map cards/controls get restrained light shadow (black 10%, blur 12 pt, y 3); in dark mode prefer an outline. No glass-only copy against tiles/photos. System tab material needs an opaque accessibility fallback.

## Shapes

Thumbnails/tags 8 pt, cards/controls 12, editorial image panels 16; system controls native sheet corners. Capsule only for short chips. Selected/focus outline 2 pt deep action; selected fill and icon/word redundant. Approximate geography has a dashed boundary plus “Approximate”; sensitive hidden uses lock, never an exact pin tip.

## Components

- **Explore pin:** forest plate with cream `book` SF Symbol (essential nontext ≥3:1), halo/dark outer stroke against changing tiles; selected ring/scale once and selected accessibility trait. Cluster deep action fill/white count, spoken as “N approved places in this area; zoom in.” At overlapping positions offer a labelled member list; aggregate world cells are distinct from native local clusters. Provider map POIs must not masquerade as owned pins.
- **Search/filters/map controls:** opaque search field with explicit city/area and location actions; intent chips Focus `book`, Meet `person.2`, Unwind `leaf`, Move `figure.walk`, Create `pencil.and.outline` with words (not five color codes). Filters show count; “Search this area” is a user-triggered commit after panning. Recenter, List, Add and detent controls remain labelled and above map attribution.
- **Place card:** name/type/locality, two practical observations with source/date, optional 4:3 thumbnail and separately tappable 44 pt save. No invented distance, rating or live open badge. Accessibility sizes stack image and text. Place detail presents practical table and provenance before archive; never force a full-screen hero scroll to discover cost/access.
- **Post/fact/status:** teal decorative leading rule on an opaque post card, accessible dark teal link/label, original language/visit/published date, Helpful and Report/Block. Facts distinguish unknown from negative and source/date from approval. Status chip uses words + icon + tested semantic text; no color-only verification.
- **Primary action:** “Submit for review,” `text.onAction` on `action.strong`, 12 pt radius, ≥48 pt default height, 16 pt horizontal padding, grows for Dynamic Type; dark `dark.canvas` on `dark.action`. In-flight spinner + “Submitting…”, explicit server receipt; error preserves form and focuses summary. One high-emphasis action per step; destructive confirmation separate.
- **Featured/saved/profile:** human-curated reason, curator, review and expiry on each feature; private collection not silently published; signed-out Explore remains open. Staff queue appears only after server capability check, and client visibility never authorizes decisions.

## Do's and Don'ts

Do show approved-only counts, provenance, last checked date, honest no-coverage/offline/filter-empty states and a list fallback. Do distinguish location precision and consent. Don't clone reference branding/grid/pins or rely on provider terms as a catalog license. Don't put small brand-green text on cream, white labels on raw brand fills, words directly over map tiles or opacity-reduced functional text. Don't equate approval with verification/safety, use leaderboards (1–5 star ratings with count are allowed by the 2026-10-13 product decision; always show the count), make a drag the only action or animate a user-driven camera pan.

## Photography & Rights

Documentary seating, entry, shade and atmosphere, not stock/generative fake scenes; no identifiable bystanders/minors without appropriate consent. Card 4:3, guide 3:2, detail 4:3 and full viewer; don't crop out a step/ramp in an access photo. No image uses a labelled no-photo outline illustration, not an invented venue. Credit is accessible on each item; license/source/permission and alt text are separate. Strip EXIF GPS before serving, review background clues for sensitive places. Image text sits on opaque plates.

## Motion & Accessibility

System sheet/navigation gestures; selection crossfade 150–220 ms, deliberate camera move ~250–350 ms, one-time pin scale ≤1.1. No looping pulse, autoplay, spring across continents or map reset on response. Reduced Motion removes zoom/scale and uses instant/quiet crossfade. Optional haptic never stands alone. VoiceOver order: search → filters → area actions → result/card → tabs; pin announces name/type/precision, cluster count/action; prominent “Show results as list.” Focus returns on dismissal. Switch, keyboard, Voice Control, Reduced Transparency, Increased Contrast and 44 pt targets all need runtime verification.

## Screen recipes

Explore has compact search/area, intent row, filters, map with coverage legend and preview sheet; List keeps same query and actual cursor pages. Detail uses description → practical table/provenance/directions → Overview/Community/Events → related editorial collections. Add Location: duplicate check → position with text alternative → details → rights/photos → privacy/public preview → pending receipt or preserved draft. Featured carries region/expiry/rationale and honest empty local curation. Saved is private Inbox/collections with offline as-of scope; Profile shows draft/pending/published, sync, blocked users, safety/contact and deletion. Error, provider/map failure, offline cold start and location denial never silently substitute fake results.

## Verification checklist

`docs/design/contrast-pairs.json` tests the exact YAML color tokens using unrounded sRGB math, **not** screenshots, composited opacity, local accessibility audits or legal/rights review. Execute verifier on every token change; add any new functional foreground/background states to the pair file, including disabled/focus/selected and adaptive appearances. Then execute `docs/qa/native-acceptance.md` on real simulator/device layouts, long localized text, light/dark, AX sizes, permissions/provider failures and VoiceOver; record evidence and failures rather than checking boxes by assumption. Token changes require design owner review and ratio/test update; no token change is approved merely because a document is edited.
