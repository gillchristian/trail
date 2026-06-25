package store

import "database/sql"

type AthleteStore struct {
	db *sql.DB
}

func NewAthleteStore(db *sql.DB) *AthleteStore {
	return &AthleteStore{db: db}
}

func (s *AthleteStore) Upsert(athleteID int64, name string) error {
	_, err := s.db.Exec(
		`INSERT INTO athletes (athlete_id, name) VALUES (?, ?)
		 ON CONFLICT(athlete_id) DO UPDATE SET name = excluded.name`,
		athleteID, name,
	)
	return err
}

func (s *AthleteStore) GetName(athleteID int64) (string, error) {
	var name string
	err := s.db.QueryRow("SELECT name FROM athletes WHERE athlete_id = ?", athleteID).Scan(&name)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return name, err
}
