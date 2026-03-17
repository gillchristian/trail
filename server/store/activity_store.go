package store

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
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
		INSERT INTO activities (activity_id, athlete_id, type, sport_type, start_date, distance, name, raw_json, cached_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(athlete_id, activity_id) DO UPDATE SET
			type = excluded.type,
			sport_type = excluded.sport_type,
			start_date = excluded.start_date,
			distance = excluded.distance,
			name = excluded.name,
			raw_json = excluded.raw_json,
			cached_at = excluded.cached_at`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	now := time.Now().Unix()
	for _, raw := range activities {
		var meta struct {
			ID        int64   `json:"id"`
			Type      string  `json:"type"`
			SportType string  `json:"sport_type"`
			StartDate string  `json:"start_date"`
			Distance  float64 `json:"distance"`
			Name      string  `json:"name"`
		}
		if err := json.Unmarshal(raw, &meta); err != nil {
			continue
		}
		if _, err := stmt.Exec(meta.ID, athleteID, meta.Type, meta.SportType, meta.StartDate, meta.Distance, meta.Name, string(raw), now); err != nil {
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

// SearchParams defines filters for searching activities.
type SearchParams struct {
	AthleteID  int64
	MinDistance float64 // meters
	MaxDistance float64 // meters, 0 = no upper bound
	NameQuery  string  // LIKE search
	Limit      int     // default 50
	Offset     int
}

// ActivitySearchResult is a lightweight activity for search results.
type ActivitySearchResult struct {
	ID             int64   `json:"id"`
	Name           string  `json:"name"`
	Distance       float64 `json:"distance"`
	MovingTime     int     `json:"moving_time"`
	StartDateLocal string  `json:"start_date_local"`
	SportType      string  `json:"sport_type"`
}

// SearchActivities returns run activities matching the given filters.
func (s *ActivityStore) SearchActivities(params SearchParams) ([]ActivitySearchResult, int, error) {
	if params.Limit <= 0 {
		params.Limit = 50
	}
	if params.Limit > 100 {
		params.Limit = 100
	}

	where := []string{
		"athlete_id = ?",
		"(type IN ('Run', 'TrailRun', 'VirtualRun') OR sport_type IN ('Run', 'TrailRun', 'VirtualRun'))",
	}
	args := []any{params.AthleteID}

	if params.MinDistance > 0 {
		where = append(where, "distance >= ?")
		args = append(args, params.MinDistance)
	}
	if params.MaxDistance > 0 {
		where = append(where, "distance <= ?")
		args = append(args, params.MaxDistance)
	}
	if params.NameQuery != "" {
		where = append(where, "name LIKE ? COLLATE NOCASE")
		args = append(args, "%"+params.NameQuery+"%")
	}

	whereClause := strings.Join(where, " AND ")

	// Count total matches
	var total int
	countSQL := fmt.Sprintf("SELECT COUNT(*) FROM activities WHERE %s", whereClause)
	if err := s.db.QueryRow(countSQL, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	// Fetch page
	querySQL := fmt.Sprintf(`
		SELECT activity_id, name, distance,
			COALESCE(json_extract(raw_json, '$.moving_time'), 0),
			COALESCE(json_extract(raw_json, '$.start_date_local'), ''),
			sport_type
		FROM activities
		WHERE %s
		ORDER BY start_date DESC
		LIMIT ? OFFSET ?`, whereClause)

	queryArgs := append(args, params.Limit, params.Offset)
	rows, err := s.db.Query(querySQL, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var results []ActivitySearchResult
	for rows.Next() {
		var r ActivitySearchResult
		if err := rows.Scan(&r.ID, &r.Name, &r.Distance, &r.MovingTime, &r.StartDateLocal, &r.SportType); err != nil {
			return nil, 0, err
		}
		results = append(results, r)
	}
	return results, total, rows.Err()
}

// IsBackfillComplete checks if full history backfill has completed for this athlete.
func (s *ActivityStore) IsBackfillComplete(athleteID int64) (bool, error) {
	var complete int
	err := s.db.QueryRow("SELECT complete FROM backfill_status WHERE athlete_id = ?", athleteID).Scan(&complete)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return complete == 1, nil
}

// UpdateBackfillProgress updates the backfill progress for an athlete.
func (s *ActivityStore) UpdateBackfillProgress(athleteID int64, totalStored int) error {
	_, err := s.db.Exec(`
		INSERT INTO backfill_status (athlete_id, complete, total_stored, updated_at)
		VALUES (?, 0, ?, ?)
		ON CONFLICT(athlete_id) DO UPDATE SET
			total_stored = excluded.total_stored,
			updated_at = excluded.updated_at`,
		athleteID, totalStored, time.Now().Unix(),
	)
	return err
}

// SetBackfillComplete marks the backfill as done for an athlete.
func (s *ActivityStore) SetBackfillComplete(athleteID int64, totalStored int) error {
	_, err := s.db.Exec(`
		INSERT INTO backfill_status (athlete_id, complete, total_stored, updated_at)
		VALUES (?, 1, ?, ?)
		ON CONFLICT(athlete_id) DO UPDATE SET
			complete = 1,
			total_stored = excluded.total_stored,
			updated_at = excluded.updated_at`,
		athleteID, totalStored, time.Now().Unix(),
	)
	return err
}

// BackfillProgress represents the backfill state for an athlete.
type BackfillProgress struct {
	Complete    bool `json:"complete"`
	TotalStored int  `json:"total_stored"`
}

// GetBackfillProgress returns the current backfill state for an athlete.
func (s *ActivityStore) GetBackfillProgress(athleteID int64) (*BackfillProgress, error) {
	var complete int
	var totalStored int
	err := s.db.QueryRow("SELECT complete, total_stored FROM backfill_status WHERE athlete_id = ?", athleteID).Scan(&complete, &totalStored)
	if err == sql.ErrNoRows {
		return &BackfillProgress{}, nil
	}
	if err != nil {
		return nil, err
	}
	return &BackfillProgress{Complete: complete == 1, TotalStored: totalStored}, nil
}

// ActivityCount returns the total number of activities stored for an athlete.
func (s *ActivityStore) ActivityCount(athleteID int64) (int, error) {
	var count int
	err := s.db.QueryRow("SELECT COUNT(*) FROM activities WHERE athlete_id = ?", athleteID).Scan(&count)
	return count, err
}
