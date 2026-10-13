# M1–M2 local implementation acceptance

M0 human/legal/operational gate remains **open**. This checklist covers only the explicitly authorized reversible local synthetic scope. No live provider, backend, seed import or release approval.

## Initial reconciliation (2026-10-09)

| Criterion (plan §9) | Initial state | Evidence / exact gap |
| --- | --- | --- |
| M1 unit/UI targets and shared scheme | Implemented but unverified | Targets and shared scheme exist; no final current-tree count. |
| M1 deterministic `--ui-testing` injection; no release fallback | Missing composition | Mock adapter exists but app still uses `PlaceStore`; compile-only release guard missing. |
| M1 exact primitives/semantic light-dark colors/contrast | Implemented but unverified | Token file/contrast verifier exist; old view references fail compile. |
| M1 scalable text and minimum targets | Partial/unverified | Old card clips metadata and tiny save target; runtime AX checks missing. |
| M1 iOS 18/device families/assets/icon/string catalog | Partial/unverified | Family 1,2 and catalog present; icon absent, device runtime checks missing. |
| M1 four destinations/Explore list/Contribute action | Partial/unverified | Sidebar selection initializer failed iOS compile after token errors; list action absent. |
| M1 compact/regular iPad and largest AX shell | Unverified | No final simulator/layout evidence. |
| M1 C2/C3/contrast/screenshots/VoiceOver gate | Missing | Current native test evidence and manual VoiceOver not recorded. |
| M2 stable IDs/unknown access-hours/scripts/bounds/filter/cursor/cache invalidation/cold-offline tests | Implemented but unverified | Existing tests need actual XCTest run and audit. |
| M2 typed facts/provenance rather than distance/rating/open | Partial | Temporary legacy accessors and views still remain. |
| M2 injected local saves; single extracted PlaceCard | Missing | In-memory PlaceStore still wired; PlaceCard nested in Explore. |
| M2 repository-driven list/detail/save with loading/empty/error/cache | Missing | Explore uses empty legacy Place.examples, no state model. |
| M2 deterministic multi-latitude/script/timezone synthetic fixtures | Partial | Stable fixtures exist; facts/timezones and explicit composition missing. |
| M2 protected local saves/drafts/query restore and cold relaunch | Partial/unverified | Actors exist but UI does not use them; query persistence missing. |
| M2 no production view reaches Place.examples | Missing | Explore/Saved still call it. |
| M2 permission-free complete list journey and freshness gate | Missing | No functioning integrated journey yet. |

## Reproduced regression and root cause

Current-worktree C1 returned exit 65 at `SavedPlacesView.swift:13`, `Color.thirdCream` missing (`/tmp/third-spaces-resume-red.log`). `DesignSystem.swift` is a synchronized app-target file, compiled by Xcode; this is **not** missing target membership. Its old Color extension was replaced by `FieldGuide.Palette`, but Explore/Saved/detail still referenced removed tokens, removed rating/amenity views, raw brand text and fixed open claims. Migrating those sibling paths to semantic tokens uncovered an independent `NavigationSplitView` List selection binding error. Optional iOS selection corrected that. Current C1 subsequently returned exit 0 (`/tmp/third-spaces-build-restored.log`); this is compile restoration, not M1/M2 acceptance.

## Current acceptance checklist — guided M1/M2 (2026-10-12)

This is the **single active acceptance checklist**. Initial reconciliation above is historical. Integration owner: Hermes. The independent review was source-only, with no executed tests; RED/GREEN results were subsequently executed in this receiving worktree. D1/D2/R1 below are the frozen 2026-10-10 tree. Guided acceptance found and repaired G1 (two prompt-only native changes, one UI-test file); fresh serial **77 tests per iPhone/iPad (62 unit + 15 UI), Release build and 31 selected Release tests all passed**, zero failures/skips, all exits 0, 60-file freeze unchanged. Latest evidence is `repair-verification.json` and fresh bundles in the guided archive. M0 OPEN; M1/M2 implemented and automated-verified, **NOT ACCEPTED** while remaining checks are open/blocked.

