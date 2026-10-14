# California open-data candidate catalog

**Status (2026-10-13): unreviewed candidates, DEBUG-only.** These records are *not* approved catalog content. They load only with the DEBUG launch flag `--candidates`; Release builds stay fail-closed. Publishing any of them requires the coordinate/seed-rights decision in `docs/decisions/0002-map-provider-and-coordinate-rights.md`, human review of each record, and the backend gates in `0003`.

Bundled file: `ThirdSpace/Resources/OpenDataCandidates/california-candidates.json` — 1,168 places across all 58 California counties.

## Sources

| Source | Records | Licence | Citation / link |
|---|---|---|---|
| IMLS Public Libraries Survey FY 2023, Public Library Outlet Data File | 1,107 library outlets | Public domain (U.S. federal work); **citation required** | Pelczar, M., Li, J., Alhassani, S., Barr, K., & Mabile, S. (2025). *Data File Documentation: Public Libraries in the United States Fiscal Year 2023.* IMLS. Data: https://www.imls.gov/sites/default/files/2025-08/pls_fy2023_csv.zip |
| City of San Diego, Recreation Center Locations | 61 recreation buildings | ODC Public Domain Dedication and License (PDDL) | https://data.sandiego.gov/datasets/recreation-center-locations/ |

Both licences were read from the publishers' own documentation on 2026-10-13. This is an engineering reading, not legal advice; the rights owner named in 0002 must still confirm use of these coordinates.

## What the importer keeps and drops

- **Kept per record:** name (title-cased from the source's capitals), category (library → Study, recreation centre → Social), county region, coordinates, published address, source record ID, geocode method, licence and citation.
- **Dropped:** bookmobiles; IMLS outlets marked deleted (10), temporarily closed (23) or survey non-respondent (25); geocodes matched only to a street name. Interpolated street-address geocodes are marked `approximatePublic`.
- **Never added:** practical facts (cost, hours, Wi-Fi, access), photos, ratings or "open now". Neither dataset has dated observations, so every candidate shows these as unknown. IMLS annual service hours are not a current schedule and are not used.
- IDs are UUIDv5 of `source:recordID`, so re-imports keep the same IDs and saved places stay attached.

## Re-running the import

Download into a fresh folder outside the repo, then:

```sh
python3 -I scripts/import-open-candidates.py \
  --imls-outlets <folder>/CSV/pls_fy23_outlet_pud23i.csv \
  --sd-rec-centers <folder>/Recreation_Centers_SD.geojson
```

San Diego coordinates arrive in EPSG:2230 (California zone 6, US feet) and are reprojected in the script; it stops if the published CRS changes. `ThirdSpaceTests/OpenDataCandidateTests.swift` checks the output: ≥250 places, all inside California, unique stable IDs, provenance on every record, no facts or media.

## Gaps

Cafés, bookstores and other commercial third spaces have no comparably licensed open dataset. They should come from rights-cleared community submissions through the human review flow, not from scraped listings or map-provider POIs.
