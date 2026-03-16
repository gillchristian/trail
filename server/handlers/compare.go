package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"cadence-server/store"
	"cadence-server/strava"

	"github.com/go-chi/chi/v5"
)

type CompareHandler struct {
	Store         *store.TokenStore
	Strava        *strava.Client
	ActivityCache *store.ActivityCacheStore
}

type activityResponse struct {
	ID             int64   `json:"id"`
	Name           string  `json:"name"`
	Distance       float64 `json:"distance"`
	MovingTime     int     `json:"moving_time"`
	StartDateLocal string  `json:"start_date_local"`
	Type           string  `json:"type"`
}

type splitResponse struct {
	Km                  int      `json:"km"`
	Distance            float64  `json:"distance"`
	ElapsedTime         int      `json:"elapsed_time"`
	MovingTime          int      `json:"moving_time"`
	AverageSpeed        float64  `json:"average_speed"`
	ElevationDifference float64  `json:"elevation_difference"`
	AverageHeartrate    *float64 `json:"average_heartrate"`
}

type detailResponse struct {
	Activity activityResponse `json:"activity"`
	Splits   []splitResponse  `json:"splits"`
}

func computePerKmHeartRate(streams *strava.ActivityStreams, numSplits int) []*float64 {
	result := make([]*float64, numSplits)
	if streams == nil || len(streams.Distance) == 0 || len(streams.Heartrate) == 0 {
		return result
	}

	distData := streams.Distance
	hrData := streams.Heartrate
	streamIdx := 0

	for km := 0; km < numSplits; km++ {
		boundary := float64((km + 1) * 1000)
		var sum float64
		var count int

		for streamIdx < len(distData) && distData[streamIdx] < boundary {
			if streamIdx < len(hrData) {
				sum += hrData[streamIdx]
				count++
			}
			streamIdx++
		}

		// For the last split, include remaining data points
		if km == numSplits-1 {
			for streamIdx < len(distData) {
				if streamIdx < len(hrData) {
					sum += hrData[streamIdx]
					count++
				}
				streamIdx++
			}
		}

		if count > 0 {
			avg := sum / float64(count)
			result[km] = &avg
		}
	}

	return result
}


func (h *CompareHandler) fetchAndCacheActivity(accessToken string, activityID int64) ([]byte, error) {
	detail, err := h.Strava.FetchActivityDetail(accessToken, activityID)
	if err != nil {
		return nil, err
	}

	log.Printf("Activity %d: has_heartrate=%v, splits=%d", activityID, detail.HasHeartrate, len(detail.SplitsMetric))

	splitsHaveHR := false
	for _, s := range detail.SplitsMetric {
		if s.AverageHeartrate != nil {
			splitsHaveHR = true
			break
		}
	}

	var perKmHR []*float64
	if splitsHaveHR {
		log.Printf("Activity %d: using HR from splits_metric", activityID)
	} else {
		streams, err := h.Strava.FetchActivityStreams(accessToken, activityID)
		if err != nil {
			log.Printf("Activity %d: streams fetch error (non-fatal): %v", activityID, err)
		} else {
			log.Printf("Activity %d: streams fetched, distance=%d points, heartrate=%d points",
				activityID, len(streams.Distance), len(streams.Heartrate))
		}
		perKmHR = computePerKmHeartRate(streams, len(detail.SplitsMetric))
	}

	splits := make([]splitResponse, len(detail.SplitsMetric))
	for i, s := range detail.SplitsMetric {
		var hr *float64
		if splitsHaveHR {
			hr = s.AverageHeartrate
		} else if perKmHR != nil {
			hr = perKmHR[i]
		}
		splits[i] = splitResponse{
			Km:                  s.Split,
			Distance:            s.Distance,
			ElapsedTime:         s.ElapsedTime,
			MovingTime:          s.MovingTime,
			AverageSpeed:        s.AverageSpeed,
			ElevationDifference: s.ElevationDifference,
			AverageHeartrate:    hr,
		}
	}

	resp := detailResponse{
		Activity: activityResponse{
			ID:             detail.ID,
			Name:           detail.Name,
			Distance:       detail.Distance,
			MovingTime:     detail.MovingTime,
			StartDateLocal: detail.StartDateLocal,
			Type:           detail.Type,
		},
		Splits: splits,
	}

	respJSON, err := json.Marshal(resp)
	if err != nil {
		return nil, err
	}

	if err := h.ActivityCache.Set(activityID, respJSON); err != nil {
		log.Printf("Cache write error for activity %d: %v", activityID, err)
	}

	return respJSON, nil
}

