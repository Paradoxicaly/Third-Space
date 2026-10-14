# 0002 — Map provider, transient search and coordinate provenance

**Status:** MapKit recommendation; durable pin/coordinate rights **open and blocking live persistence**. **Owners:** product/legal for accepted terms and pin rights; engineering for adapter/testing; regional partner for local map coverage.

## Decision boundary

Recommend native MapKit rendering (MKMapView for documented annotation clustering), Apple's `MKLocalSearch`/completion for **ephemeral geographic navigation**, and a separate, independently sourced PostGIS Third Spaces catalog. Apple search results and basemap POIs are not owned approved records. Show provider address results only with corresponding Apple map and required provider attribution; if map rendering fails, list-only mode uses owned catalog/region search and withholds detached Apple address details. Provider tiles, POI payloads, names and geocodes are not mirrored into shared DB, analytics, fixtures, logs or offline cache. Follow accepted contract and platform rules as revalidated before integration.

Public coordinate provenance must be recorded per field: `contributor_direct_measurement_with_consent`, `authorized_organization_source`, or `licensed_open_or_contract_source`, each with method/date/rights scope and approved review. These are **proposed source categories**, not a license grant. Apple dropped-pin interaction, chosen Apple POI or map-derived geocode does not by itself qualify as independent measurement. Unknown/uncleared provenance means no public coordinate. For approximate/sensitive places publish independently reviewed safe display geometry (or no public row), never a small offset from a secret point; prevent descendant, distance/cluster, photo, source-link and offline inference.

**Until written rights confirmation:** exercise only clearly synthetic local placement and draft previews; do not store provider-derived coordinates in a live shared catalog or enable publishing from pin selection. An alternative independently measured/rights-cleared input workflow may be staged after provenance and privacy review. No checkbox converts provider terms into ownership.

## Alternatives reviewed

Google Maps/Places adds billing/terms and prohibited-territory constraints; ordinary Places search does not grant shared permanent catalog rights or unrestricted non-Google-map display. Mapbox has POI coverage, storage and territory limits; a permanent-geocode product flag is not a shared database license. MapLibre requires separately licensed tiles, fonts, geocoder and OSM/ODbL analysis; public OSM tile/Nominatim endpoints are not a production worldwide search backend. Keep these as fallback candidates only after measured need, not installed just for optionality. See the authoritative planning record §8 for dated source URLs and detailed limitations; recheck **current accepted agreement** (including region/account terms), not old pricing summaries.

## Open gates / evidence required

1. **Product/legal:** review accepted Apple developer/map agreement and obtain written determination for the exact dropped-pin/user-authored coordinate workflow *before* live persistence. If denied/unclear, use independently licensed/measured sources and keep map as preview/navigation only.
2. **Engineering/legal:** define and enforce provenance schema and an Apple map/result/attribution presentation path, including list-only and map-failure behavior; adversarial tests prohibit provider-data caching/ingestion.
3. **Regional partner/product:** test map search, WGS84 marker alignment, labels, directions, attribution, low connectivity and provider terms per proposed distribution territory, especially mainland China. Never apply undocumented coordinate offsets or claim worldwide provider coverage from a simulator mock.
4. **Product/ops:** confirm actual provider quotas/usage/cost controls before public use. No native unlimited-free claim: published MapKit JS limits are not native SDK quotas.

No production license approval, provider coverage test, external legal opinion or account-term acceptance is asserted here.

## 2026-10-09 source recheck and unresolved determination

Read-only HTTP fetch of Apple's public [Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) returned HTTP 200. Attachment 6 §§2.1–2.5 still states attribution/non-obscuring, prohibits extraction and secondary/derived Map Data databases, requires a corresponding Apple map for surfaced address results, and permits only temporary, limited caching as necessary under the terms. §2.7 permits usage limits/revocation. Official [MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch.md) and [annotation clusteringIdentifier](https://developer.apple.com/documentation/mapkit/mkannotationview/clusteringidentifier.md) Markdown endpoints returned HTTP 200; the latter says a non-`nil` identifier enables native collision clustering. This is a **public-source recheck**, not an inspection of the app owner's accepted agreement or legal advice.

**Decision required:** product/legal must supply the accepted-account contract version and a written determination for user-authored dropped-pin coordinate persistence, including source/provenance and Apple map/result display. Engineering can implement synthetic local map previews later, but **must not persist Apple-derived pin/POI/geocode data into the shared catalog** or treat a tap/checkbox as rights clearance. Coordinate provenance categories in this record are proposed, not approval. A written signed decision, date and reviewer are absent; M0 rights gate remains open.

## 2026-10-13 open-data candidate import (unreviewed)

1,168 California candidate places were imported from public-domain government data (IMLS PLS FY 2023 outlets; City of San Diego recreation centres, ODC-PDDL) with per-record provenance — see `docs/data/open-data-candidates.md`. These are candidates for the `licensed_open_or_contract_source` category, **not** approved records: they load only behind the DEBUG `--candidates` flag. IMLS coordinates are IMLS's own geocodes released as federal public domain; whether that satisfies this record's coordinate-rights requirement still needs the product/legal determination above. No Apple or other provider data was used.

**2026-10-13:** the owner chose to accept member-submitted pins (criterion 2). The app stores only the position the member sets by moving the map or typing coordinates. Apple POIs are hidden in the picker and no provider search result is saved. Whether that position may be published still needs the written determination above. Moderators should reject pins that look copied from a provider listing.
