-- glance-feed's cache: the one place the desktop's network data lives between fetches and boots.
-- Read by the bar, the glance band and the lock screen through `glance-feed read <name>`.
PRAGMA journal_mode = WAL;

-- Conditional GET: per URL its validator and its last body, so an unchanged resource is a 304.
CREATE TABLE IF NOT EXISTS http_cache (
  url        TEXT PRIMARY KEY,
  etag       TEXT,
  body       TEXT,
  fetched_at INTEGER, -- the last 200
  checked_at INTEGER  -- the last answer of any kind
);

-- What the UI reads: one ready document per source. updated_at moves ONLY when the content does.
CREATE TABLE IF NOT EXISTS feed (
  name       TEXT PRIMARY KEY,
  json       TEXT NOT NULL,
  source     TEXT,
  updated_at INTEGER NOT NULL,
  checked_at INTEGER NOT NULL,
  error      TEXT -- the last failure, NULL once a fetch succeeds again
);

-- The scheduler's memory: when each source is due, the last model run seen, the alerts' digest.
CREATE TABLE IF NOT EXISTS state (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- What the network actually cost, per source per day: the proof the cache is working.
CREATE TABLE IF NOT EXISTS traffic (
  day          TEXT NOT NULL,
  source       TEXT NOT NULL,
  bytes        INTEGER NOT NULL DEFAULT 0,
  requests     INTEGER NOT NULL DEFAULT 0,
  not_modified INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, source)
);

-- The house's devices as ever seen, for "a device never seen before". Inventory, not a log: kept.
CREATE TABLE IF NOT EXISTS devices (
  mac        TEXT PRIMARY KEY,
  name       TEXT,
  first_seen INTEGER NOT NULL, -- 0 = already there when the inventory started (the baseline)
  last_seen  INTEGER NOT NULL,
  last_ip    TEXT
);
