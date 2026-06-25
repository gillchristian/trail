package handlers

import (
	"errors"
	"testing"
	"time"
)

func TestOAuthStateRoundTrip(t *testing.T) {
	nonce, err := newOAuthNonce()
	if err != nil {
		t.Fatalf("newOAuthNonce: %v", err)
	}
	if len(nonce) == 0 {
		t.Fatal("nonce is empty")
	}

	state, err := encodeOAuthState(nonce, OriginTrail)
	if err != nil {
		t.Fatalf("encodeOAuthState: %v", err)
	}

	gotNonce, gotOrigin, err := decodeOAuthState(state)
	if err != nil {
		t.Fatalf("decodeOAuthState: %v", err)
	}
	if gotNonce != nonce {
		t.Errorf("nonce mismatch: got %q want %q", gotNonce, nonce)
	}
	if gotOrigin != OriginTrail {
		t.Errorf("origin mismatch: got %q want %q", gotOrigin, OriginTrail)
	}
}

func TestDecodeOAuthStateRejectsGarbage(t *testing.T) {
	for _, raw := range []string{"", "not-base64!!!", "Zm9v"} {
		if _, _, err := decodeOAuthState(raw); err == nil {
			t.Errorf("expected error for %q, got nil", raw)
		}
	}
}

func TestOAuthStateStoreTakeIsOneShot(t *testing.T) {
	s := &OAuthStateStore{now: time.Now}
	s.Put("nonce-1", OriginTrail)

	origin, err := s.Take("nonce-1")
	if err != nil {
		t.Fatalf("first Take: %v", err)
	}
	if origin != OriginTrail {
		t.Errorf("origin: got %q want %q", origin, OriginTrail)
	}

	if _, err := s.Take("nonce-1"); !errors.Is(err, ErrOAuthStateUnknown) {
		t.Errorf("second Take: got %v want %v", err, ErrOAuthStateUnknown)
	}
}

func TestOAuthStateStoreTakeUnknown(t *testing.T) {
	s := &OAuthStateStore{now: time.Now}
	if _, err := s.Take("never-stored"); !errors.Is(err, ErrOAuthStateUnknown) {
		t.Errorf("got %v want %v", err, ErrOAuthStateUnknown)
	}
}

func TestOAuthStateStoreTakeExpired(t *testing.T) {
	clock := time.Now()
	s := &OAuthStateStore{now: func() time.Time { return clock }}
	s.Put("nonce-2", OriginCadence)

	clock = clock.Add(oauthStateTTL + time.Second)

	if _, err := s.Take("nonce-2"); !errors.Is(err, ErrOAuthStateExpired) {
		t.Errorf("got %v want %v", err, ErrOAuthStateExpired)
	}
}

func TestAuthHandlerRedirectURLFor(t *testing.T) {
	h := &AuthHandler{
		FrontendURL: "http://legacy.example",
		FrontendURLs: map[string]string{
			OriginCadence: "http://cadence.example",
			OriginTrail:   "http://trail.example",
		},
	}
	cases := map[string]string{
		OriginCadence: "http://cadence.example",
		OriginTrail:   "http://trail.example",
		"unknown":     "http://legacy.example", // falls back
	}
	for origin, want := range cases {
		if got := h.redirectURLFor(origin); got != want {
			t.Errorf("redirectURLFor(%q): got %q want %q", origin, got, want)
		}
	}

	// Empty map entry should also fall back
	h.FrontendURLs[OriginTrail] = ""
	if got := h.redirectURLFor(OriginTrail); got != "http://legacy.example" {
		t.Errorf("empty map entry should fall back, got %q", got)
	}
}

func TestIsAllowedOrigin(t *testing.T) {
	cases := map[string]bool{
		OriginCadence: true,
		OriginTrail:   true,
		"":            false,
		"unknown":     false,
		"CADENCE":     false,
	}
	for origin, want := range cases {
		if got := IsAllowedOrigin(origin); got != want {
			t.Errorf("IsAllowedOrigin(%q): got %v want %v", origin, got, want)
		}
	}
}
