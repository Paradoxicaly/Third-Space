-- Member-typed street address, shown to moderators so they can check the pin. Plain text; never geocoded.
alter table public.places add column address text check (char_length(address) <= 400);
