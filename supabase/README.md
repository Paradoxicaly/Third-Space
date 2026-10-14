# Supabase backend

Community features (accounts, place submissions, moderation, ratings, reviews, tagged place posts, one-level Q&A answers, helpful votes, likes, follows, reports) run on Supabase Auth + Postgres. **All authority is in the database**: row-level security plus the `moderate_place`, `moderate_place_post` and `resolve_report` functions. The iOS app only holds the public anon key.

## One-time setup

1. **Create a project** at supabase.com. Choose the region nearest your users and keep the database password private.
2. **Email sign-up:** Authentication → Sign In / Providers → Email → turn **off "Confirm email"**. Supabase's built-in mailer only delivers to project team members, so confirmations would block testers. Re-enable it (with custom SMTP) before a public launch.
3. **Apply the schema:** SQL Editor → paste and run `migrations/20261013120000_community.sql`, then paste and run `migrations/20261013130000_place_address.sql`, then `migrations/20261013140000_place_posts.sql`.
4. **Optional seed:** paste `seed/california_candidates.sql` (1,168 public-domain places, inserted as `pending`) → Run. Regenerate with `python3 -I scripts/export-candidates-sql.py`. Approving them publishes them, so that's a moderator decision; see `docs/data/open-data-candidates.md`.
5. **Make a moderator:** sign up in the app, then in SQL Editor:
   ```sql
   insert into public.moderators (user_id)
   select id from public.profiles where username = 'YOUR_USERNAME';
   ```
6. **Configure the app:** copy `Supabase.example.plist` to `ThirdSpace/Resources/Supabase.plist` (git-ignored) and fill in the Project URL and the **anon / publishable** key from Project Settings → API. Never use the `service_role` key; the app refuses a key containing that string.

With the plist present, a normal launch uses Supabase. `--ui-testing` (synthetic, on-device backend) and `--candidates` (DEBUG open-data preview) never touch the network.

## Verify the security rules

```sh
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<anon key> \
MODERATOR_EMAIL=<moderator email> MODERATOR_PASSWORD=<password> \
python3 -I scripts/supabase-rls-check.py
```

This signs up throwaway `rls_check_*` members with the anon key and confirms they **cannot**:
- see pending places,
- approve places, or change a status directly,
- rate or review pending places,
- make themselves moderators,
- follow on someone else's behalf,
- or read other people's reports.

With moderator credentials it also confirms that moderators can decide other members' submissions but not their own. Delete the throwaway users afterwards in Authentication → Users.

## Rules at a glance

| Table | Read | Write |
|---|---|---|
| places | approved: everyone. pending/rejected: submitter and moderators | members insert; a trigger forces `pending`, submitter and no source. Status changes only via `moderate_place` (moderator, never own submission) |
| ratings / likes | everyone (approved places) | own rows on approved places |
| reviews | visible reviews on approved places; own; moderators | own, approved places; moderators hide via `resolve_report` |
| place_posts | approved posts and answers on approved places; own pending/rejected; moderators | members submit tagged root posts or one-level answers as pending; moderator approval via `moderate_place_post`; reports can hide |
| place_post_helpful_votes | votes on approved answers | one vote per member per answer; no voting on own answer |
| follows | everyone | as yourself only, not yourself |
| reports | own; moderators | members insert; a trigger forces reporter and `open` |
| moderators | own row | SQL editor / service role only |

Not yet built: account deletion, blocking, rate limits and email verification. These are release requirements in `docs/qa/native-acceptance.md`.
