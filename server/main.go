package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"cadence-server/handlers"
	"cadence-server/store"
	"cadence-server/strava"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/joho/godotenv"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envList(key string) []string {
	raw := os.Getenv(key)
	if raw == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func main() {
	godotenv.Load()

	port := env("PORT", "3001")
	frontendURL := env("FRONTEND_URL", "http://localhost:5173")
	apiBaseURL := env("API_BASE_URL", "http://localhost:"+port)
	dbPath := env("DB_PATH", "tokens.db")

	allowedOrigins := envList("FRONTEND_URLS")
	if len(allowedOrigins) == 0 {
		allowedOrigins = []string{frontendURL}
	}
	clientID := os.Getenv("STRAVA_CLIENT_ID")
	clientSecret := os.Getenv("STRAVA_CLIENT_SECRET")

	db, err := store.OpenDB(dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}

	tokenStore := store.NewTokenStore(db)
	activityCache := store.NewActivityCacheStore(db)
	activityStore := store.NewActivityStore(db)
	athleteStore := store.NewAthleteStore(db)

	stravaClient := &strava.Client{
		ClientID:     clientID,
		ClientSecret: clientSecret,
	}

	authHandler := &handlers.AuthHandler{
		Store:        tokenStore,
		AthleteStore: athleteStore,
		Strava:       stravaClient,
		ClientID:     clientID,
		APIBaseURL:   apiBaseURL,
		FrontendURL:  frontendURL,
	}

	backfillHandler := &handlers.BackfillHandler{
		Store:         tokenStore,
		Strava:        stravaClient,
		ActivityStore: activityStore,
	}

	activitiesHandler := &handlers.ActivitiesHandler{
		Store:         tokenStore,
		Strava:        stravaClient,
		ActivityStore: activityStore,
		Backfill:      backfillHandler,
	}

	compareHandler := &handlers.CompareHandler{
		Store:         tokenStore,
		Strava:        stravaClient,
		ActivityCache: activityCache,
		AthleteStore:  athleteStore,
	}

	r := chi.NewRouter()

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: allowedOrigins,
		AllowedMethods: []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders: []string{"Authorization", "Content-Type"},
		ExposedHeaders: []string{"X-Data-Source"},
	}))

	r.Get("/auth/strava", authHandler.StravaRedirect)
	r.Get("/auth/callback", authHandler.Callback)
	r.Get("/auth/status", authHandler.Status)
	r.Post("/auth/logout", authHandler.Logout)
	r.Get("/api/activities", activitiesHandler.GetActivities)
	r.Get("/api/activities/search", activitiesHandler.SearchActivities)
	r.Get("/api/activities/{id}/detail", compareHandler.GetActivityDetail)
	r.Get("/api/resolve-link", compareHandler.ResolveShortLink)
	r.Get("/api/backfill/status", backfillHandler.GetBackfillStatus)

	fmt.Printf("Server running on http://localhost:%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