| Criterion | Current evidence/status |
|---|---|
| Review A: withdrawal during suspended saved fallback | **Reproduced, fixed, verified.** RED: 1 executed test, 1 failed test, exit 65. Focused GREEN: 11 tests, 0 failures, exit 0. Controlled continuation invalidates during fallback; asserts no publication or recache. Post-lookup check plus synchronous lock-shared publication policy closes the final actor-hop gap; an additional test invalidates after an earlier eligibility read. Passed final D1/D2/R1. |
| Review B: older restoration overwrites newer unsave | **Reproduced, fixed, verified.** RED: 2 tests, 1 failed test, exit 65. Focused GREEN: 5 tests, 0 failures, exit 0. Controlled continuation completes the old lookup after the newer unsave settles; asserts saved places, in-memory IDs and durable IDs remain unsaved. Generation invalidated before mutation awaits and checked at late publication/error boundaries. Passed D1/D2/R1. |
| Review C: unreadable query overwritten automatically | **Reproduced, fixed, verified.** RED: 4 tests, 3 failed tests / 9 assertion failures, exit 65; missing-file case passed. Eight final unit regressions distinguish missing, malformed, incompatible and read-failed data; preserve bytes across refresh/query changes; exercise retry, explicit reset, failed reset and restored readable data. Browsing is temporary until restoration/recovery succeeds. Visible warning + retry + confirmation-gated query-only reset; UI checks cancel, retry, confirm and relaunch. Passed D1/D2/R1; recovery UI passed D1/D2. Isolated temporary/test storage only. |
| Prior iPhone/iPad East-area / Arabic Open failure | **Resolved; D1/D2 passed.** Failure hierarchy contained FSI/PDI controls added by native bidi interpolation, although screenshot showed the correct original Arabic name. Stable record-ID selector added without changing or discarding the accessible name; test still asserts the full name after removing only native FSI/PDI controls. Navigation, cost and unknown hours asserted. |
| Prior iPad Load more not reachable | **Resolved; D2 passed, also D1.** Old helper selected the sidebar CollectionView (not the results pane). Results ScrollView now has a stable identifier; gestures target it and constrain reachable frames below navigation and above fixed contribution/tab/keyboard chrome. Actual pagination, totals and original Nepali row remain asserted; no assertion removed, skipped or delayed to pass. |
| Additional Hours assertion exposed after Arabic navigation repair | **Resolved; D1/D2 passed.** Focused iPhone run reached detail then failed a nonexistent exact short label `Hours unknown`; source and recording showed `Hours unknown — check before visiting`. Full truthful label now asserted. That intermediate bundle failed overall (exit 65); its 62 unit tests passed. It does not certify the final tree. |
| M1: real test targets/shared scheme, minimum iOS 18, families 1/2, assets/icon/catalog | **Implemented / automated evidence passed.** D1/D2 execute both targets; Debug and Release unsigned builds exit 0. Project and built Info validated; three asset JSON files valid; actual icon PNG 1024×1024. Tests ran on iOS 26.5, not an iOS 18 runtime. |
| M1: exact primitives, semantic light/dark/high-contrast tokens, scalable typography / minimum owned targets | **Implemented; G1 repaired and fresh complete verification passed.** Static 46 pairs missed UIKit placeholder opacity (search/draft 1.73/1.72:1). Semantic prompt styling passes 2 rendered regressions; fresh light/default search screenshot now measures **6.3054934705917658:1**. Real OS matrix captured 28 initial Explore views, not all screens/scrolling; full composited/text-size/human matrix remains OPEN. |
| M1: Explore/Featured/Saved/Profile, list action, persistent Contribute; adaptive regular/compact, rotation | **Implemented / D1/D2 passed.** Three shell journeys on each simulator include portrait/landscape and AX-largest dark/RTL forced compact. Source/data have no seed/sign-in dependency. Forced compact does not certify real Split View or Stage Manager. |
| M1: manual VoiceOver/focus/announcements, Switch Control/Voice Control, hardware keyboard | **OPEN — unperformed.** Human checks must include the new restoration warning, retry and reset confirmation, results focus, detail/back and draft feedback. No spoken-feedback certification. |
| M1: rendered system Increased Contrast, Reduce Transparency/Reduce Motion, grayscale/color-vision matrix | **OPEN — unperformed manual matrix.** Trait-resolved token units and screenshots are narrower evidence. |
| M1: actual compact iPad multitasking; physical/smallest/minimum-OS devices | **OPEN.** No physical device or real iPad Split View/Stage Manager; no smallest-phone or iOS 18 runtime acceptance. |
| M2: immutable/wire IDs, original scripts, typed unknown/fact/source/date/bounds/filter/query/cursor contracts | **Implemented / D1/D2 unit suites passed; selected contracts R1 passed.** No distance/rating/evergreen-open production claims or direct legacy sample path. |
| M2: owned repositories, normal fail-closed composition and DEBUG-only region/place/error fixtures | **Implemented / D1/D2/R1 passed.** Release checks ignore testing/scenario/malformed-query flags and exclude sample records/regions. No live map/provider/backend adapter is activated. |
| M2: generation/cursor coherence, TTL/tombstones, sensitive descendants, non-destructive file failures | **Implemented / D1/D2 passed; new races/recovery R1 passed.** Same synchronous publication policy applied to live, paged and cached Explore paths. No provider DTO cache. This is local policy evidence, not future server/RLS or immediate disconnected-erasure acceptance. |
| M2: permission-free loading/search/filter/manual area/world paging/list/detail/save/draft/query/cold relaunch | **Implemented / D1/D2 complete UI suites passed.** Includes loading/supersession, empty vs filtered empty, cold/warm offline, dated cache vs outage, retry, relaunch and deliberate query recovery. No provider/location/network needed. |
| Current-tree freeze and project/plist/scheme/contrast/diff/web integrity | **Passed post-G1 freeze: 60 native/project/test files, `source_changed=[]`.** Historical preflight 59-file match and plist/scheme/protected-web checks retained separately. Fresh current built Info iOS 18 / families 1,2; current contrast/diff exits 0. No delegated writer, staging, commit, push, deployment or web edits. Final protected-path audit remains to record at guided closure. |
| M0 legal/coordinate rights, age, staffing/languages, region/transfer, budget, signing/domain/distribution | **OPEN, unchanged.** No legal clearance, live catalog, service provisioning, production persistence or release approval. |
| Final milestone status | **M0 OPEN; M1/M2 implemented + post-G1 automated-verified, NOT ACCEPTED.** Basic sighted navigation/save/unsave human observations recorded below, not spoken-feedback or full acceptance. Remaining checks explicit; M3+ untouched. |

