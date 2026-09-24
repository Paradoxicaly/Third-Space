# Third Spaces

Third Spaces is a Capstone project exploring how people can discover welcoming places to study, work, meet, move, create, or relax outside home and school. Instead of only listing businesses, it organizes places by the feeling or need they support.

The current pilot focuses on **Carson, California**. It is an early visual prototype—not yet a production directory—and its example listings and images must be verified before public release.

## Problem

Many people, especially students, struggle to find affordable, welcoming places to spend time beyond home and school. Existing map products make it difficult to search for qualities such as quietness, study space, outdoor seating, accessibility, or a sense of community. Third Spaces is designed to make those practical and social details easier to find.

## Current prototypes

This repository contains two related prototypes:

- **`web/`** — the active Next.js visual pilot, called “Living City.” It includes intent-based discovery, Carson-area prototype cards, interactive motion, accessibility-aware reduced-motion behavior, and automated tests.
- **`ThirdSpace/`** — an earlier SwiftUI iOS concept with Explore, Map, Saved, and Profile tabs plus local sample place data.

The web pilot currently uses local prototype content only. Planned future work includes verified local place data, map search, community reviews, moderated submissions, authentication, and a secure backend.

## Run the web prototype

### Requirements

- Node.js 20 or newer
- npm

### Setup

```bash
git clone https://github.com/Paradoxicaly/Third-Space.git
cd Third-Space/web
npm install
```

### Start the development server

```bash
npm run dev
```

Open <http://localhost:3000> in a browser.

### Quality checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

End-to-end browser tests are available with:

```bash
npm run test:e2e
```

## Run the iOS concept

1. Open `ThirdSpace.xcodeproj` in Xcode.
2. Select an iPhone simulator.
3. Press **Run**.

The iOS prototype uses in-app mock data, so no account, API key, or network connection is required.

## Technology

- Next.js, React, and TypeScript
- GSAP, Lenis, Vanta, and selected React Bits components for the web prototype’s motion design
- Swift and SwiftUI for the iOS concept
- Vitest, Testing Library, and Playwright for web verification

See [`web/THIRD_PARTY_NOTICES.md`](web/THIRD_PARTY_NOTICES.md) for component and library notices. Prototype imagery is documented in [`web/public/places/README.md`](web/public/places/README.md).

## Project status and next steps

The project is in an early design-and-validation phase. Before launch, it needs:

- verified and attributed Carson-area place information and photography;
- a searchable map and filters;
- accounts, saves, reviews, and moderation workflows;
- privacy and accessibility testing with users;
- a production backend and deployment plan.

## Git workflow

Development happens through feature branches and Pull Requests. Before starting work, pull the latest `main`; commit small, focused changes; push at the end of a work session; and open a Pull Request for a complete feature before merging it into `main`.
