package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"cadence-server/store"
	"cadence-server/strava"
)

type ActivitiesHandler struct {
	Store         *store.TokenStore
	Strava        *strava.Client
	ActivityStore *store.ActivityStore
}

func (h *ActivitiesHandler) GetActivities(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		log.Printf("Activities token check error: %v", err)
		http.Error(w, `{"error":"Internal server error"}`, http.StatusInternalServerError)
		return
	}
	if tokens == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	accessToken, refreshed, err := h.Strava.GetValidAccessToken(tokens)
	if err != nil {
		log.Printf("Activities access token error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to get access token"})
		return
	}

	if refreshed != nil {
		if err := h.Store.UpdateTokens(*refreshed); err != nil {
			log.Printf("Activities token update error: %v", err)
		}
	}

	// Parse ?days=N (default 30, clamp 1-365)
	days := 30
	if d, err := strconv.Atoi(r.URL.Query().Get("days")); err == nil && d > 0 && d <= 365 {
		days = d
	}

	// Incremental sync: only fetch new activities from Strava
	latestDate, err := h.ActivityStore.LatestStartDate(tokens.AthleteID)
	if err != nil {
		log.Printf("Activities latest date error: %v", err)
	}

	var after int64
	if latestDate == "" {
		// First sync: seed with 30 days
		after = time.Now().AddDate(0, 0, -30).Unix()
	} else {
		// Delta sync: from latest activity minus 1h overlap buffer
		t, err := time.Parse(time.RFC3339, latestDate)
		if err != nil {
			after = time.Now().AddDate(0, 0, -30).Unix()
		} else {
			after = t.Add(-1 * time.Hour).Unix()
		}
	}

	now := time.Now().Unix()
	stravaActivities, err := h.Strava.FetchActivities(accessToken, after, now)
	if err != nil {
		log.Printf("Activities fetch error: %v", err)
		// Non-fatal if we have cached data — continue to serve from SQLite
	}

	if len(stravaActivities) > 0 {
		if err := h.ActivityStore.UpsertActivities(tokens.AthleteID, stravaActivities); err != nil {
			log.Printf("Activities upsert error: %v", err)
		}
	}

	// Query cached activities for the requested day range
	since := time.Now().AddDate(0, 0, -days)
	runs, err := h.ActivityStore.GetRunActivities(tokens.AthleteID, since)
	if err != nil {
		log.Printf("Activities query error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to fetch activities"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if runs == nil {
		runs = []json.RawMessage{}
	}
	json.NewEncoder(w).Encode(runs)
}
