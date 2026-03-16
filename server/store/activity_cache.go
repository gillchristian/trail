package store

import (
	"database/sql"
	"time"
)

type ActivityCacheStore struct {
	db *sql.DB
}

func NewActivityCacheStore(db *sql.DB) *ActivityCacheStore {
	return &ActivityCacheStore{db: db}
}

func (s *ActivityCacheStore) Get(activityID int64) ([]byte, error) {
	var jsonData string
	err := s.db.QueryRow(
		"SELECT response_json FROM activity_cache WHERE activity_id = ?",
		activityID,
	).Scan(&jsonData)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return []byte(jsonData), nil
}

func (s *ActivityCacheStore) Set(activityID int64, responseJSON []byte) error {
	_, err := s.db.Exec(
		`INSERT INTO activity_cache (activity_id, response_json, cached_at)
		 VALUES (?, ?, ?)
		 ON CONFLICT(activity_id) DO UPDATE SET
		    response_json = excluded.response_json,
		    cached_at = excluded.cached_at`,
		activityID, string(responseJSON), time.Now().Unix(),
	)
	return err
}
