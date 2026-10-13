# Third Spaces native architecture (target and local implementation boundary)

**Status (2026-10-10):** the local synthetic M1/M2 native shell/domain/repository/list integration is implemented and freshly automated-verified, **not accepted or release-ready**. Current-tree unsigned Debug/Release builds exit 0; complete iPhone/iPad simulator suites each execute 62 unit + 13 UI tests, 0 failures/skips; selected Release contracts/exclusion/race/recovery execute 31 tests, 0 failures/skips. Saved-restoration races and unreadable-query overwrite were reproduced before repair. The earlier `Color.thirdCream` compile failure below is historical and repaired. Required manual accessibility, real multitasking and physical-device acceptance remain open; M0 human/legal/operational gates remain open. See `docs/qa/m1-m2-implementation.md` for the single scoped acceptance checklist, exact commands and result artifacts, and the three decision records for unresolved release gates. The diagram/services below remain the **target**, not existing live adapters/backend.

```text
SwiftUI screens / @MainActor view models (Explore, Featured, Saved, Profile)
  ├─ owned Place/Community/Submission/Saved/Featured/Profile repositories
  ├─ Session/Moderation/Media/AccountLifecycle services
  ├─ GeographicSearchProvider (ephemeral Apple region/address results)
  ├─ LocationService (when-in-use, on explicit request)
  └─ MapRenderer (MKMapView, display and native annotation clustering only)
         ↓ typed redacted own-data queries / pending commands
Supabase Auth + PostgreSQL/PostGIS (proposed; not provisioned here)
  ├─ approved public projections, area index and aggregate map cells
  ├─ immutable revisions, transactional human publication and audit/outbox
  ├─ private geometry, reports, rights evidence and quarantine storage
  └─ deletion, expiry, derivative and cache-invalidation jobs
```

## Geographic and domain contract

- Map rendering, Apple geographic lookup, Core Location and owned place search are separate. `MKMapItem`/Apple search results live only for provider presentation; a selection is never an approved `Place`, cached offline catalog or durable source. Apple result presentation must retain the corresponding Apple map and unobscured attribution; list-only/offline fallback uses only owned catalog/index. Legal review of durable dropped-pin coordinates is **open**; synthetic local pin exercises are allowed, provider-derived public persistence is not.
- Initial state: world/region choice and city/area search without permission or automatic Carson center. Panning changes viewport; user commits “Search this area.” Use WGS84 valid latitude/normalized longitude, split antimeridian bounds, support large/rural regions and no-coverage states. Map at world scale shows aggregate approved cells; zoomed map is capped/clustered; cursor-paged list always returns real approved places, not cluster objects.
- A shared normalized `query_id` identifies bounds/region, text, intent/practical filters and sort; map/list share publication watermark and selection state. Ignore superseded responses, label retained old results and refresh invalid cursors. Do not represent a capped map or 30-row page as complete results. Typed facts retain source/date/unknown; formatted distance, rating and evergreen `isOpen` are not persistent domain fields.
- Screen tabs are Explore (list), Map, Featured, Saved, Profile (Map tab: product decision 2026-10-13, see 0001); Contribute is a persistent labelled action. Map and Explore share one `ExploreViewModel` query for filters; the map viewport replaces the area only for map display until the user chooses “List places in this area”. Guest browsing works without auth. Offline cache contains only eligible redacted owned snapshots and own drafts/saves; no provider search payloads or sensitive place descendants. Tombstones and publication revisions invalidate stale content on reconnect; disconnected copies cannot be recalled instantly.

## Trust and security contract

- Public data is approved current-revision, provenance/rights checked and sensitivity-redacted. Child rows, media, counts, translations, region labels and Featured snapshots inherit parent visibility. Pending edits never mutate current public facts. Private exact geometry/evidence/contact is isolated from exposed schemas; public query/cluster/distance cannot infer it.
- Server derives author, operational moderation scope and status; verifies live account status, region/language grant and MFA for staff, forbids self-approval and requires two distinct reviewers for sensitive publication. A publication transaction links approved revision/media/facts, audit and invalidation. RLS/storage grants and raw REST/RPC paths need adversarial tests; hiding a UI button is not authorization. Service-role credentials never enter the client.
- Region labels are not grants. Regions without staffed language/safety review may allow browsing/local drafts but not remote publication. Safety intake must include an accountless protected route, reports/blocks and a visible contact; deletion revokes sessions immediately and tracks server-side purge separately from backup/offline expiry.

## Sequence and evidence

M0 documents decisions and open gates; M1 adds the native test harness/design shell; M2–M4 implement synthetic local vertical slices; M5+ add the audited backend and operations only as gates resolve. This file is not evidence of a working adapter, database, provider coverage, release build or rights clearance. Run the exact native/backend verification commands in the implementation plan when their targets exist; record device, Xcode, result bundle and executed test counts in `docs/qa/native-acceptance.md`.

## M0 baseline evidence (2026-10-09)

- `xcodebuild -version`: Xcode 26.6 (17F113). Before test-target edits, `xcodebuild -list -project ThirdSpace.xcodeproj` showed a single app target and `ThirdSpace` scheme; installed iOS 26.5 iPhone/iPad simulators were listed. The native project had no package dependencies at baseline.
- The exact C1 unsigned command from the implementation plan was executed **before** native source/project edits and returned exit **0**, `BUILD SUCCEEDED`. Only reported warning: `appintentsmetadataprocessor` skipped metadata extraction because no AppIntents.framework dependency was found. This is a simulator compile, not executed tests, device QA or release signing.
- An independent clean-HEAD reproduction extracted only committed `ThirdSpace.xcodeproj` and `ThirdSpace/` into `/tmp/third-spaces-m0-head` (no checkout/reset and no dirty-work changes). Running C1 there with `-derivedDataPath /tmp/third-spaces-m0-head-derived` returned exit **0**, `BUILD SUCCEEDED`, with the same App Intents warning. Log: `/tmp/third-spaces-m0-head-build.log` (local, not committed).
- The **historical 2026-10-09 in-progress worktree** was also built with C1; it returned exit **65**, `BUILD FAILED`, at `ThirdSpace/Views/SavedPlacesView.swift:13:23: type 'Color' has no member 'thirdCream'`. That later M1/M2 integration failure is now repaired; do not conflate its historical failure with the successful clean-source M0 baseline or the fresh 2026-10-10 receiving-tree evidence above. No XCTest count was produced by C1.