## Final executed evidence

Verification ran serially 2026-10-10 20:52:54–21:01:00 America/Los_Angeles, Xcode 26.6 (17F113), unsigned arm64 iOS Simulator 26.5 (23F77). Default/light and synthetic forced dark/AX-largest/RTL scenarios were exercised. Original Arabic/Nepali text is tested; this is not a complete translated-localization audit. There were no simultaneous Debug/Release installations on one simulator.

| ID | Run | Exit | Non-overlapping tests within this run | Failures / skips | Original artifact |
|---|---|---|---|---|---|
| B1 | Current-tree unsigned Debug build | 0 | Build only | N/A | `/tmp/third-spaces-resume-final-debug-build.log` |
| D1 | iPhone 17 complete Debug | 0 | 62 unit + 13 UI = 75 | 0 / 0 | `/tmp/third-spaces-resume-final-iphone.xcresult` |
| D2 | iPad Pro 13-inch (M5) complete Debug | 0 | 62 unit + 13 UI = 75 | 0 / 0 | `/tmp/third-spaces-resume-final-ipad.xcresult` |
| B2 | Unsigned Release build | 0 | Build only | N/A | `/tmp/third-spaces-resume-final-release-build.log` |
| R1 | Selected Release contracts/composition/query/race/recovery | 0 | 31 unit, selected suites only | 0 / 0 | `/tmp/third-spaces-resume-final-release.xcresult` |
| S1 | Static design contrast | 0 | 46 pairs, not XCTest | 0 failed pairs | `/tmp/third-spaces-resume-final-contrast.log` |
| S2 | Project plist validation | 0 | Not tests | N/A | `/tmp/third-spaces-resume-final-plist.log` |
| S3 | Diff whitespace check | 0 | Not tests | N/A | `/tmp/third-spaces-resume-final-diff-check.log` |

`xcresulttool get test-results summary` and `tests` were extracted successfully for D1/D2/R1. Test trees independently confirm 62 unit/13 UI and 31 selected Release leaves, all Passed. No overlapping device/configuration/focused totals are summed as unique tests. Release used `ENABLE_TESTABILITY=YES` for engineering assertions, not archive/distribution signing.

