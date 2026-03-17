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
	Backfill      *BackfillHandler
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
			// Always re-fetch at least the last 24h to catch metadata changes
		afterLatest := t.Add(-1 * time.Hour).Unix()
		oneDayAgo := time.Now().Add(-24 * time.Hour).Unix()
		after = min(afterLatest, oneDayAgo)
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

	// Auto-trigger backfill if not yet complete
	if h.Backfill != nil {
		h.Backfill.TryStartBackfill(tokens)
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

	if len(stravaActivities) > 0 {
		w.Header().Set("X-Data-Source", "strava")
	} else {
		w.Header().Set("X-Data-Source", "cache")
	}
	w.Header().Set("Content-Type", "application/json")
	if runs == nil {
		runs = []json.RawMessage{}
	}
	json.NewEncoder(w).Encode(runs)
}

func (h *ActivitiesHandler) SearchActivities(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil || tokens == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	q := r.URL.Query()
	params := store.SearchParams{
		AthleteID: tokens.AthleteID,
		NameQuery: q.Get("q"),
		Limit:     50,
	}

	if v, err := strconv.ParseFloat(q.Get("min_distance"), 64); err == nil {
		params.MinDistance = v
	}
	if v, err := strconv.ParseFloat(q.Get("max_distance"), 64); err == nil {
		params.MaxDistance = v
	}
	if v, err := strconv.Atoi(q.Get("limit")); err == nil && v > 0 {
		params.Limit = v
	}
	if v, err := strconv.Atoi(q.Get("offset")); err == nil && v >= 0 {
		params.Offset = v
	}

	results, total, err := h.ActivityStore.SearchActivities(params)
	if err != nil {
		log.Printf("Search error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Search failed"})
		return
	}

	if results == nil {
		results = []store.ActivitySearchResult{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"activities": results,
		"total":      total,
		"limit":      params.Limit,
		"offset":     params.Offset,
	})
}
