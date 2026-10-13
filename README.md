# Third Spaces

Third Spaces is a worldwide-capable native iOS community field guide for finding welcoming places beyond home, work, or school. Carson/South Bay is a proposed first **seed collection**, not a geographic limit. The eventual primary Explore experience is map-first; the current list-first slice provides the accessible, permission-free foundation.

## Current implementation boundary

`ThirdSpace/` is a local native prototype under active development. Its development fixtures are **synthetic**, never verified public places. There is no production catalog, backend, account, moderation, live location, geographic search or provider-derived durable coordinate store. No demo row may be shipped as a verified listing. An empty world/region is a truthful result.

`web/` remains a separate Next.js visual pilot with local example content and motion experiments; it is not the production native design or a data source. Its changes and deployment are independent of this iOS work.

## Run and verify iOS

Open `ThirdSpace.xcodeproj` in Xcode 26.6 or compatible and run the shared `ThirdSpace` scheme on an installed iOS 18+ simulator. Debug UI fixtures require `--ui-testing`; ordinary launches do not silently fall back to samples. For a signing-free build:

```sh
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/third-spaces-ios-derived CODE_SIGNING_ALLOWED=NO build
```

Set `IOS_SIMULATOR_ID` to an installed simulator UDID (`xcrun simctl list devices available`) and run the native tests:

```sh
xcodebuild -project ThirdSpace.xcodeproj -scheme ThirdSpace \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath /tmp/third-spaces-ios-derived CODE_SIGNING_ALLOWED=NO test
python3 scripts/verify-design-contrast.py
```

See `DEVELOPMENT.md`, `ARCHITECTURE.md`, `DESIGN.md`, and `docs/decisions/` for boundaries and open gates. No release/archive claim follows from an unsigned simulator build.

## Web visual pilot (separate)

Requires Node.js 20+ and npm. In `web/`, run `npm install`, `npm run dev`, `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build`. Browser tests: `npm run test:e2e`. See `web/THIRD_PARTY_NOTICES.md` and `web/public/places/README.md` for notices and prototype imagery. Nothing in the web pilot verifies actual places.

## Release gates

Provider coordinate/pin-placement rights, signing/domain ownership, backend region/data transfers, moderation staffing and languages, age policy, budget, regional distribution, content/photo rights, safety and privacy operations all remain open. No accounts, paid resources, publication or production place import are authorized by the local prototype. See the decision records for owners and blocked dependencies.
