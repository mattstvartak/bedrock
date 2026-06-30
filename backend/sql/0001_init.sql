-- Bedrock canonical-account schema (Neon Postgres).
-- One account per human; platform identities (steam/psn/xbox/switch/device/epic)
-- link to it. Saves are metadata here, blobs in R2 keyed by account + slot.

create table if not exists accounts (
  id           uuid primary key default gen_random_uuid(),
  display_name text not null default '',
  created_at   timestamptz not null default now()
);

create table if not exists platform_links (
  platform    text not null,   -- 'steam' | 'psn' | 'xbox' | 'switch' | 'device' | 'epic'
  platform_id text not null,   -- steamid64 / native id / EOS puid / device id
  account_id  uuid not null references accounts(id) on delete cascade,
  linked_at   timestamptz not null default now(),
  primary key (platform, platform_id)
);

create table if not exists save_objects (
  account_id     uuid not null references accounts(id) on delete cascade,
  slot           int  not null,
  schema_version int  not null default 1,
  checksum       text not null default '',
  updated_unix   bigint not null default 0,
  object_key     text not null,   -- R2 object key
  primary key (account_id, slot)
);

create table if not exists link_codes (
  code       text primary key,
  account_id uuid not null references accounts(id) on delete cascade,
  expires_at timestamptz not null
);
