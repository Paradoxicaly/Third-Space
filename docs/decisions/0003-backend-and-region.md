# 0003 — Owned catalog backend and operational regions

**Status:** Supabase/PostgreSQL/PostGIS recommendation; project region, data processing and operations **unselected**. **Owners:** engineering/privacy for hosting/backup; product/ops for budget; safety lead for moderation scope/language.

## Decision boundary

Recommend one initial Supabase project with Postgres/PostGIS: bounded area/antimeridian search, approved-only public projections, typed facts with provenance, immutable pending revisions, transactional human approval, private sensitive geometry/evidence, RLS, storage authorization and audit/invalidation. A Swift repository interface permits synthetic local fixtures in early prototypes; *mock fallback is forbidden in release*. No Supabase project, migration, credential or region is provisioned by this document. Backend authority controls content state, region/language grants and active account status; neither mutable client profile metadata nor hidden staff UI grants publication rights.

Public browsing may operate globally from approved owned data. A geographic region is not an authorization scope: independent reviewed operational scope, staffed languages, incident pause and global triage for ambiguous boundaries govern remote submissions. Unsupported regions can browse and retain local drafts, not silently enter an unserviceable publishing queue. Moderation of all public text/images/edits is required in MVP; sensitive release requires two distinct scoped reviewers. Accountless protected safety request/contact remains available. Staff cannot approve their own content. Rights evidence and exact sensitive geometry remain private; approved revision membership applies to all child rows and aggregates.

Firestore would require geohash joins and extra relational consistency mechanisms for these requirements; self-managed Postgres increases pilot operational overhead. Neither alternative resolves licensing, staffing or privacy by itself.

## Open gates / evidence required

- **Engineering/privacy:** select primary project region against actual pilot data, transfer/residency obligations, vendor terms, backup/restore settings and deletion replay; document regional restrictions before M5/live data. No speculative multi-region writes.
- **Safety lead:** name reviewers, supported languages, escalation/backups and incident pause ownership per enabled region before accepting public submissions. Initial Carson/South Bay collection does not authorize worldwide publishing. No SLA is promised until staffed and measured.
- **Product/ops:** approve monthly backend/storage/email/provider *and staff* envelope, owner, 50/80/100% alerts, hard quotas and degradation/kill switch before public usage; no invented total or free-tier production assumption.
- **Product/privacy/legal:** settle 18+ closed-beta contributor assumption/teen safety, retention and market-by-market processing duties before signup launch. Review deletion/account revocation and rights/contact channels against actual configured infrastructure.
- **Engineering/security:** before public beta, replay local migrations; test raw RLS/REST/RPC/storage routes as anon/member/revoked staff, publication atomicity, denied private geometry, cache tombstones, deletion and backup restoration. No passing tests are asserted here.

Only local synthetic repository prototypes may proceed without these gates; no real production seed import or release authorization follows from this recommendation.

## M0 unresolved assignment register (2026-10-09)

No primary Supabase project region, DPA/transfer arrangement, backup configuration, monthly staff/infrastructure budget or named spending owner has been selected. No moderator or backup has been named, no language coverage granted, and no public submission region is enabled. The accountable *roles* above are placeholders for a decision-maker, not staff assignments. Product/ops must provide a cost envelope and controls before billable provisioning; engineering/privacy must provide a documented region/retention/restore choice; safety lead must provide named trained reviewers and escalation before any remote write. Until then local contracts, disposable synthetic tests and own-data UI are the only permitted implementation paths. No backend credentials or live accounts are needed to verify M0 documentation.
