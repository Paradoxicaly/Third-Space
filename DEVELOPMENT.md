# Native development notes

## Product boundary

Worldwide native iOS field guide; Carson/South Bay is a candidate first seed collection only. Explore is eventually map-first with complete list parity. The M2 list is deliberately permission-free and never a replacement for map discovery. Four destinations: Explore, Featured, Saved, Profile; Add/Contribute is an action. No star score, reputation/leaderboard, paid placement, location history, or fabricated nearby claims.

## Engineering sequence

- M0: record open legal, operational and provider decisions; unsigned baseline build. Synthetic local work can proceed without a release sign-off.
- M1: native tests/shared scheme, exact light/dark tokens, adaptive phone/iPad shell, contrast verifier, accessibility review.
- M2: typed source/freshness/unknown models, repository boundaries, clearly synthetic fixtures only under test launch, local saves/drafts, complete owned list/filter/details and honest loading/empty/error/offline behavior.
- M3+: MapKit world rendering/search, service adapters, contributions, backend, moderation, regional rollout and release gates are **not implemented by M2**. Do not turn a placeholder into a success claim.

## Data trust rules

Own catalog records require independent coordinate/fact rights, public approved revision and source. Provider geographies are ephemeral and distinct from places. Unknown hours/access are neither open/closed nor accessible/inaccessible. No fake distances, hardcoded closing time, demo rating, hidden pending row, or mock fallback when a real repository fails. Drafts are local until a genuine server receipt exists. A cold offline browse cannot manufacture uncached results. Sensitive/removed content must not stay readable in cache.

## Verification

Use the shared `ThirdSpace` scheme, actual installed iPhone and iPad destinations, `CODE_SIGNING_ALLOWED=NO` for local simulator builds/tests, `python3 scripts/verify-design-contrast.py`, and the visual/assistive-tech matrix in `docs/qa/native-acceptance.md`. Report exact command, exit, test counts, skips and unverified boundaries. Never infer VoiceOver, region/provider coverage or publication readiness from compilation alone.

Do not edit `web/` for native milestones; preserve unrelated work. No commit/push/upload absent explicit authorization.