### Durable local artifacts and screenshot audit

The originals above remain available. Hash-verified copies of 33 artifact files/directories (final `.xcresult` bundles, raw summaries/test trees, exact-command/exit/freeze manifest and runner, final logs, RED/focused bundles and both screenshot/hierarchy export folders) are retained under project-relative `.hermes/qa/2026-10-10-m1-m2-restoration-fixes/`, ignored by git. `artifact-index.json` maps original to archived paths with verified SHA-256. `third-spaces-resume-verification.json` preserves exact executed commands, exits, actual result summaries and before/after source hashes; it is not fabricated output.

Export folders: `third-spaces-resume-final-iphone-attachments/` and `third-spaces-resume-final-ipad-attachments/` under that archive. Each contains a manifest, screenshots and accessibility hierarchies. Inspected final iPhone/iPad Arabic detail, iPad six-place pagination/Nepali script, iPhone actionable unreadable-query warning and both dark RTL largest-text shells. Inspected the old failure screenshots/hierarchies and the intermediate Hours failure recording before selector fixes. Original script/facts are readable in those captures; fixed chrome remains distinct from the scrolling content. This limited screenshot audit does **not** prove VoiceOver, every text size/screen, composited contrast or real multitasking.

### Exact final commands (executed from repository root)

```sh
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/third-spaces-ios-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Debug -destination 'platform=iOS Simulator,id=88265712-79D2-4A75-8CA4-FBC0E9A7AB22' -derivedDataPath /tmp/third-spaces-ios-derived CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -resultBundlePath /tmp/third-spaces-resume-final-iphone.xcresult test
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Debug -destination 'platform=iOS Simulator,id=21AD6D22-45C7-40BB-A80F-EAA3EA336745' -derivedDataPath /tmp/third-spaces-resume-ipad-derived CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -resultBundlePath /tmp/third-spaces-resume-final-ipad.xcresult test
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/third-spaces-release-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Release -destination 'platform=iOS Simulator,id=21AD6D22-45C7-40BB-A80F-EAA3EA336745' -derivedDataPath /tmp/third-spaces-release-derived CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES -parallel-testing-enabled NO -only-testing:ThirdSpaceTests/DomainModelTests -only-testing:ThirdSpaceTests/RepositoryContractTests -only-testing:ThirdSpaceTests/AppEnvironmentTests -only-testing:ThirdSpaceTests/ExploreQueryTests -only-testing:ThirdSpaceTests/QueryRestorationTests -only-testing:ThirdSpaceTests/SavedRestorationRaceTests -resultBundlePath /tmp/third-spaces-resume-final-release.xcresult test
python3 scripts/verify-design-contrast.py
plutil -lint ThirdSpace.xcodeproj/project.pbxproj
git diff --check
```

All eight commands exited 0. For each final result bundle, the actual extraction commands were `xcrun xcresulttool get test-results summary --path <bundle> --format json` and `xcrun xcresulttool get test-results tests --path <bundle> --format json`, both exit 0; exported JSON is archived. Attachment export was `xcrun xcresulttool export attachments --path <bundle> --output-path <export-folder>` for D1/D2, exit 0. Use fresh result paths for a rerun; never reuse a bundle or infer fresh results from this record.

### Historical RED / focused execution (not final acceptance totals)

The exact invocation is recorded at line 2 of each matching `third-spaces-resume-{A-red,A-green,B-red,B-green,C-red}.log` in the archive. All used Debug, iPhone UDID above, `/tmp/third-spaces-ios-derived`, unsigned/nonparallel `xcodebuild test`; selectors and result paths were:

| Run | `-only-testing:ThirdSpaceTests/…` suites | `-resultBundlePath` | Exit / executed / failed tests / skips |
|---|---|---|---|
| A RED | `SavedRestorationRaceTests` | `/tmp/third-spaces-resume-A-red.xcresult` | 65 / 1 / 1 / 0 |
| A focused GREEN | Race/cache/composition suites (exact log invocation) | `/tmp/third-spaces-resume-A-green.xcresult` | 0 / 11 / 0 / 0 |
| B RED | `SavedRestorationRaceTests` | `/tmp/third-spaces-resume-B-red.xcresult` | 65 / 2 / 1 / 0 |
| B focused GREEN | `SavedRestorationRaceTests`, `AppEnvironmentTests` | `/tmp/third-spaces-resume-B-green.xcresult` | 0 / 5 / 0 / 0 |
| C RED | `QueryRestorationTests` | `/tmp/third-spaces-resume-C-red.xcresult` | 65 / 4 / 3 / 0 (9 failed assertions) |
| Intermediate focused iPhone | Complete unit target plus paging/Arabic/query-recovery UI | `/tmp/third-spaces-resume-focused-iphone.xcresult` | 65 / 65 / 1 / 0; all 62 units and two UI cases passed; Hours-label assertion failed |

