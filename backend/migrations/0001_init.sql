-- Bedrock canonical-account schema (Cloudflare D1, SQLite).
-- One account per human; platform identities (steam/psn/xbox/switch/device/epic)
-- link to it. Save metadata lives here, blobs in R2 keyed by account + slot.
-- Timestamps are unix seconds.

create table if not exists accounts (
  id           text primary key,
  display_name text not null default '',
  created_at   integer not null default (unixepoch())
);

create table if not exists platform_links (
  platform    text not null,   -- 'steam' | 'psn' | 'xbox' | 'switch' | 'device' | 'epic'
  platform_id text not null,   -- steamid64 / native id / EOS puid / device id
  account_id  text not null references accounts(id) on delete cascade,
  linked_at   integer not null default (unixepoch()),
  primary key (platform, platform_id)
);

create table if not exists save_objects (
  account_id     text not null references accounts(id) on delete cascade,
  slot           integer not null,
  schema_version integer not null default 1,
  checksum       text not null default '',
  updated_unix   integer not null default 0,
  blob_key       text not null,   -- R2 object key
  primary key (account_id, slot)
);

create table if not exists link_codes (
  code       text primary key,
  account_id text not null references accounts(id) on delete cascade,
  expires_at integer not null
);
