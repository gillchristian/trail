package handlers

import (
	"encoding/json"
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

	// Follow redirects but stop before the final page — we just need the Location header
	client := &http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			// Check each redirect URL for the activity ID
			return nil
		},
	}

	resp, err := client.Get(shortURL)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to resolve short link"})
		return
	}
	defer resp.Body.Close()

	// The final URL after redirects should contain the activity ID
	finalURL := resp.Request.URL.String()
	match := activityIDPattern.FindStringSubmatch(finalURL)
	if match == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Could not extract activity ID from link"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"id": match[1]})
}
