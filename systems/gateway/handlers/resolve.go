package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"regexp"
)

var activityIDPattern = regexp.MustCompile(`strava\.com/activities/(\d+)`)

func (h *CompareHandler) ResolveShortLink(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not authenticated"})
		return
	}

	shortURL := r.URL.Query().Get("url")
	if shortURL == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Missing url parameter"})
		return
	}

	resp, err := http.Get(shortURL)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to resolve short link"})
		return
	}
	defer resp.Body.Close()

	// First check if HTTP redirects resolved to a strava.com/activities URL
	finalURL := resp.Request.URL.String()
	match := activityIDPattern.FindStringSubmatch(finalURL)
	if match != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"id": match[1]})
		return
	}

	// Branch.io deep links return HTML with the activity URL embedded in the page
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read response"})
		return
	}

	match = activityIDPattern.FindStringSubmatch(string(body))
	if match != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"id": match[1]})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	json.NewEncoder(w).Encode(map[string]string{"error": "Could not extract activity ID from link"})
}
