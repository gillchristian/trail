package handlers

import (
	"testing"
	"time"
)

func TestIsAthleteCacheFresh(t *testing.T) {
	now := time.Unix(1_000_000, 0)
	ttl := 24 * time.Hour

	cases := []struct {
		name     string
		cachedAt int64
		want     bool
	}{
		{name: "just cached", cachedAt: now.Unix(), want: true},
		{name: "5 min ago", cachedAt: now.Add(-5 * time.Minute).Unix(), want: true},
		{name: "1 second under TTL", cachedAt: now.Add(-ttl + time.Second).Unix(), want: true},
		{name: "exactly at TTL boundary", cachedAt: now.Add(-ttl).Unix(), want: false},
		{name: "1 second over TTL", cachedAt: now.Add(-ttl - time.Second).Unix(), want: false},
		{name: "ancient cache", cachedAt: 0, want: false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := isAthleteCacheFresh(now, tc.cachedAt, ttl)
			if got != tc.want {
				t.Errorf("isAthleteCacheFresh(now, %d, %s): got %v want %v", tc.cachedAt, ttl, got, tc.want)
			}
		})
	}
}

func TestAthleteHandlerClockFallsBackToTimeNow(t *testing.T) {
	h := &AthleteHandler{}
	got := h.clock()
	if time.Since(got) > time.Second {
		t.Errorf("clock() returned suspiciously old time: %v", got)
	}

	fixed := time.Unix(42, 0)
	h.now = func() time.Time { return fixed }
	if h.clock() != fixed {
		t.Errorf("injected clock not honored: got %v want %v", h.clock(), fixed)
	}
}
