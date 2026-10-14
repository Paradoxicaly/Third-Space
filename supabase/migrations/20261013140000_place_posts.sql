-- Tagged, place-scoped community posts with one-level answers and helpful votes.
create table public.place_posts (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  parent_id uuid references public.place_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  kind text not null check (kind in ('question', 'visit_note', 'correction', 'answer')),
  title text,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  check ((parent_id is null and kind <> 'answer') or (parent_id is not null and kind = 'answer')),
  check ((kind = 'question' and char_length(btrim(coalesce(title, ''))) between 1 and 160) or kind <> 'question'),
  unique (id, place_id)
);
create index place_posts_place_idx on public.place_posts (place_id, created_at desc) where parent_id is null;
create index place_posts_parent_idx on public.place_posts (parent_id, created_at asc) where parent_id is not null;

create or replace function public.place_posts_force_pending() returns trigger
language plpgsql security definer set search_path = public as $$
declare parent public.place_posts;
begin
  new.author_id := auth.uid();
  new.status := 'pending';
  new.hidden := false;
  if not exists (select 1 from public.places p where p.id = new.place_id and p.status = 'approved') then
    raise exception 'posts require an approved place' using errcode = '42501';
  end if;
  if new.parent_id is not null then
    select * into parent from public.place_posts where id = new.parent_id;
    if parent.id is null or parent.parent_id is not null or parent.kind <> 'question' or parent.place_id <> new.place_id or parent.status <> 'approved' or parent.hidden then
      raise exception 'answers must reply to a visible question at the same place' using errcode = '42501';
    end if;
    if new.kind <> 'answer' or new.title is not null then raise exception 'invalid answer'; end if;
  elsif new.kind = 'answer' then
    raise exception 'answers require a parent question';
  end if;
  return new;
end;
$$;
create trigger place_posts_pending_before_insert before insert on public.place_posts
  for each row execute function public.place_posts_force_pending();

create or replace function public.moderate_place_post(post_id uuid, decision text, note text default null)
returns public.place_posts
language plpgsql security definer set search_path = public as $$
declare result public.place_posts;
begin
  if not public.is_moderator() then raise exception 'moderator role required' using errcode = '42501'; end if;
  if decision not in ('approved', 'rejected') then raise exception 'invalid decision'; end if;
  update public.place_posts set status = decision
   where id = post_id and status = 'pending' and author_id <> auth.uid()
   returning * into result;
  if result.id is null then raise exception 'not found, own post, or already decided' using errcode = 'P0002'; end if;
  return result;
end;
$$;

create table public.place_post_helpful_votes (
  post_id uuid not null references public.place_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create view public.place_post_helpful_summary with (security_invoker = false) as
  select v.post_id, count(*)::int as helpful_count
    from public.place_post_helpful_votes v
    join public.place_posts answer on answer.id = v.post_id and answer.kind = 'answer' and answer.status = 'approved' and not answer.hidden
    join public.place_posts question on question.id = answer.parent_id and question.kind = 'question' and question.status = 'approved' and not question.hidden
    join public.places place on place.id = answer.place_id and place.status = 'approved'
   group by v.post_id;

alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check (target_type in ('place', 'review', 'post', 'profile'));

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
  elsif hide_review and result.target_type = 'post' then
    update public.place_posts set hidden = true where id = result.target_id;
  end if;
  return result;
end;
$$;

alter table public.place_posts enable row level security;
alter table public.place_post_helpful_votes enable row level security;

create policy "visible place posts" on public.place_posts for select
  using (
    (author_id = auth.uid() or public.is_moderator())
    or (not hidden and status = 'approved'
        and exists (select 1 from public.places p where p.id = place_id and p.status = 'approved')
        and (parent_id is null or exists (
          select 1 from public.place_posts parent
           where parent.id = place_posts.parent_id and parent.status = 'approved' and not parent.hidden and parent.kind = 'question'
        )))
  );
create policy "members submit posts" on public.place_posts for insert to authenticated
  with check (author_id = auth.uid() and status = 'pending' and not hidden);

create policy "helpful votes on visible answers" on public.place_post_helpful_votes for select
  using (user_id = auth.uid());
create policy "helpful vote as self" on public.place_post_helpful_votes for insert to authenticated
  with check (user_id = auth.uid() and exists (
    select 1 from public.place_posts p join public.places place on place.id = p.place_id
     where p.id = post_id and p.kind = 'answer' and p.status = 'approved' and not p.hidden and p.author_id <> auth.uid() and place.status = 'approved'
  ));
create policy "remove own helpful vote" on public.place_post_helpful_votes for delete to authenticated using (user_id = auth.uid());

grant execute on function public.moderate_place_post(uuid, text, text) to authenticated;
grant select on public.place_post_helpful_summary to anon, authenticated;
grant select on public.place_post_helpful_votes to authenticated;
