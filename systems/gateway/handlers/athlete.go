package handlers

import (
	"log"
	"net/http"
	"time"

	"cadence-server/store"
	"cadence-server/strava"
)

const athleteCacheTTL = 24 * time.Hour

type AthleteHandler struct {
	Store  *store.TokenStore
	Strava *strava.Client
	Cache  *store.ActivityCacheStore

	now func() time.Time // injectable for tests
}

func (h *AthleteHandler) clock() time.Time {
	if h.now != nil {
		return h.now()
	}
	return time.Now()
}

func isAthleteCacheFresh(now time.Time, cachedAt int64, ttl time.Duration) bool {
	return now.Sub(time.Unix(cachedAt, 0)) < ttl
}

func (h *AthleteHandler) Get(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		writeJSONError(w, http.StatusUnauthorized, "Not authenticated")
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		log.Printf("Athlete token lookup error: %v", err)
		writeJSONError(w, http.StatusInternalServerError, "Internal server error")
		return
	}
	if tokens == nil {
		writeJSONError(w, http.StatusUnauthorized, "Not authenticated")
		return
	}

	now := h.clock()

	if entry, err := h.Cache.GetAthlete(tokens.AthleteID); err == nil && entry != nil {
		if isAthleteCacheFresh(now, entry.CachedAt, athleteCacheTTL) {
			w.Header().Set("X-Data-Source", "cache")
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write(entry.Data)
			return
		}
	} else if err != nil {
		log.Printf("Athlete cache read error: %v", err)
	}

	accessToken, refreshed, err := h.Strava.GetValidAccessToken(tokens)
	if err != nil {
		log.Printf("Athlete access token error: %v", err)
		writeJSONError(w, http.StatusInternalServerError, "Failed to get access token")
		return
	}
	if refreshed != nil {
		if err := h.Store.UpdateTokens(*refreshed); err != nil {
			log.Printf("Athlete token update error: %v", err)
		}
	}

	body, _, err := h.Strava.FetchAthlete(accessToken)
	if err != nil {
		log.Printf("Athlete fetch error: %v", err)
		writeJSONError(w, http.StatusBadGateway, "Failed to fetch athlete from Strava")
		return
	}

	if err := h.Cache.SetAthlete(tokens.AthleteID, body); err != nil {
		log.Printf("Athlete cache write error: %v", err)
	}

	w.Header().Set("X-Data-Source", "strava")
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(body)
}
