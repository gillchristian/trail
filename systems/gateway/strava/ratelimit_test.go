package strava

import (
	"bytes"
	"log"
	"net/http"
	"strings"
	"testing"
)

func captureLog(t *testing.T, fn func()) string {
	t.Helper()
	var buf bytes.Buffer
	prevOut := log.Writer()
	prevFlags := log.Flags()
	log.SetOutput(&buf)
	log.SetFlags(0)
	defer func() {
		log.SetOutput(prevOut)
		log.SetFlags(prevFlags)
	}()
	fn()
	return buf.String()
}

func TestLogRateLimit(t *testing.T) {
	cases := []struct {
		name      string
		limit     string
		usage     string
		wantWarns []string
		wantNone  bool
	}{
		{name: "headers absent", wantNone: true},
		{
			name: "well under threshold",
			limit: "100,1000", usage: "10,100",
			wantNone: true,
		},
		{
			name: "exactly 80 percent short bucket",
			limit: "100,1000", usage: "80,100",
			wantWarns: []string{"15-min bucket at 80% (80/100)"},
		},
		{
			name: "above threshold short bucket only",
			limit: "100,1000", usage: "95,100",
			wantWarns: []string{"15-min bucket at 95% (95/100)"},
		},
		{
			name: "above threshold both buckets",
			limit: "100,1000", usage: "90,950",
			wantWarns: []string{
				"15-min bucket at 90% (90/100)",
				"daily bucket at 95% (950/1000)",
			},
		},
		{
			name: "garbage values are ignored silently",
			limit: "lol,wat", usage: "10,20",
			wantNone: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := http.Header{}
			if tc.limit != "" {
				h.Set("X-Ratelimit-Limit", tc.limit)
			}
			if tc.usage != "" {
				h.Set("X-Ratelimit-Usage", tc.usage)
			}

			out := captureLog(t, func() { LogRateLimit(h) })

			if tc.wantNone {
				if out != "" {
					t.Errorf("expected no log output, got %q", out)
				}
				return
			}
			for _, want := range tc.wantWarns {
				if !strings.Contains(out, want) {
					t.Errorf("expected log to contain %q, got %q", want, out)
				}
			}
		})
	}
}
