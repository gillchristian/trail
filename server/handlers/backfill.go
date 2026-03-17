package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"cadence-server/store"
	"cadence-server/strava"
)

type BackfillHandler struct {
	Store         *store.TokenStore
	Strava        *strava.Client
	ActivityStore *store.ActivityStore

	mu      sync.Mutex
	running bool
}

type backfillStatusResponse struct {
	Running     bool `json:"running"`
	Complete    bool `json:"complete"`
	TotalStored int  `json:"total_stored"`
}

// TryStartBackfill checks if a backfill is needed and starts one in the background.
// Called from GetActivities after the incremental sync completes.
func (h *BackfillHandler) TryStartBackfill(tokens *store.Tokens) {
	complete, err := h.ActivityStore.IsBackfillComplete(tokens.AthleteID)
	if err != nil {
		log.Printf("Backfill status check error: %v", err)
		return
	}
	if complete {
		return
	}

	h.mu.Lock()
	if h.running {
		h.mu.Unlock()
		return
	}
	h.running = true
	h.mu.Unlock()

	go h.runBackfill(tokens)
}

func (h *BackfillHandler) runBackfill(tokens *store.Tokens) {
	defer func() {
		h.mu.Lock()
		h.running = false
		h.mu.Unlock()
	}()

	athleteID := tokens.AthleteID
	log.Printf("Starting backfill for athlete %d", athleteID)

	page := 1
	perPage := 200
	totalStored := 0

	// Count existing activities as starting point
	existing, err := h.ActivityStore.ActivityCount(athleteID)
	if err == nil {
		totalStored = existing
	}

	for {
		// Re-resolve access token each page to handle expiry
		accessToken, refreshed, err := h.Strava.GetValidAccessToken(tokens)
		if err != nil {
			log.Printf("Backfill token error on page %d: %v", page, err)
			return
		}
		if refreshed != nil {
			if err := h.Store.UpdateTokens(*refreshed); err != nil {
				log.Printf("Backfill token update error: %v", err)
			}
			tokens = refreshed
		}

		activities, err := h.Strava.FetchActivitiesPage(accessToken, page, perPage)
		if err != nil {
			log.Printf("Backfill fetch error on page %d: %v", page, err)
			return
		}

		if len(activities) > 0 {
			if err := h.ActivityStore.UpsertActivities(athleteID, activities); err != nil {
				log.Printf("Backfill upsert error on page %d: %v", page, err)
				return
			}
			totalStored += len(activities)
			if err := h.ActivityStore.UpdateBackfillProgress(athleteID, totalStored); err != nil {
				log.Printf("Backfill progress update error: %v", err)
			}
		}

		log.Printf("Backfill page %d: fetched %d activities (total: %d)", page, len(activities), totalStored)

		if len(activities) < perPage {
			// Last page reached
			break
		}

		page++
		time.Sleep(2 * time.Second)
	}

	if err := h.ActivityStore.SetBackfillComplete(athleteID, totalStored); err != nil {
		log.Printf("Backfill complete error: %v", err)
		return
	}
	log.Printf("Backfill complete for athlete %d: %d activities", athleteID, totalStored)
}

// GetBackfillStatus returns the current backfill progress.
func (h *BackfillHandler) GetBackfillStatus(w http.ResponseWriter, r *http.Request) {
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

	progress, err := h.ActivityStore.GetBackfillProgress(tokens.AthleteID)
	if err != nil {
		log.Printf("Backfill status error: %v", err)
		http.Error(w, `{"error":"Internal server error"}`, http.StatusInternalServerError)
		return
	}

	h.mu.Lock()
	running := h.running
	h.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(backfillStatusResponse{
		Running:     running,
		Complete:    progress.Complete,
		TotalStored: progress.TotalStored,
	})
}
