package handlers

import (
	"reflect"
	"testing"
)

func TestValidateStreamKeys(t *testing.T) {
	cases := []struct {
		name       string
		input      string
		wantKeys   []string
		wantBadKey string
		wantOK     bool
	}{
		{
			name:     "single allowed key",
			input:    "distance",
			wantKeys: []string{"distance"},
			wantOK:   true,
		},
		{
			name:     "multiple allowed with whitespace",
			input:    " time, distance ,latlng,altitude ",
			wantKeys: []string{"time", "distance", "latlng", "altitude"},
			wantOK:   true,
		},
		{
			name:     "all documented keys",
			input:    "time,distance,latlng,altitude,heartrate,cadence,watts,velocity_smooth,grade_smooth,temp,moving,grade_adjusted_speed",
			wantKeys: []string{"time", "distance", "latlng", "altitude", "heartrate", "cadence", "watts", "velocity_smooth", "grade_smooth", "temp", "moving", "grade_adjusted_speed"},
			wantOK:   true,
		},
		{
			name:       "single unknown key",
			input:      "bogus",
			wantBadKey: "bogus",
		},
		{
			name:       "mixed valid and invalid — first invalid wins",
			input:      "distance,bogus,heartrate",
			wantBadKey: "bogus",
		},
		{
			name:  "empty input is rejected",
			input: "",
		},
		{
			name:  "only commas is rejected",
			input: ",,,",
		},
		{
			name:       "case-sensitive — uppercase is unknown",
			input:      "Distance",
			wantBadKey: "Distance",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotKeys, gotBadKey, gotOK := validateStreamKeys(tc.input)
			if gotOK != tc.wantOK {
				t.Errorf("ok: got %v want %v", gotOK, tc.wantOK)
			}
			if gotBadKey != tc.wantBadKey {
				t.Errorf("badKey: got %q want %q", gotBadKey, tc.wantBadKey)
			}
			if tc.wantOK && !reflect.DeepEqual(gotKeys, tc.wantKeys) {
				t.Errorf("keys: got %v want %v", gotKeys, tc.wantKeys)
			}
		})
	}
}