These genuine RED failures are not the review's verdict and are not marked expected/skipped. D1/D2/R1 supersede the intermediate changed trees. Recovery's eight tests and three race/publication tests are present and Passed in the final test trees.

### Worktree preservation and remaining actions

Final branch: `feat/third-spaces-web-pilot`, still tracking its original upstream. Git reports **15 unstaged modified tracked entries and 29 untracked entries** (some entries are directories, not file counts); no staged changes. Unrelated native/document changes preserved. No web edits, checkout/reset/stash/stage/commit/push/deploy. Original protected hashes still match:

| Protected file | SHA-256 |
|---|---|
| `web/next.config.ts` | `27b3d7ae584c5e7e73f61567b2bb5725e6c046912bb37392b9169d5ce176aeae` |
| `web/src/components/landing/LivingCityPage.tsx` | `ffa901f8fd63c34ee4b3a2d820c2a03caa75141045ae5c28f38f53fdbf1a0f1c` |
| `web/public/.nojekyll` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Next actions: assigned human QA must exercise VoiceOver/focus/announcements and recovery, other assistive modes/hardware keyboard, composited/system-setting contrast/transparency/motion and full text-size/screen matrix, actual iPad multitasking and physical/minimum-OS/small-screen devices. Record defects and rerun affected tests **and complete relevant suites** after any source/test fix. Separately, named owners must resolve M0 legal/rights/age/operational/signing/distribution gates before live or release work. No M3+ work is authorized by these results.

## Guided acceptance execution — 2026-10-12 (in progress)

This section records execution against the **same active scoped checklist above**, not a second acceptance checklist or the full future-product matrix. Map clustering/tiles/provider attribution, backend moderation/RLS, live media, account deletion and release operations are **OUTSIDE M1/M2 scope**, not passed. VoiceOver checks apply to the implemented shell/list/detail/local-save/recovery/draft paths only; future map/form/community controls are excluded.

**Preflight:** all 59 current native/project/test files match the durable 2026-10-10 verification manifest, with no additions/removals. Existing complete-suite evidence remains valid; no passing suite repeated before work. Branch/status unchanged (15 unstaged modified tracked / 29 untracked entries; preserved unrelated web changes, not newly edited). Xcode 26.6; installed runtimes iOS 17.4 and 26.5 only. `devicectl list devices`: no devices. User reports **Mac/simulators only** and explicitly permits temporary changes/restoration **only in the new isolated simulator**, not Mac or physical-device accessibility settings. No runtime download, signing change or device install authorized.

**Prepared state:** fresh `Third Spaces M1M2 Acceptance SE3`, iPhone SE (3rd generation), iOS 26.5 / 23F77, UDID `2D631155-1FD9-4C7A-8F94-2B194CEE7B05`. Existing verified unsigned Debug app installed and launched with only `--ui-testing`; no forced trait overrides, no reset flag, no real app data touched. Baseline actual simulator settings: light / content size `large` / Increase Contrast disabled. Native framebuffer screenshot 750×1334. Evidence root `.hermes/qa/2026-10-12-guided-m1-m2/`; exact settings/commands/exits/source-check are in `environment-baseline.json`.

