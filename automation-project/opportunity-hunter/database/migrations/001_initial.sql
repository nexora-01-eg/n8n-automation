-- 001_initial.sql — Opportunity Hunter schema (SQLite)
-- Conventions: UTC ISO timestamps, UNKNOWN for missing strings, NULL for unknown numbers/booleans.

CREATE TABLE IF NOT EXISTS opportunities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  source_item_id TEXT NOT NULL,
  url TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  normalized_description TEXT DEFAULT '',
  service_category TEXT DEFAULT 'Unknown',
  service_subcategory TEXT DEFAULT 'UNKNOWN',
  budget_type TEXT DEFAULT 'UNKNOWN',
  budget_min REAL,
  budget_max REAL,
  budget_currency TEXT DEFAULT 'UNKNOWN',
  deadline TEXT,
  deadline_text TEXT DEFAULT 'UNKNOWN',
  location TEXT DEFAULT 'UNKNOWN',
  remote INTEGER,
  company_name TEXT DEFAULT 'UNKNOWN',
  client_name TEXT DEFAULT 'UNKNOWN',
  client_type TEXT DEFAULT 'UNKNOWN',
  project_type TEXT DEFAULT 'UNKNOWN',
  skills TEXT DEFAULT '[]',
  technologies TEXT DEFAULT '[]',
  topics TEXT DEFAULT '[]',
  posted_at TEXT,
  discovered_at TEXT NOT NULL,
  opportunity_score INTEGER DEFAULT 0,
  confidence_score INTEGER DEFAULT 0,
  service_match_score INTEGER DEFAULT 0,
  budget_score INTEGER DEFAULT 0,
  freshness_score INTEGER DEFAULT 0,
  clarity_score INTEGER DEFAULT 0,
  remote_score INTEGER DEFAULT 0,
  client_signal_score INTEGER DEFAULT 0,
  missing_penalty INTEGER DEFAULT 0,
  risk_penalty INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW','REVIEWING','INTERESTED','APPLIED','CONTACTED','REPLIED','WON','LOST','REJECTED','ARCHIVED')),
  possible_duplicate INTEGER DEFAULT 0,
  ai_mode TEXT DEFAULT 'AI_DISABLED',
  ai_summary TEXT,
  raw_data TEXT DEFAULT '{}',
  fingerprint TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(source, source_item_id)
);
CREATE INDEX IF NOT EXISTS idx_opp_fingerprint ON opportunities(fingerprint);
CREATE INDEX IF NOT EXISTS idx_opp_status ON opportunities(status);
CREATE INDEX IF NOT EXISTS idx_opp_category ON opportunities(service_category);
CREATE INDEX IF NOT EXISTS idx_opp_score ON opportunities(opportunity_score DESC);
CREATE INDEX IF NOT EXISTS idx_opp_posted ON opportunities(posted_at);

CREATE TABLE IF NOT EXISTS status_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id),
  old_status TEXT NOT NULL,
  new_status TEXT NOT NULL,
  changed_at TEXT NOT NULL,
  note TEXT DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_hist_opp ON status_history(opportunity_id);

CREATE TABLE IF NOT EXISTS notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id),
  body TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notes_opp ON notes(opportunity_id);

CREATE TABLE IF NOT EXISTS runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  status TEXT DEFAULT 'running',
  sources_total INTEGER DEFAULT 0,
  items_found INTEGER DEFAULT 0,
  items_added INTEGER DEFAULT 0,
  duplicates INTEGER DEFAULT 0,
  rejected INTEGER DEFAULT 0,
  errors INTEGER DEFAULT 0,
  triggered_by TEXT DEFAULT 'manual'
);
CREATE TABLE IF NOT EXISTS run_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL REFERENCES runs(id),
  source TEXT NOT NULL,
  status TEXT DEFAULT 'success',
  items_found INTEGER DEFAULT 0,
  items_added INTEGER DEFAULT 0,
  error_type TEXT,
  error_message TEXT,
  started_at TEXT NOT NULL,
  finished_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_rs_run ON run_sources(run_id);
