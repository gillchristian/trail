package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"cadence-server/store"
	"cadence-server/strava"

	"github.com/go-chi/chi/v5"
)

type CompareHandler struct {
	Store  *store.TokenStore
	Strava *strava.Client
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

func (h *CompareHandler) GetActivityDetail(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		log.Printf("Compare token check error: %v", err)
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
		log.Printf("Compare access token error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to get access token"})
		return
	}

	if refreshed != nil {
		if err := h.Store.UpdateTokens(*refreshed); err != nil {
			log.Printf("Compare token update error: %v", err)
		}
	}

	idStr := chi.URLParam(r, "id")
	activityID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid activity ID"})
		return
	}

	detail, err := h.Strava.FetchActivityDetail(accessToken, activityID)
	if err != nil {
		log.Printf("Compare activity detail error: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Activity not found or not accessible"})
		return
	}

	// Fetch streams for HR computation (best effort — activity may lack HR)
	var streams *strava.ActivityStreams
	if detail.HasHeartrate {
		streams, err = h.Strava.FetchActivityStreams(accessToken, activityID)
		if err != nil {
			log.Printf("Compare streams fetch error (non-fatal): %v", err)
		}
	}

	perKmHR := computePerKmHeartRate(streams, len(detail.SplitsMetric))

	splits := make([]splitResponse, len(detail.SplitsMetric))
	for i, s := range detail.SplitsMetric {
		splits[i] = splitResponse{
			Km:                  s.Split,
			Distance:            s.Distance,
			ElapsedTime:         s.ElapsedTime,
			MovingTime:          s.MovingTime,
			AverageSpeed:        s.AverageSpeed,
			ElevationDifference: s.ElevationDifference,
			AverageHeartrate:    perKmHR[i],
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

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}
