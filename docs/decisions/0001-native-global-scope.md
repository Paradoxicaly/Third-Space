# 0001 — Native worldwide-capable product scope

**Status (2026-10-09):** engineering direction recorded; **not signed off** for release or live data. **Owners:** product and engineering for platform; product/legal/regional partner for distribution; release owner for signing. Role assignments below are accountable functions, not named people or approvals.

## Context and decision

The current web visual pilot and earlier SwiftUI mock are not a verified catalog. Build the community field guide as a native SwiftUI iOS app, minimum iOS 18, with iPad layout in MVP (the current in-progress Xcode configuration now declares device families 1 and 2; this is not verified responsive behavior). Four tabs: Explore with shared map/list, Featured, Saved and Profile; a persistent labelled Add/Contribute action. Worldwide means global schema/bounds, manual region search, locale-safe labels, honest empty coverage and independently approved own places; it **does not** imply worldwide map service, verified places, publishing operations or store distribution. Carson/South Bay is a *possible first verified collection*, never the default center or hard geographic constraint. Retain `web/` separately and untouched by native migration.

Guest browsing and local drafts/saves must work without location/account when their milestone is complete; the current in-progress tree does not yet prove those journeys. Public contributions require auth, source/rights, moderation, safety reporting/blocking and regional language capacity. Do not implement purchased ranking, ratings/points, synthetic production listings, scraped POIs or motion-heavy web chrome. An early reversible local synthetic prototype may proceed while decisions remain open; it cannot be marketed as a production directory.

## Alternatives and consequences

A Carson-only or web-first app would narrow the product model and confuse the prototype with independently approved global data; duplicated Map and Explore tabs create inconsistent query state. Worldwide data ingestion from a map provider would be a rights and trust shortcut, not a valid launch strategy. Native iPad support requires device-family/project changes and real compact/regular QA later, not a claim of current capability.

## Open gates and acceptance

- **Product/engineering:** confirm iOS 18 floor, iPad MVP commitment and release matrix before M1 project configuration changes.
- **Product/legal/regional partner:** decide lawful distribution territories (including mainland China), map limitations/disclosure and locally applicable safety/privacy before store submission; no universal service claim.
- **Product/privacy:** age/teen account policy. Reversible closed-beta default: 18+ contributors pending specialist review; anonymous browsing subject to store/access policy. Age gate alone is not legal clearance.
- **Release owner:** signing team, bundle identity, owned domain/deep links, support and deletion URLs before auth/distribution. No credentials recorded here.
- **Safety lead:** staffed region/language moderation and escalation before enabling regional remote writes. No unsupported auto-approval.

Review these at their milestones; record owner, date, evidence and actual approval in a later revision. Current status remains **open**, regardless of a successful simulator build.

## M0 worktree boundary and sign-off register (2026-10-09)

- **Branch/worktree approach:** retain the existing `feat/third-spaces-web-pilot` checkout in place and limit edits to assigned native/docs paths. No branch switch, stash, reset or commit. The user explicitly requires preservation of unrelated changes; an isolated worktree has **not** been separately agreed. Revisit a dedicated branch/worktree before any merge or release, without overwriting this tree.
- **Existing protected work:** `web/next.config.ts` and `web/src/components/landing/LivingCityPage.tsx` are modified and `web/public/.nojekyll` is untracked. Their SHA-256 values were rechecked against the planning baseline on 2026-10-09; all three match. No `web/` edit is authorized by M0.
- **Human sign-off:** none recorded. The named signatories for product/legal, privacy, safety, operations and release remain **unassigned**. Functional owners in this record are not a substitute for actual named approvers. Do not interpret these records as approval.

| Open decision | Accountable owner to name | What may proceed now / what is blocked |
| --- | --- | --- |
| iOS 18 minimum and iPad MVP | Product + engineering | Reversible simulator shell/tests may proceed; supported-device commitment and release matrix await sign-off. |
| Public identity, signing team, owned domain, callback/support/deletion URLs | Release owner | Local unsigned build allowed; auth callbacks, universal links, archive and distribution blocked. |
| Territorial distribution and mainland-China mapping/legal review | Product + legal + regional partner | Worldwide-capable models and synthetic browse allowed; territory-specific release/coverage claims blocked. |
| Contributor age/teen participation | Product + privacy/legal | Anonymous/local prototype allowed; 18+ contributor closed beta is a proposed conservative default, **not approved policy**; signup blocked. |
| Moderator names, languages, backup and incident escalation | Safety lead | Local drafts allowed; remote intake/publication blocked until staffed scopes and escalation exist. |
| Coordinate and seed rights | Product + legal + content owner | Synthetic local placement and independently measured/rights-cleared *staging candidates after review* only; provider-derived durable catalog coordinates and production seed publication blocked. See 0002. |
| Backend region, transfer/backup and monthly staff/infrastructure envelope | Engineering + privacy; product + operations | Protocols, local fixtures and disposable local tests allowed; live project/persistence and public writes blocked. See 0003. |
| Boundary/timezone/source licenses and retention/SLA | Content + legal; privacy + safety | Typed schema and test fixtures allowed; ingestion, legal promises and service-level commitments blocked. |

**M0 gate status: blocked on actual decision/signature evidence.** Engineering documentation and the original baseline check are available, but none of the above rows is marked approved. This does not block M1–M2 reversible synthetic work.

## 2026-10-13 product decision — dedicated Map tab and synthetic media

- **Decision (product owner, in-session request):** add a fifth **Map** destination beside Explore, Featured, Saved and Profile, superseding “four tabs” and the “no duplicated Map/Explore tabs” consequence above. Mitigation for query drift: Map reads Explore's single shared filter query; its viewport affects only map display until the user explicitly commits it with “List places in this area”. Map markers load automatically for the visible viewport (display only); the list area never changes without that commit.
- **Implemented locally with synthetic data only:** MKMapView rendering with Apple POIs excluded, world-scale aggregate cells, native clustering, photo markers and a preview card; no location prompt, no provider search, no persisted provider coordinates. Coordinate-rights (0002) and all other gates above remain **open**.
- **Media:** `MediaAsset` now carries a source and a synthetic flag; public places expose only rights-cleared media approved for their own record. Fixture images are generated abstract patterns (`scripts/generate-synthetic-media.py`), labelled SYNTHETIC with alt text, never photographs of a place. Real uploads still require contributor rights evidence, EXIF/GPS stripping, human review and a provisioned backend; none exists.


## 2026-10-13 product decision — community features and Supabase

The product owner supplied nine acceptance criteria and chose the iOS app with a real Supabase backend now. This **supersedes** for MVP: "no ratings/points" (criterion 4 adds 1–5 star ratings with average and count; still no leaderboards or paid ranking) and "public submissions blocked" (criteria 2–3 add member submissions with a map pin, moderator approval and visible decisions). Implemented: accounts (email + password), submissions forced to `pending`, a moderator queue with no self-approval, ratings, reviews, likes, follows, reports to moderators, and like-based recommendations. Schema and RLS are in `supabase/migrations`; setup and the adversarial RLS check are in `supabase/README.md`.

Still open and **not** satisfied by this change: legal determination on member-authored pin coordinates (0002), named moderators/languages and escalation, age policy, account deletion, blocking, rate limiting, email verification and region/cost choices for the owner's project (0003). The owner provisions the project; no service-role key is used by the app or scripts.
