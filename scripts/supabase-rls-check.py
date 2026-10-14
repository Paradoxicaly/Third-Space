#!/usr/bin/env python3
"""Adversarial check of the community RLS rules against a live Supabase project (standard library only).

Creates throwaway members (rls_check_<random>) through the public API with the anon key — exactly what an
attacker could do — and verifies what they must NOT be able to do. Optionally exercises the moderator path.

  SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<anon key> python3 -I scripts/supabase-rls-check.py
  # optional moderator checks (an account already granted in public.moderators):
  MODERATOR_EMAIL=... MODERATOR_PASSWORD=... python3 -I scripts/supabase-rls-check.py

Never pass the service-role key: the point is to test with the same powers as the app.
Throwaway accounts cannot be deleted with the anon key; remove them in Authentication → Users afterwards.
"""
import json
import os
import secrets
import sys
import urllib.error
import urllib.request

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_ANON_KEY", "")
if not URL.startswith("https://") or not KEY or "service_role" in KEY:
    sys.exit("Set SUPABASE_URL (https) and SUPABASE_ANON_KEY (anon/publishable key only).")

results = []


def call(method, path, token=None, body=None, prefer=None):
    request = urllib.request.Request(URL + path, method=method, data=None if body is None else json.dumps(body).encode())
    request.add_header("apikey", KEY)
    request.add_header("Authorization", f"Bearer {token or KEY}")
    request.add_header("Content-Type", "application/json")
    if prefer:
        request.add_header("Prefer", prefer)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw)
        except ValueError:
            return error.code, raw.decode(errors="replace")


def check(name, ok, detail=""):
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f"  -> {detail}"))


def member(tag):
    name = f"rls_check_{tag}_{secrets.token_hex(3)}"
    status, body = call("POST", "/auth/v1/signup", body={"email": f"{name}@example.com", "password": secrets.token_urlsafe(12), "data": {"username": name}})
    if status != 200 or not isinstance(body, dict) or not body.get("access_token"):
        sys.exit(f"Could not create a test member ({status}): {body}\nIs 'Confirm email' turned off?")
    return body["access_token"], body["user"]["id"]


def sign_in(email, password):
    status, body = call("POST", "/auth/v1/token?grant_type=password", body={"email": email, "password": password})
    if status != 200:
        sys.exit(f"Moderator sign-in failed ({status}): {body}")
    return body["access_token"], body["user"]["id"]


a_token, a_id = member("a")
b_token, b_id = member("b")

# Submission is forced to pending and attributed to the caller, whatever the client sends.
status, rows = call("POST", "/rest/v1/places?select=id,status,submitted_by", a_token, prefer="return=representation",
                    body={"name": "RLS check place", "category": "study", "latitude": 1, "longitude": 1,
                          "status": "approved", "submitted_by": b_id, "source": {"forged": True}})
place_id = rows[0]["id"] if status == 201 and rows else None
check("member submission stored as pending for themselves", status == 201 and rows and rows[0]["status"] == "pending" and rows[0]["submitted_by"] == a_id, (status, rows))

status, rows = call("GET", f"/rest/v1/places?select=id&id=eq.{place_id}")
check("anonymous visitors cannot see pending places", status == 200 and rows == [], (status, rows))
status, rows = call("GET", f"/rest/v1/places?select=id&id=eq.{place_id}", b_token)
check("other members cannot see someone else's pending place", status == 200 and rows == [], (status, rows))
status, rows = call("GET", f"/rest/v1/places?select=id,status&id=eq.{place_id}", a_token)
check("submitter can see their own pending place", status == 200 and len(rows) == 1, (status, rows))

status, body = call("POST", "/rest/v1/rpc/moderate_place", a_token, body={"place_id": place_id, "decision": "approved"})
check("members cannot approve via moderate_place", status >= 400, (status, body))
status, rows = call("PATCH", f"/rest/v1/places?id=eq.{place_id}", a_token, prefer="return=representation", body={"status": "approved"})
check("members cannot update status directly", status >= 400 or rows == [], (status, rows))

status, body = call("POST", "/rest/v1/ratings", a_token, body={"place_id": place_id, "user_id": a_id, "stars": 5})
check("cannot rate a pending place", status >= 400, (status, body))
status, body = call("POST", "/rest/v1/reviews", a_token, body={"place_id": place_id, "body": "x"})
check("cannot review a pending place", status >= 400, (status, body))
status, body = call("POST", "/rest/v1/moderators", a_token, body={"user_id": a_id})
check("members cannot grant themselves moderator", status >= 400, (status, body))
status, body = call("POST", "/rest/v1/follows", a_token, body={"follower_id": b_id, "followee_id": a_id})
check("cannot create a follow on someone else's behalf", status >= 400, (status, body))

status, rows = call("POST", "/rest/v1/reports?select=id,reporter_id,status", a_token, prefer="return=representation",
                    body={"target_type": "profile", "target_id": b_id, "reason": "spam", "status": "resolved", "reporter_id": b_id})
report_id = rows[0]["id"] if status == 201 and rows else None
check("report filed as open by the caller", status == 201 and rows[0]["status"] == "open" and rows[0]["reporter_id"] == a_id, (status, rows))
status, rows = call("GET", f"/rest/v1/reports?select=id&id=eq.{report_id}", b_token)
check("members cannot read others' reports", status == 200 and rows == [], (status, rows))

moderator_email, moderator_password = os.environ.get("MODERATOR_EMAIL"), os.environ.get("MODERATOR_PASSWORD")
if moderator_email and moderator_password:
    m_token, _ = sign_in(moderator_email, moderator_password)
    status, rows = call("GET", f"/rest/v1/reports?select=id&id=eq.{report_id}", m_token)
    check("moderator sees the report", status == 200 and len(rows) == 1, (status, rows))
    status, body = call("POST", "/rest/v1/rpc/moderate_place", m_token, body={"place_id": place_id, "decision": "rejected", "note": "RLS check"})
    check("moderator can decide a member's submission", status == 200, (status, body))
    status, rows = call("GET", f"/rest/v1/places?select=status,decision_note&id=eq.{place_id}", a_token)
    check("submitter sees the decision", status == 200 and rows and rows[0]["status"] == "rejected", (status, rows))
    status, rows = call("POST", "/rest/v1/places?select=id", m_token, prefer="return=representation",
                        body={"name": "Moderator own place", "category": "other", "latitude": 2, "longitude": 2})
    own_id = rows[0]["id"] if status == 201 and rows else None
    status, body = call("POST", "/rest/v1/rpc/moderate_place", m_token, body={"place_id": own_id, "decision": "approved"})
    check("moderator cannot approve their own submission", status >= 400, (status, body))
    call("POST", "/rest/v1/rpc/resolve_report", m_token, body={"report_id": report_id, "outcome": "dismissed"})
else:
    print("SKIP moderator checks (set MODERATOR_EMAIL / MODERATOR_PASSWORD)")

print(f"\n{sum(results)}/{len(results)} checks passed")
sys.exit(0 if all(results) else 1)