| Remaining check | Execution class and present status | Procedure / evidence / boundary |
|---|---|---|
| Real light/dark, 12 Dynamic Type categories, Increase Contrast | **1 Agent-executed; 28 captures complete, full criterion OPEN** | `display-matrix-settings.json` records actual settings/commands, 24 light/dark × 12-size initial Explore views plus 4 high-contrast default/largest views. Contact sheets inspected. Baseline light/large/disabled readback restored. Before prompt repair; later actual rendering must be rechecked. No forced traits. Scroll-content fold clipping is not automatically a layout failure; below-fold reachability remains to check. |
| Implemented Explore/detail/Saved/Featured/Profile/draft/recovery across sizes; scroll/keyboard/footer/rotation | **1 capture/measurement + 2 human UI interaction; OPEN** | Agent can capture actual framebuffer and render/settings evidence. Current host automation process reports `AX_TRUSTED=false`; no permission granted/changed. User can interact with the isolated simulator, one prepared short check at a time. |
| Small-screen initial Explore/default size | **PASS for this initial rendered view only** | SE3 baseline screenshot `SE3-baseline-explore-light-large.png`: synthetic disclaimer, search/area/filter/list controls and fixed Contribute/four destinations visible without observed clipping. Results below fold; scrolling/hittability and all other sizes/screens NOT certified. |
| Actual Reduce Motion / Reduce Transparency | **2 human settings interaction + agent capture; OPEN** | `simctl ui` exposes no setter for these. Check native simulator Settings availability, record toggles/readback and observations; restore originals. No unsupported preference injection or Mac setting changes. |
| iOS VoiceOver / Voice Control / Switch Control | **VoiceOver 3 BLOCKED in available environment; other native capability checks OPEN** | After ambiguity clarified, user explicitly observed no row named VoiceOver in simulator Accessibility. Captured preceding screen showed Live Speech Off, not VoiceOver; neither Live Speech/Spoken Content nor Mac VoiceOver/AX audit substitutes for iOS VoiceOver. No physical device available. Voice Control/Switch Control not independently exercised or passed. |
| Save/unsave feedback, recovery warning/retry/reset/cancel, draft feedback | **2 human observation; OPEN** | Prepare isolated synthetic state and ask one procedure at a time; automated assertions remain supporting evidence, not invented human observations. |
| Hardware-keyboard navigation and actual iPadOS simulator windowing | **2 human interaction/capability check; OPEN** | Determine available simulator routing/windowing before claiming coverage; never equate forced compact with actual multitasking or a Mac keyboard session with physical iPad acceptance. |
| Physical iPhone/iPad and physical iPad multitasking/assistive modes | **3 BLOCKED** | No connected device; user has Mac/simulators only. Smallest practical unblock: access a compatible test device and obtain separate permission for signing/install; no registration or install performed. |
| Minimum iOS 18 runtime | **3 BLOCKED** | iOS 18 not installed; 17.4 is below deployment minimum and not a substitute. Obtain user approval before downloading an available iOS 18 runtime or arranging an iOS 18 device; minimum remains 18. |
| Full composited contrast / color-vision / all-screen matrix | **1 targeted pixel/render inspection + 2 human assessment; OPEN** | Actual screenshot evidence, not 46 static hex pairs or OCR alone. Limited views do not pass the entire matrix. |

### Defect G1 — composited editable-input prompt contrast

- Procedure: existing verified Debug, fresh SE3 / iOS 26.5, actual light / `large` / Increase Contrast disabled; empty Explore search. Decode actual screenshot in sRGB and sample field interior, excluding border/other controls. Background `#FFFDF7`, repeated core glyph `#C5C3C1`, unrounded ratio **1.7276084051289091**; evidence `search-placeholder-rendered-contrast.json` and baseline screenshot. Root cause: default SwiftUI/UIKit placeholder style rather than existing semantic role. This was not caught by static token pairs.
- Search RED: new `RenderedInputContrastTests/testEmptySearchPromptHasReadableRenderedContrast`, **1 executed/1 failed**, exit **65**, same ratio in `.xcresult` assertion; `search-prompt-red.xcresult`. Search prompt alone styled with `FieldGuide.Palette.secondary`; focused **1/1**, exit **0**, `search-prompt-green.xcresult`.
- Sibling draft input then reproduced separately before its fix: **2 tests / 1 failure**, exit **65** (`draft-prompt-red.xcresult`); draft ratio **1.7233924684533595**, search remained green. Existing draft prompt styled with same semantic role. No token/labels/layout/business logic change or refactor. Final focused **2 tests, 0 failures/skips, exit 0**, `input-prompts-green.xcresult`, with full screenshot/hierarchy and composited pixel attachments.
- Minimal source changes: `ThirdSpace/Views/ExploreView.swift`, `ThirdSpace/Views/Contribution/ContributeMenu.swift`; new `ThirdSpaceUITests/RenderedInputContrastTests.swift`. Fresh serial complete Debug **iPhone 77/77; iPad 77/77 (62 unit + 15 UI each)**, unsigned Release build and **31/31 selected Release**, contrast **46/46**, diff: **all exit 0**, zero test failures/skips. Runner exited 0; **60-file before/after freeze unchanged**. Exact commands and fresh summary/test-case trees in `repair-verification.json`, `complete-{iphone,ipad}.xcresult`, `release-contracts.xcresult`. Rendered input regressions cover actual default-light cases; the all-screen real-dark/text-size matrix remains distinct and open. Earlier 2026-10-10 full bundles historical after edit. Relaunched repaired synthetic SE3; original transition frame retained as `SE3-post-boot-launch-transition.png` (not ready evidence); later verified `SE3-repaired-light-default.png` and readback light/large/disabled. Search prompt actual measured **6.3054934705917658**, `search-prompt-post-repair-rendered-contrast.json`.
- Human check preparation hit `simctl` shutdown-state exit **149**: Xcode shut down the acceptance SE3 while switching verification destinations. This is simulator lifecycle interference, not an executed product failure. No duplicate tests/repeated boots; wait for serial verification to finish before preparing the human app again. Host shell emitted unrelated conda plugin import warnings but the Python/Xcode runner started; test results must be read from actual bundles.

