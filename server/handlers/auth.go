package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"

	"cadence-server/store"
	"cadence-server/strava"
)

type AuthHandler struct {
	Store        *store.TokenStore
	AthleteStore *store.AthleteStore
	Strava       *strava.Client
	ClientID     string
	APIBaseURL   string
	FrontendURL  string
}

func getSessionToken(r *http.Request) string {
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(auth, "Bearer ") {
		return auth[7:]
	}
	return ""
}

func (h *AuthHandler) StravaRedirect(w http.ResponseWriter, r *http.Request) {
	redirectURI := h.APIBaseURL + "/auth/callback"
	u := fmt.Sprintf(
		"https://www.strava.com/oauth/authorize?client_id=%s&response_type=code&redirect_uri=%s&scope=activity:read_all&approval_prompt=auto",
		h.ClientID,
		url.QueryEscape(redirectURI),
	)
	http.Redirect(w, r, u, http.StatusFound)
}

func (h *AuthHandler) Callback(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "Missing authorization code", http.StatusBadRequest)
		return
	}

	result, err := h.Strava.ExchangeCodeForTokens(code)
	if err != nil {
		log.Printf("OAuth callback error: %v", err)
		http.Error(w, "Authentication failed", http.StatusInternalServerError)
		return
	}

	sessionToken, err := store.GenerateSessionToken()
	if err != nil {
		log.Printf("Session token generation error: %v", err)
		http.Error(w, "Authentication failed", http.StatusInternalServerError)
		return
	}

	if err := h.Store.SetTokens(result.Tokens, sessionToken); err != nil {
		log.Printf("Token store error: %v", err)
		http.Error(w, "Authentication failed", http.StatusInternalServerError)
		return
	}

	if result.AthleteName != "" {
		if err := h.AthleteStore.Upsert(result.Tokens.AthleteID, result.AthleteName); err != nil {
			log.Printf("Athlete name store error: %v", err)
		}
	}

	http.Redirect(w, r, h.FrontendURL+"/?token="+url.QueryEscape(sessionToken), http.StatusFound)
}

func (h *AuthHandler) Status(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	sessionToken := getSessionToken(r)
	if sessionToken == "" {
		json.NewEncoder(w).Encode(map[string]any{
			"authenticated": false,
			"athleteId":     nil,
		})
		return
	}

	tokens, err := h.Store.GetTokensBySession(sessionToken)
	if err != nil {
		log.Printf("Status check error: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if tokens == nil {
		json.NewEncoder(w).Encode(map[string]any{
			"authenticated": false,
			"athleteId":     nil,
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]any{
		"authenticated": true,
		"athleteId":     tokens.AthleteID,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	sessionToken := getSessionToken(r)
	if sessionToken != "" {
		if err := h.Store.ClearTokensBySession(sessionToken); err != nil {
			log.Printf("Logout error: %v", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"ok": true})
}
