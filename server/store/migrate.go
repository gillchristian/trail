package store

import (
	"database/sql"
	"log"
	"time"

	_ "modernc.org/sqlite"
)

func OpenDB(dbPath string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	if err := RunMigrations(db); err != nil {
		return nil, err
	}

	return db, nil
}

type Migration struct {
	ID  string
	SQL string
}

var migrations = []Migration{
	{
		ID: "001_create_migrations_table",
		SQL: `CREATE TABLE IF NOT EXISTS migrations (
			id TEXT PRIMARY KEY,
			applied_at INTEGER NOT NULL
		)`,
	},
	{
		ID: "002_create_tokens_table",
		SQL: `CREATE TABLE IF NOT EXISTS tokens (
			athlete_id INTEGER PRIMARY KEY,
			session_token TEXT NOT NULL UNIQUE,
			access_token TEXT NOT NULL,
			refresh_token TEXT NOT NULL,
			expires_at INTEGER NOT NULL
		)`,
	},
	{
		ID: "003_create_activity_cache_table",
		SQL: `CREATE TABLE IF NOT EXISTS activity_cache (
			activity_id INTEGER PRIMARY KEY,
			response_json TEXT NOT NULL,
			cached_at INTEGER NOT NULL
		)`,
	},
	{
		ID: "004_create_activities_table",
		SQL: `CREATE TABLE IF NOT EXISTS activities (
			activity_id INTEGER NOT NULL,
			athlete_id  INTEGER NOT NULL,
			type        TEXT NOT NULL DEFAULT '',
			sport_type  TEXT NOT NULL DEFAULT '',
			start_date  TEXT NOT NULL,
			raw_json    TEXT NOT NULL,
			cached_at   INTEGER NOT NULL,
			PRIMARY KEY (athlete_id, activity_id)
		)`,
	},
	{
		ID:  "005_create_activities_index",
		SQL: `CREATE INDEX IF NOT EXISTS idx_activities_athlete_date ON activities (athlete_id, start_date)`,
	},
	{
		ID:  "006_add_distance_column",
		SQL: `ALTER TABLE activities ADD COLUMN distance REAL NOT NULL DEFAULT 0`,
	},
	{
		ID:  "007_add_name_column",
		SQL: `ALTER TABLE activities ADD COLUMN name TEXT NOT NULL DEFAULT ''`,
	},
	{
		ID:  "008_backfill_distance_name",
		SQL: `UPDATE activities SET distance = COALESCE(json_extract(raw_json, '$.distance'), 0), name = COALESCE(json_extract(raw_json, '$.name'), '') WHERE distance = 0 OR name = ''`,
	},
	{
		ID:  "009_index_athlete_distance",
		SQL: `CREATE INDEX IF NOT EXISTS idx_activities_athlete_distance ON activities (athlete_id, distance)`,
	},
	{
		ID: "010_create_backfill_status",
		SQL: `CREATE TABLE IF NOT EXISTS backfill_status (
			athlete_id INTEGER PRIMARY KEY,
			complete INTEGER NOT NULL DEFAULT 0,
			total_stored INTEGER NOT NULL DEFAULT 0,
			updated_at INTEGER NOT NULL
		)`,
	},
	{
		ID: "012_create_athletes_table",
		SQL: `CREATE TABLE IF NOT EXISTS athletes (
			athlete_id INTEGER PRIMARY KEY,
			name TEXT NOT NULL DEFAULT ''
		)`,
	},
	{
		ID: "011_create_activities_fts",
		SQL: `CREATE VIRTUAL TABLE IF NOT EXISTS activities_fts USING fts5(
			name,
			content='activities',
			content_rowid='rowid',
			tokenize='trigram'
		);
		INSERT INTO activities_fts(rowid, name) SELECT rowid, name FROM activities;
		CREATE TRIGGER IF NOT EXISTS activities_fts_insert AFTER INSERT ON activities BEGIN
			INSERT INTO activities_fts(rowid, name) VALUES (new.rowid, new.name);
		END;
		CREATE TRIGGER IF NOT EXISTS activities_fts_update AFTER UPDATE OF name ON activities BEGIN
			INSERT INTO activities_fts(activities_fts, rowid, name) VALUES('delete', old.rowid, old.name);
			INSERT INTO activities_fts(rowid, name) VALUES (new.rowid, new.name);
		END`,
	},
}

func RunMigrations(db *sql.DB) error {
	// Bootstrap: run the migrations table creation unconditionally (idempotent)
	if _, err := db.Exec(migrations[0].SQL); err != nil {
		return err
	}

	for _, m := range migrations {
		var exists int
		err := db.QueryRow("SELECT 1 FROM migrations WHERE id = ?", m.ID).Scan(&exists)
		if err == nil {
			continue // already applied
		}
		if err != sql.ErrNoRows {
			return err
		}

		if _, err := db.Exec(m.SQL); err != nil {
			return err
		}
		if _, err := db.Exec(
			"INSERT INTO migrations (id, applied_at) VALUES (?, ?)",
			m.ID, time.Now().Unix(),
		); err != nil {
			return err
		}
		log.Printf("Applied migration %s", m.ID)
	}

	return nil
}
