package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"

	"cadence-server/store"
	"cadence-server/strava"

	"github.com/go-chi/chi/v5"
)

// allowedStreamKeys mirrors Strava's documented stream-key set.
// https://developers.strava.com/docs/reference/#api-Streams-getActivityStreams
var allowedStreamKeys = map[string]struct{}{
	"time":                 {},
	"distance":             {},
	"latlng":               {},
	"altitude":             {},
	"heartrate":            {},
	"cadence":              {},
	"watts":                {},
	"velocity_smooth":      {},
	"grade_smooth":         {},
	"temp":                 {},
	"moving":               {},
	"grade_adjusted_speed": {},
}

type StreamsHandler struct {
	Store  *store.TokenStore
	Strava *strava.Client
}

func writeJSONError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// validateStreamKeys parses the comma-separated keys param, returning
// the cleaned list. On the first unknown key it returns (key, false)
// so the caller can build a 400 message naming it.
func validateStreamKeys(raw string) (keys []string, badKey string, ok bool) {
	if raw == "" {
		return nil, "", false
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if _, allowed := allowedStreamKeys[p]; !allowed {
			return nil, p, false
		}
		out = append(out, p)
	}
	if len(out) == 0 {
		return nil, "", false
	}
	return out, "", true
}

func (h *StreamsHandler) Get(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		writeJSONError(w, http.StatusUnauthorized, "Not authenticated")
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		log.Printf("Streams token lookup error: %v", err)
		writeJSONError(w, http.StatusInternalServerError, "Internal server error")
		return
	}
	if tokens == nil {
		writeJSONError(w, http.StatusUnauthorized, "Not authenticated")
		return
	}

	activityID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "Invalid activity ID")
		return
	}

	keys, badKey, ok := validateStreamKeys(r.URL.Query().Get("keys"))
	if !ok {
		if badKey != "" {
			writeJSONError(w, http.StatusBadRequest, "unknown stream key: "+badKey)
		} else {
			writeJSONError(w, http.StatusBadRequest, "missing required parameter: keys")
		}
		return
	}

	accessToken, refreshed, err := h.Strava.GetValidAccessToken(tokens)
	if err != nil {
		log.Printf("Streams access token error: %v", err)
		writeJSONError(w, http.StatusInternalServerError, "Failed to get access token")
		return
	}
	if refreshed != nil {
		if err := h.Store.UpdateTokens(*refreshed); err != nil {
			log.Printf("Streams token update error: %v", err)
		}
	}

	body, _, err := h.Strava.FetchActivityStreamsRaw(accessToken, activityID, keys)
	if err != nil {
		log.Printf("Streams fetch error (activity %d): %v", activityID, err)
		writeJSONError(w, http.StatusBadGateway, "Failed to fetch streams from Strava")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(body)
}
