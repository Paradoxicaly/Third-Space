-- Third Spaces community schema: places with moderation, ratings, reviews, likes, follows, reports.
-- Authority lives here (RLS + SECURITY DEFINER functions), never in the client. Apply once per project.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- profiles & roles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  created_at timestamptz not null default now()
);

-- Granted only from the SQL editor / service role. No client policy can write this table.
create table public.moderators (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  granted_at timestamptz not null default now()
);

create or replace function public.is_moderator() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.moderators where user_id = auth.uid());
$$;

-- Profile row created from sign-up metadata; username must be supplied by the client at sign-up.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'username', 'user_' || substr(replace(new.id::text, '-', ''), 1, 12)));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- places
create table public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  category text not null check (category in ('study', 'relax', 'social', 'outdoors', 'other')),
  description text not null default '' check (char_length(description) <= 2000),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  submitted_by uuid references public.profiles (id) on delete set null default auth.uid(),
  decided_by uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  decision_note text check (char_length(decision_note) <= 500),
  -- Imported records carry their dataset provenance; user submissions record the submitter instead.
  source jsonb,
  created_at timestamptz not null default now()
);
create index places_status_idx on public.places (status);
create index places_position_idx on public.places (latitude, longitude) where status = 'approved';

-- Clients can only create pending rows for themselves; decisions are set only by moderate_place().
create or replace function public.places_force_pending() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) = 'authenticated' or auth.uid() is not null then
    new.status := 'pending';
    new.submitted_by := auth.uid();
    new.decided_by := null; new.decided_at := null; new.decision_note := null;
    new.source := null;
  end if;
  return new;
end;
$$;
create trigger places_force_pending before insert on public.places
  for each row execute function public.places_force_pending();

create or replace function public.moderate_place(place_id uuid, decision text, note text default null)
returns public.places
language plpgsql security definer set search_path = public as $$
declare result public.places;
begin
  if not public.is_moderator() then raise exception 'moderator role required' using errcode = '42501'; end if;
  if decision not in ('approved', 'rejected') then raise exception 'invalid decision'; end if;
  update public.places
     set status = decision, decided_by = auth.uid(), decided_at = now(), decision_note = note
   where id = place_id
     and status = 'pending'
     and submitted_by is distinct from auth.uid()   -- no self-approval
  returning * into result;
  if result.id is null then raise exception 'not found, already decided, or own submission' using errcode = 'P0002'; end if;
  return result;
end;
$$;

-- ---------------------------------------------------------------- ratings, reviews, likes, follows
create table public.ratings (
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  stars smallint not null check (stars between 1 and 5),
  updated_at timestamptz not null default now(),
  primary key (place_id, user_id)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index reviews_place_idx on public.reviews (place_id, created_at desc);

create table public.likes (
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (place_id, user_id)
);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  target_type text not null check (target_type in ('place', 'review', 'profile')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'harassment', 'unsafe', 'inaccurate', 'private_property', 'other')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolved_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create or replace function public.reports_force_open() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.reporter_id := auth.uid(); new.status := 'open'; new.resolved_by := null;
  return new;
end;
$$;
create trigger reports_force_open before insert on public.reports
  for each row execute function public.reports_force_open();

create or replace function public.resolve_report(report_id uuid, outcome text, hide_review boolean default false)
returns public.reports
language plpgsql security definer set search_path = public as $$
declare result public.reports;
begin
  if not public.is_moderator() then raise exception 'moderator role required' using errcode = '42501'; end if;
  if outcome not in ('resolved', 'dismissed') then raise exception 'invalid outcome'; end if;
  update public.reports set status = outcome, resolved_by = auth.uid()
   where id = report_id and status = 'open' returning * into result;
  if result.id is null then raise exception 'not found or already handled' using errcode = 'P0002'; end if;
  if hide_review and result.target_type = 'review' then
    update public.reviews set hidden = true where id = result.target_id;
  end if;
  return result;
end;
$$;

-- Public aggregate; counts only approved places and visible ratings.
create view public.place_rating_summary with (security_invoker = true) as
  select r.place_id, round(avg(r.stars)::numeric, 2) as average, count(*)::int as count
    from public.ratings r join public.places p on p.id = r.place_id and p.status = 'approved'
   group by r.place_id;

-- ---------------------------------------------------------------- row-level security
alter table public.profiles enable row level security;
alter table public.moderators enable row level security;
alter table public.places enable row level security;
alter table public.ratings enable row level security;
alter table public.reviews enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.reports enable row level security;

create policy "profiles readable" on public.profiles for select using (true);
create policy "own profile update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "moderator self-check" on public.moderators for select to authenticated using (user_id = auth.uid());

create policy "approved, own or moderator" on public.places for select
  using (status = 'approved' or submitted_by = auth.uid() or public.is_moderator());
create policy "members submit" on public.places for insert to authenticated with check (true); -- trigger forces pending + submitter

create policy "ratings on approved places readable" on public.ratings for select
  using (exists (select 1 from public.places p where p.id = place_id and p.status = 'approved'));
create policy "rate approved places" on public.ratings for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.places p where p.id = place_id and p.status = 'approved'));
create policy "change own rating" on public.ratings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "remove own rating" on public.ratings for delete to authenticated using (user_id = auth.uid());

create policy "visible reviews" on public.reviews for select
  using ((not hidden and exists (select 1 from public.places p where p.id = place_id and p.status = 'approved'))
         or author_id = auth.uid() or public.is_moderator());
create policy "review approved places" on public.reviews for insert to authenticated
  with check (author_id = auth.uid() and not hidden and exists (select 1 from public.places p where p.id = place_id and p.status = 'approved'));
create policy "delete own review" on public.reviews for delete to authenticated using (author_id = auth.uid());

create policy "likes readable" on public.likes for select using (true);
create policy "like approved places" on public.likes for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.places p where p.id = place_id and p.status = 'approved'));
create policy "unlike own" on public.likes for delete to authenticated using (user_id = auth.uid());

create policy "follows readable" on public.follows for select using (true);
create policy "follow as self" on public.follows for insert to authenticated with check (follower_id = auth.uid());
create policy "unfollow as self" on public.follows for delete to authenticated using (follower_id = auth.uid());

create policy "file reports" on public.reports for insert to authenticated with check (true); -- trigger sets reporter/status
create policy "own or moderator reports" on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_moderator());

grant select on public.place_rating_summary to anon, authenticated;
grant execute on function public.moderate_place(uuid, text, text) to authenticated;
grant execute on function public.resolve_report(uuid, text, boolean) to authenticated;
grant execute on function public.is_moderator() to anon, authenticated;
