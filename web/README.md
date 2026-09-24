# Third Spaces web pilot

This directory contains the active **Living City** web prototype for Third Spaces: an intent-first discovery experience for welcoming places around Carson, California.

It is a visual, local-data prototype. The cards and imagery are not yet a production place directory; verify all place information, attribution, and local photography before publishing.

## Run locally

```bash
npm install
npm run dev
```

Open <http://localhost:3000>.

## Verify

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run test:e2e
```

## What is included

- intent selection for Focus, Meet, Unwind, Move, and Create;
- Carson-area prototype place cards;
- GSAP, Lenis, Vanta, and adapted React Bits motion components;
- reduced-motion behavior and semantic test coverage;
- Vitest component tests and Playwright browser tests.

For the project overview, iOS prototype, and planned product work, see the [repository README](../README.md). Third-party notices are in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md); prototype image sources and limitations are in [`public/places/README.md`](public/places/README.md).
