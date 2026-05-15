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
	FrontendURL  string            // legacy fallback redirect target
	FrontendURLs map[string]string // origin -> redirect URL (overrides FrontendURL)
	OAuthState   *OAuthStateStore
}

func getSessionToken(r *http.Request) string {
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(auth, "Bearer ") {
		return auth[7:]
	}
	return ""
}

func (h *AuthHandler) redirectURLFor(origin string) string {
	if u, ok := h.FrontendURLs[origin]; ok && u != "" {
		return u
	}
	return h.FrontendURL
}

func (h *AuthHandler) StravaRedirect(w http.ResponseWriter, r *http.Request) {
	origin := r.URL.Query().Get("origin")
	if origin == "" {
		origin = OriginCadence
	}
	if !IsAllowedOrigin(origin) {
		http.Error(w, "Unknown origin", http.StatusBadRequest)
		return
	}

	nonce, err := newOAuthNonce()
	if err != nil {
		log.Printf("OAuth nonce error: %v", err)
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}
	h.OAuthState.Put(nonce, origin)

	state, err := encodeOAuthState(nonce, origin)
	if err != nil {
		log.Printf("OAuth state encode error: %v", err)
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}

	redirectURI := h.APIBaseURL + "/auth/callback"
	u := fmt.Sprintf(
		"https://www.strava.com/oauth/authorize?client_id=%s&response_type=code&redirect_uri=%s&scope=activity:read_all&approval_prompt=auto&state=%s",
		h.ClientID,
		url.QueryEscape(redirectURI),
		url.QueryEscape(state),
	)
	http.Redirect(w, r, u, http.StatusFound)
}

func (h *AuthHandler) Callback(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "Missing authorization code", http.StatusBadRequest)
		return
	}

	rawState := r.URL.Query().Get("state")
	if rawState == "" {
		http.Error(w, "Missing OAuth state", http.StatusBadRequest)
		return
	}

	nonce, stateOrigin, err := decodeOAuthState(rawState)
	if err != nil {
		log.Printf("OAuth state decode error: %v", err)
		http.Error(w, "Invalid OAuth state", http.StatusBadRequest)
		return
	}

	storedOrigin, err := h.OAuthState.Take(nonce)
	if err != nil {
		log.Printf("OAuth nonce verification failed: %v", err)
		http.Error(w, "Invalid or expired OAuth state", http.StatusBadRequest)
		return
	}
	if storedOrigin != stateOrigin {
		log.Printf("OAuth origin mismatch: state=%s stored=%s", stateOrigin, storedOrigin)
		http.Error(w, "OAuth state mismatch", http.StatusBadRequest)
		return
	}
	if !IsAllowedOrigin(stateOrigin) {
		http.Error(w, "Unknown origin", http.StatusBadRequest)
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

	if err := h.Store.SetTokens(result.Tokens, sessionToken, stateOrigin); err != nil {
		log.Printf("Token store error: %v", err)
		http.Error(w, "Authentication failed", http.StatusInternalServerError)
		return
	}

	if result.AthleteName != "" {
		if err := h.AthleteStore.Upsert(result.Tokens.AthleteID, result.AthleteName); err != nil {
			log.Printf("Athlete name store error: %v", err)
		}
	}

	http.Redirect(w, r, h.redirectURLFor(stateOrigin)+"/?token="+url.QueryEscape(sessionToken), http.StatusFound)
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