### Attributed human checks — isolated SE3 / iOS 26.5 / repaired Debug

Capture-tool verification (separate from app suites/human acceptance): OS-safe `hermes-verify-` tempfile executed **4 explicitly mocked checks** (settings/hash metadata, missing files, screenshot failure propagation, wrong-device container rejection) and **1 live read-only simulator capture**, exit **0**. Live PNG **750×1334**; actual settings and hashes of query/saves/drafts unchanged before/after; helper source unchanged. Temporary verifier and mock directories cleaned. Evidence `capture-helper-ad-hoc-verification.json`, `helper-adhoc-smoke.json`/PNG. This is **ad-hoc tooling verification**, not additional native suite green or a human recovery pass. Current query hash differs from the earlier deliberately malformed fixture outside this verification interval; no Reset/Retry action or success is inferred without the user's observation.

All observations below are the user's responses, not agent-generated behavior. Settings: actual light / `large` / Increase Contrast disabled. No VoiceOver substitute.

| Check / procedure | Observed result and evidence | Status |
|---|---|---|
| H1 sighted Explore → list → Reading Room → Back; observe controls/detail | User: “I think thats good. When I press save and everything it works.” Positive basic-flow report, not explicit confirmation of each requested label or spoken feedback. Agent screenshot `SE3-human-navigation-save-observation.png` corroborates Reading Room in Saved, private on-device explanation, dated snapshot and reachable-looking footer/tabs. | **PASS for reported basic sighted flow + visible saved state only**; exact-label/human VO criteria not inferred. |
| H2 unsave from detail, return to Saved; save again from other locations | User: “The save function completely works. I could save unsave they erase and dont erase and I could unseave from multiple different places it all is going great.” `SE3-human-unsave-observation.png`; subsequent synthetic saved file SHA corresponds to empty array (2 bytes). | **PASS — explicit sighted save/unsave/removal/multiple entry points**; spoken announcements untested. |
| H3a unreadable query warning and Retry | Agent launched **only** `--ui-testing --malformed-query` in isolated SE3, no reset flag. Debug code writes only `ThirdSpaces/SyntheticUITests/query.json`; saves/drafts not reset. Verified visible warning, Retry and Reset at default size. `query-warning-before-retry.json`/screenshot records device/settings and 34-byte query SHA before interaction. User asked where to find control; specific simulator/window and Explore warning location explained. | **PENDING — no retry observation yet**; no pass inferred. |

Photos requested as future product direction; noted, **outside this M1/M2 task**, no media/fabricated imagery added. Minimum-OS/physical/VoiceOver checks remain BLOCKED as above. All changed simulator display settings restored; Mac accessibility and real app data untouched. M0 OPEN; M1/M2 automated-verified, **NOT ACCEPTED**. Next prepared step: human Retry observation, then confirmation/Cancel/query-byte preservation, draft/keyboard, actual settings/windowing capabilities.