func (h *CompareHandler) refreshActivityCache(accessToken string, activityID int64) {
	log.Printf("Background revalidation for activity %d", activityID)
	if _, err := h.fetchAndCacheActivity(accessToken, activityID); err != nil {
		log.Printf("Background revalidation error for activity %d: %v", activityID, err)
	}
}

func (h *CompareHandler) GetActivityDetail(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	activityID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid activity ID"})
		return
	}

	// Serve from cache if available (for all users, authenticated or not)
	entry, err := h.ActivityCache.Get(activityID)
	if err != nil {
		log.Printf("Cache read error for activity %d: %v", activityID, err)
	}
	if entry != nil {
		w.Header().Set("X-Data-Source", "cache")
		w.Header().Set("Content-Type", "application/json")
		w.Write(entry.Data)

		// Check if cache is stale and we can revalidate in the background
		if sessionToken := getSessionToken(r); sessionToken != "" {
			if h.isStale(entry) {
				go func() {
					accessToken, err := h.resolveAccessToken(sessionToken)
					if err != nil {
						log.Printf("Background revalidation auth error for activity %d: %v", activityID, err)
						return
					}
					h.refreshActivityCache(accessToken, activityID)
				}()
			}
		}
		return
	}

	// Cache miss — need Strava auth to fetch
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Activity not found. It must be viewed by an authenticated user first.",
		})
		return
	}

	accessToken, err := h.resolveAccessToken(sessionToken)
	if err != nil {
		log.Printf("Compare access token error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to get access token"})
		return
	}
	if accessToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Activity not found. It must be viewed by an authenticated user first.",
		})
		return
	}

	respJSON, err := h.fetchAndCacheActivity(accessToken, activityID)
	if err != nil {
		log.Printf("Compare activity detail error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Activity not found or not accessible"})
		return
	}

	w.Header().Set("X-Data-Source", "strava")
	w.Header().Set("Content-Type", "application/json")
	w.Write(respJSON)
}

func (h *CompareHandler) isStale(entry *store.CacheEntry) bool {
	// Parse start_date_local from cached JSON to determine activity age
	var cached struct {
		Activity struct {
			StartDateLocal string `json:"start_date_local"`
		} `json:"activity"`
	}
	if err := json.Unmarshal(entry.Data, &cached); err != nil {
		return false // can't parse, don't revalidate
	}

	activityTime, err := time.Parse(time.RFC3339, cached.Activity.StartDateLocal)
	if err != nil {
		return false
	}

	now := time.Now()
	activityAge := now.Sub(activityTime)
	cacheAge := now.Sub(time.Unix(entry.CachedAt, 0))

	// Only revalidate recent activities (<24h old) with stale cache (>1h)
	if activityAge < 24*time.Hour {
		return cacheAge > 1*time.Hour
	}

	return false
}

func (h *CompareHandler) resolveAccessToken(sessionToken string) (string, error) {
	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		return "", err
	}
	if tokens == nil {
		return "", nil
	}

	accessToken, refreshed, err := h.Strava.GetValidAccessToken(tokens)
	if err != nil {
		return "", err
	}

	if refreshed != nil {
		if err := h.Store.UpdateTokens(*refreshed); err != nil {
			log.Printf("Token update error: %v", err)
		}
	}

	return accessToken, nil
}
