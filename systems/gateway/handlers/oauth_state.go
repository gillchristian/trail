package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"sync"
	"time"
)

const (
	oauthStateTTL    = 5 * time.Minute
	oauthSweepEvery  = 1 * time.Minute
	OriginCadence    = "cadence"
	OriginTrail      = "trail"
)

var ErrOAuthStateUnknown = errors.New("unknown or already-consumed OAuth state")
var ErrOAuthStateExpired = errors.New("OAuth state expired")

type oauthState struct {
	origin    string
	expiresAt time.Time
}

type OAuthStateStore struct {
	m   sync.Map // map[string]oauthState
	now func() time.Time
}

func NewOAuthStateStore() *OAuthStateStore {
	s := &OAuthStateStore{now: time.Now}
	go s.sweepLoop()
	return s
}

func (s *OAuthStateStore) Put(nonce, origin string) {
	s.m.Store(nonce, oauthState{
		origin:    origin,
		expiresAt: s.now().Add(oauthStateTTL),
	})
}

// Take consumes the nonce (one-time use). Returns the stored origin
// or an error if the nonce was never recorded, was already consumed,
// or has expired.
func (s *OAuthStateStore) Take(nonce string) (string, error) {
	v, ok := s.m.LoadAndDelete(nonce)
	if !ok {
		return "", ErrOAuthStateUnknown
	}
	st := v.(oauthState)
	if s.now().After(st.expiresAt) {
		return "", ErrOAuthStateExpired
	}
	return st.origin, nil
}

func (s *OAuthStateStore) sweepLoop() {
	t := time.NewTicker(oauthSweepEvery)
	defer t.Stop()
	for now := range t.C {
		s.m.Range(func(k, v any) bool {
			if now.After(v.(oauthState).expiresAt) {
				s.m.Delete(k)
			}
			return true
		})
	}
}

type oauthStatePayload struct {
	Nonce  string `json:"n"`
	Origin string `json:"o"`
}

func encodeOAuthState(nonce, origin string) (string, error) {
	p, err := json.Marshal(oauthStatePayload{Nonce: nonce, Origin: origin})
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(p), nil
}

func decodeOAuthState(raw string) (nonce, origin string, err error) {
	b, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return "", "", err
	}
	var p oauthStatePayload
	if err := json.Unmarshal(b, &p); err != nil {
		return "", "", err
	}
	return p.Nonce, p.Origin, nil
}

func newOAuthNonce() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func IsAllowedOrigin(o string) bool {
	return o == OriginCadence || o == OriginTrail
}
