#!/usr/bin/env python3
"""Build the California open-data *candidate* catalog (no third-party dependencies).

Inputs are public-domain government datasets, downloaded separately into an isolated folder:

  IMLS Public Libraries Survey FY 2023 outlet file (public domain; citation required)
    https://www.imls.gov/sites/default/files/2025-08/pls_fy2023_csv.zip  -> CSV/pls_fy23_outlet_pud23i.csv
  City of San Diego Recreation Center Locations (ODC-PDDL)
    https://geo.sandag.org/server/rest/directories/downloads/Recreation_Centers_SD.geojson

Every record is an UNREVIEWED CANDIDATE: provenance is kept per record, no practical fact is invented,
and nothing here is approved for public display. Usage:

  python3 -I scripts/import-open-candidates.py --imls-outlets <csv> --sd-rec-centers <geojson>
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ThirdSpace/Resources/OpenDataCandidates/california-candidates.json"
RETRIEVED = "2026-10-13"
NAMESPACE = uuid.UUID("6f0c3b1e-5a4d-4f6b-9a51-3e2b7c1d9a20")  # fixed: IDs stay stable across re-imports
CA_BOUNDS = (32.4, -124.6, 42.1, -114.1)  # south, west, north, east

IMLS = {
    "id": "imls-pls-fy2023-outlets",
    "title": "Public Libraries Survey FY 2023 — Public Library Outlet Data File",
    "publisher": "Institute of Museum and Library Services",
    "license": "Public domain (U.S. federal government work); citation required",
    "url": "https://www.imls.gov/sites/default/files/2025-08/pls_fy2023_csv.zip",
    "citation": "Pelczar, M., Li, J., Alhassani, S., Barr, K., & Mabile, S. (2025). Data File Documentation: "
                "Public Libraries in the United States Fiscal Year 2023. Institute of Museum and Library Services: Washington, D.C.",
}
SD_REC = {
    "id": "sandiego-recreation-centers",
    "title": "Recreation Center Locations",
    "publisher": "City of San Diego Parks & Recreation (via data.sandiego.gov)",
    "license": "Open Data Commons Public Domain Dedication and License (ODC-PDDL)",
    "url": "https://data.sandiego.gov/datasets/recreation-center-locations/",
    "citation": "City of San Diego, Recreation Center Locations, data.sandiego.gov.",
}

# IMLS structure codes that mean the outlet is not currently a reliable open location.
EXCLUDED_STATUS = {"10", "23", "25"}  # deleted, temporarily closed, survey non-respondent
# IMLS geocode match types; street-name-only matches are too coarse to place a marker.
PRECISION = {"POINTADDRESS": "exactPublic", "SUBADDRESS": "exactPublic", "MANUAL": "exactPublic", "STREETADDRESS": "approximatePublic"}

LOWER = {"of", "the", "and", "at", "for", "in", "on", "de", "del", "la", "las", "los", "el", "y"}
UPPER = {"la", "ca", "us", "ucla", "csu", "uc", "ii", "iii", "iv", "po", "ne", "nw", "se", "sw", "mlk"}


def title(text: str) -> str:
    """Readable case for ALL-CAPS source names, keeping the source spelling otherwise."""
    words = re.split(r"(\s+|-|/)", text.strip().lower())
    out = []
    for index, word in enumerate(words):
        if not word or word.isspace() or word in "-/":
            out.append(word)
        elif word.rstrip(".") in UPPER and len(word.rstrip(".")) <= 4 and word.rstrip(".") not in {"la"}:
            out.append(word.upper())
        elif index > 0 and word in LOWER:
            out.append(word)
        else:
            parts = word.split("'")
            out.append("'".join(p[:1].upper() + p[1:] for p in parts))
    return "".join(out)


def stable_id(key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, key)).upper()


def county_region(county: str) -> tuple[str, str]:
    name = title(county)
    return "us-ca-" + re.sub(r"[^a-z]+", "-", county.lower()).strip("-"), f"{name} County"


def in_california(lat: float, lon: float) -> bool:
    south, west, north, east = CA_BOUNDS
    return south <= lat <= north and west <= lon <= east


def imls_libraries(path: Path, regions: dict) -> list[dict]:
    places = []
    with path.open(encoding="latin-1", newline="") as handle:
        for row in csv.DictReader(handle):
            if row["STABR"] != "CA" or row["C_OUT_TY"] == "BS" or row["STATSTRU"] in EXCLUDED_STATUS:
                continue
            precision = PRECISION.get(row["GEOMTYPE"])
            lat, lon = float(row["LATITUDE"]), float(row["LONGITUD"])
            if precision is None or not in_california(lat, lon):
                continue
            region_id, region_name = county_region(row["CNTY"])
            regions[region_id] = region_name
            record_id = f"{row['FSCSKEY']}-{row['FSCS_SEQ']}"
            places.append({
                "id": stable_id(f"{IMLS['id']}:{record_id}"),
            "revisionID": stable_id(f"{IMLS['id']}:{record_id}:{RETRIEVED}"),
                "name": title(row["LIBNAME"]),
                "category": "study",
                "regionID": region_id,
                "latitude": round(lat, 6), "longitude": round(lon, 6),
                "precision": precision,
                "address": f"{title(row['ADDRESS'])}, {title(row['CITY'])}, CA {row['ZIP']}",
                "sourceID": IMLS["id"],
                "sourceRecordID": record_id,
                "coordinateMethod": f"IMLS geocode ({row['GEOMTYPE']}, score {row['GEOSCORE']})",
                "facts": [],
            })
    return places


def sp_zone6_to_wgs84(x_ft: float, y_ft: float) -> tuple[float, float]:
    """Inverse Lambert Conformal Conic for NAD83 / California zone 6 (US survey feet, EPSG:2230).

    NAD83 is treated as WGS84 (sub-metre difference for display markers)."""
    a, f = 6378137.0, 1 / 298.257222101
    e = math.sqrt(2 * f - f * f)
    ft = 1200 / 3937
    x, y = x_ft * ft - 2_000_000.0, y_ft * ft - 500_000.0
    lat1, lat2, lat0, lon0 = map(math.radians, (33 + 53 / 60, 32 + 47 / 60, 32 + 10 / 60, -116.25))

    def m(p): return math.cos(p) / math.sqrt(1 - (e * math.sin(p)) ** 2)
    def t(p): return math.tan(math.pi / 4 - p / 2) / ((1 - e * math.sin(p)) / (1 + e * math.sin(p))) ** (e / 2)

    n = (math.log(m(lat1)) - math.log(m(lat2))) / (math.log(t(lat1)) - math.log(t(lat2)))
    big_f = m(lat1) / (n * t(lat1) ** n)
    rho0 = a * big_f * t(lat0) ** n
    rho = math.copysign(math.hypot(x, rho0 - y), n)
    theta = math.atan2(x, rho0 - y)
    tt = (rho / (a * big_f)) ** (1 / n)
    lat = math.pi / 2 - 2 * math.atan(tt)
    for _ in range(10):
        lat = math.pi / 2 - 2 * math.atan(tt * ((1 - e * math.sin(lat)) / (1 + e * math.sin(lat))) ** (e / 2))
    return math.degrees(lat), math.degrees(theta / n + lon0)


def sd_rec_centers(path: Path, regions: dict) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("crs", {}).get("properties", {}).get("name") != "EPSG:2230":
        raise SystemExit("San Diego recreation centers changed coordinate system; update the projection.")
    region_id, region_name = county_region("SAN DIEGO")
    regions[region_id] = region_name
    places = []
    for feature in data["features"]:
        p = feature["properties"]
        if not p.get("rec_bldg") or not feature.get("geometry"):
            continue
        lat, lon = sp_zone6_to_wgs84(*feature["geometry"]["coordinates"][:2])
        if not in_california(lat, lon):
            continue
        # globalid identifies the building; facility_name_id is shared by buildings in one park.
        record_id = p["globalid"].strip("{}").upper()
        places.append({
            "id": stable_id(f"{SD_REC['id']}:{record_id}"),
            "revisionID": stable_id(f"{SD_REC['id']}:{record_id}:{RETRIEVED}"),
            "name": p["rec_bldg"].strip(),
            "category": "social",
            "regionID": region_id,
            "latitude": round(lat, 6), "longitude": round(lon, 6),
            "precision": "exactPublic",
            "address": f"{p['address'].strip()}, {p['city'].strip()}, CA {p['zipcode']}",
            "sourceID": SD_REC["id"],
            "sourceRecordID": record_id,
            "coordinateMethod": "City of San Diego GIS point (EPSG:2230, reprojected to WGS84)",
            # No practical facts: the dataset has no observation dates, so nothing can be shown as observed.
            "facts": [],
        })
    return places


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--imls-outlets", type=Path, required=True)
    parser.add_argument("--sd-rec-centers", type=Path, required=True)
    args = parser.parse_args()
    regions: dict[str, str] = {}
    places = imls_libraries(args.imls_outlets, regions) + sd_rec_centers(args.sd_rec_centers, regions)
    ids = [p["id"] for p in places]
    if len(ids) != len(set(ids)):
        raise SystemExit("Duplicate stable IDs; source keys changed.")
    places.sort(key=lambda p: (p["regionID"], p["name"], p["id"]))
    catalog = {
        "schemaVersion": 1,
        "status": "unreviewedCandidates",
        "notice": "Open-data candidates for review. Not verified by Third Spaces; hours, access and amenities are unknown.",
        "retrieved": RETRIEVED,
        "sources": [IMLS, SD_REC],
        "regions": [{"id": k, "name": v} for k, v in sorted(regions.items())],
        "places": places,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    by_source = {s["id"]: sum(p["sourceID"] == s["id"] for p in places) for s in catalog["sources"]}
    print(f"wrote {OUT.relative_to(ROOT)}: {len(places)} places, {len(regions)} regions, {by_source}")


if __name__ == "__main__":
    main()
