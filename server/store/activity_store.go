package store

import (
	"database/sql"
	"encoding/json"
	"time"
)

type ActivityStore struct {
	db *sql.DB
}

func NewActivityStore(db *sql.DB) *ActivityStore {
	return &ActivityStore{db: db}
}

// LatestStartDate returns the most recent start_date for this athlete,
// or "" if no activities are stored.
func (s *ActivityStore) LatestStartDate(athleteID int64) (string, error) {
	var date string
	err := s.db.QueryRow(
		"SELECT start_date FROM activities WHERE athlete_id = ? ORDER BY start_date DESC LIMIT 1",
		athleteID,
	).Scan(&date)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return date, nil
}

// UpsertActivities inserts or updates activities from raw Strava JSON blobs.
// Stores all activity types (filtering happens at query time).
func (s *ActivityStore) UpsertActivities(athleteID int64, activities []json.RawMessage) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT INTO activities (activity_id, athlete_id, type, sport_type, start_date, raw_json, cached_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(athlete_id, activity_id) DO UPDATE SET
			type = excluded.type,
			sport_type = excluded.sport_type,
			start_date = excluded.start_date,
			raw_json = excluded.raw_json,
			cached_at = excluded.cached_at`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	now := time.Now().Unix()
	for _, raw := range activities {
		var meta struct {
			ID        int64  `json:"id"`
			Type      string `json:"type"`
			SportType string `json:"sport_type"`
			StartDate string `json:"start_date"`
		}
		if err := json.Unmarshal(raw, &meta); err != nil {
			continue
		}
		if _, err := stmt.Exec(meta.ID, athleteID, meta.Type, meta.SportType, meta.StartDate, string(raw), now); err != nil {
			return err
		}
	}

	return tx.Commit()
}

// GetRunActivities returns running activities for this athlete since the given time.
func (s *ActivityStore) GetRunActivities(athleteID int64, since time.Time) ([]json.RawMessage, error) {
	sinceStr := since.UTC().Format(time.RFC3339)
	rows, err := s.db.Query(`
		SELECT raw_json FROM activities
		WHERE athlete_id = ?
		  AND start_date >= ?
		  AND (type IN ('Run', 'TrailRun', 'VirtualRun') OR sport_type IN ('Run', 'TrailRun', 'VirtualRun'))
		ORDER BY start_date DESC`,
		athleteID, sinceStr,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []json.RawMessage
	for rows.Next() {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return nil, err
		}
		results = append(results, json.RawMessage(raw))
	}
	return results, rows.Err()
}
