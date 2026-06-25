package strava

import (
	"log"
	"net/http"
	"strconv"
	"strings"
)

const rateLimitWarnThreshold = 0.80

// LogRateLimit inspects the X-Ratelimit-Limit / X-Ratelimit-Usage pair
// (Strava emits "shortLimit,longLimit" and "shortUsage,longUsage") and
// log.Printfs a warning when either bucket is at or above 80 %.
func LogRateLimit(h http.Header) {
	limit := h.Get("X-Ratelimit-Limit")
	usage := h.Get("X-Ratelimit-Usage")
	if limit == "" || usage == "" {
		return
	}

	limits, lok := parseRateLimitPair(limit)
	usages, uok := parseRateLimitPair(usage)
	if !lok || !uok {
		return
	}

	for i, label := range []string{"15-min", "daily"} {
		if i >= len(limits) || i >= len(usages) {
			break
		}
		if limits[i] == 0 {
			continue
		}
		ratio := float64(usages[i]) / float64(limits[i])
		if ratio >= rateLimitWarnThreshold {
			log.Printf("Strava rate-limit warning: %s bucket at %.0f%% (%d/%d)",
				label, ratio*100, usages[i], limits[i])
		}
	}
}

func parseRateLimitPair(s string) ([]int, bool) {
	parts := strings.Split(s, ",")
	out := make([]int, 0, len(parts))
	for _, p := range parts {
		n, err := strconv.Atoi(strings.TrimSpace(p))
		if err != nil {
			return nil, false
		}
		out = append(out, n)
	}
	return out, true
}
