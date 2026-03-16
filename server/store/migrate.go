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
