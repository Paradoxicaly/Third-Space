# Repository guidance

## Scope and precedence

Third Spaces is moving toward a native, worldwide-capable iOS community field guide. The current iOS app is an earlier mock-data concept, **not** the completed product. `web/` is a separate visual prototype; obey `web/AGENTS.md` when working there. Do not migrate web motion or fabricated place content into the native catalog. Read `ARCHITECTURE.md`, `DESIGN.md`, the three `docs/decisions/` records and `docs/qa/native-acceptance.md` before native feature changes. Decision records contain **open gates**, not release authorization.

## Contribution boundaries

- Preserve unrelated dirty work; inspect `git status --short` and the diff before edits. Do not stash/reset/commit/push/deploy without explicit authorization. Keep changes within the assigned files and milestone.
- iOS 18 remains the minimum; iPad is an MVP target, not current project capability. Use native SwiftUI, system typography, Dynamic Type, accessibility, MapKit for rendering, an ephemeral Apple geographic search adapter and a separate owned-place repository. No Google/Mapbox/MapLibre dependency by default.
- Public map/list/detail show only approved, rights-cleared own records. Provider results are transient navigation aids, **not** catalog content. No durable Apple/provider geocodes, selected POIs, dropped-pin coordinates or map-derived catalog records while coordinate-rights review remains open. Only synthetic local test data may exercise pin placement until an approved independently sourced workflow exists. Never turn existing mock locations, ratings, images or claims into production seeds.
- Use explicit permission-free worldwide area browsing; no default Carson or location prompt, no fabricated nearby/open/accessibility claims. Manual list must remain useful if map/provider/location fails. Public submissions require human review, source/rights evidence and regional staffing; no client moderation bypass or privileged key in app.
- Protect sensitive geometry and descendants (posts/media/links/translations/collections), and do not cache provider payloads or exact sensitive locations. Server checks all grants, public revisions and account status. Account deletion and UGC safety flows are release requirements, not existing behavior.
- Use `DESIGN.md` semantic colors, not brand greens for small text or labelled fills. Check unrounded color pairs with `python3 scripts/verify-design-contrast.py`, then native rendered light/dark/assistive-tech behavior separately. Static ratios do not prove native accessibility.

## Verification and truthfulness

Report commands, real exit status and test counts. Before changing Xcode configuration, inspect installed destinations and capture an unsigned baseline build; no successful build or tests are implied by these docs. Create failing tests before implementation in later milestones and inspect `.xcresult` for nonzero executed tests. Use synthetic fixtures only; staging or production persistence, provider coverage, legal rights, regional launch and store distribution each require the separately documented gate. `docs/qa/native-acceptance.md` is a checklist, not a completed QA report. Do not claim a feature or release is approved from a green static contrast script.
