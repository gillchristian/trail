package strava

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"cadence-server/store"
)

const (
	stravaAPI   = "https://www.strava.com/api/v3"
	stravaOAuth = "https://www.strava.com/oauth"
)

type Client struct {
	ClientID     string
	ClientSecret string
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresAt    int64  `json:"expires_at"`
	Athlete struct {
		ID        int64  `json:"id"`
		Firstname string `json:"firstname"`
		Lastname  string `json:"lastname"`
	} `json:"athlete"`
}

type TokenExchangeResult struct {
	Tokens      store.Tokens
	AthleteName string
}

func (c *Client) ExchangeCodeForTokens(code string) (*TokenExchangeResult, error) {
	resp, err := http.PostForm(stravaOAuth+"/token", url.Values{
		"client_id":     {c.ClientID},
		"client_secret": {c.ClientSecret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
	})
	if err != nil {
		return nil, fmt.Errorf("token exchange request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token exchange failed: %d %s", resp.StatusCode, body)
	}

	var data tokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("token exchange decode failed: %w", err)
	}

	name := strings.TrimSpace(data.Athlete.Firstname + " " + data.Athlete.Lastname)

	return &TokenExchangeResult{
		Tokens: store.Tokens{
			AccessToken:  data.AccessToken,
			RefreshToken: data.RefreshToken,
			ExpiresAt:    data.ExpiresAt,
			AthleteID:    data.Athlete.ID,
		},
		AthleteName: name,
	}, nil
}

func (c *Client) RefreshAccessToken(tokens *store.Tokens) (*store.Tokens, error) {
	resp, err := http.PostForm(stravaOAuth+"/token", url.Values{
		"client_id":     {c.ClientID},
		"client_secret": {c.ClientSecret},
		"grant_type":    {"refresh_token"},
		"refresh_token": {tokens.RefreshToken},
	})
	if err != nil {
		return nil, fmt.Errorf("token refresh request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token refresh failed: %d %s", resp.StatusCode, body)
	}

	var data tokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("token refresh decode failed: %w", err)
	}

	return &store.Tokens{
		AccessToken:  data.AccessToken,
		RefreshToken: data.RefreshToken,
		ExpiresAt:    data.ExpiresAt,
		AthleteID:    tokens.AthleteID,
	}, nil
}

// GetValidAccessToken returns a valid access token, refreshing if needed.
// If a refresh occurred, refreshedTokens is non-nil and should be persisted.
func (c *Client) GetValidAccessToken(tokens *store.Tokens) (accessToken string, refreshedTokens *store.Tokens, err error) {
	if store.IsTokenExpired(tokens) {
		refreshed, err := c.RefreshAccessToken(tokens)
		if err != nil {
			return "", nil, err
		}
		return refreshed.AccessToken, refreshed, nil
	}
	return tokens.AccessToken, nil, nil
}

type Split struct {
	Split               int      `json:"split"`
	Distance            float64  `json:"distance"`
	ElapsedTime         int      `json:"elapsed_time"`
	MovingTime          int      `json:"moving_time"`
	AverageSpeed        float64  `json:"average_speed"`
	ElevationDifference float64  `json:"elevation_difference"`
	PaceZone            int      `json:"pace_zone"`
	AverageHeartrate    *float64 `json:"average_heartrate"`
}

type ActivityDetail struct {
	ID             int64   `json:"id"`
	Name           string  `json:"name"`
	Distance       float64 `json:"distance"`
	MovingTime     int     `json:"moving_time"`
	ElapsedTime    int     `json:"elapsed_time"`
	StartDateLocal string  `json:"start_date_local"`
	Type           string  `json:"type"`
	HasHeartrate   bool    `json:"has_heartrate"`
	SplitsMetric   []Split `json:"splits_metric"`
	Athlete        struct {
		ID int64 `json:"id"`
	} `json:"athlete"`
}

func (c *Client) FetchActivityDetail(accessToken string, activityID int64) (*ActivityDetail, error) {
	url := fmt.Sprintf("%s/activities/%d", stravaAPI, activityID)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("strava activity detail request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("strava activity detail error: %d %s", resp.StatusCode, body)
	}

	var detail ActivityDetail
	if err := json.NewDecoder(resp.Body).Decode(&detail); err != nil {
		return nil, fmt.Errorf("activity detail decode failed: %w", err)
	}

	return &detail, nil
}

type streamEntry struct {
	Type string    `json:"type"`
	Data []float64 `json:"data"`
}

type ActivityStreams struct {
	Distance  []float64
	Heartrate []float64
}

// doStreamsRequest issues GET /activities/{id}/streams to Strava with the
// given keys. When keyByType is true the response is a JSON object keyed
// by stream type; when false it's an array of {type, data} entries. The
// caller decides which shape it wants and decodes accordingly.
func (c *Client) doStreamsRequest(accessToken string, activityID int64, keys []string, keyByType bool) ([]byte, http.Header, error) {
	params := url.Values{
		"keys": {strings.Join(keys, ",")},
	}
	if keyByType {
		params.Set("key_by_type", "true")
	}
	reqURL := fmt.Sprintf("%s/activities/%d/streams?%s", stravaAPI, activityID, params.Encode())

	req, err := http.NewRequest("GET", reqURL, nil)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("strava streams request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.Header, fmt.Errorf("strava streams read failed: %w", err)
	}

	LogRateLimit(resp.Header)

	if resp.StatusCode != http.StatusOK {
		return nil, resp.Header, fmt.Errorf("strava streams error: %d %s", resp.StatusCode, body)
	}

	return body, resp.Header, nil
}

// FetchActivityStreams returns the requested streams in cadence's typed
// shape (Distance / Heartrate slices). Used by compare.go for per-km HR
// computation. Keys outside Distance/Heartrate are tolerated but ignored.
func (c *Client) FetchActivityStreams(accessToken string, activityID int64, keys []string) (*ActivityStreams, error) {
	body, _, err := c.doStreamsRequest(accessToken, activityID, keys, false)
	if err != nil {
		return nil, err
	}

	var entries []streamEntry
	if err := json.Unmarshal(body, &entries); err != nil {
		return nil, fmt.Errorf("streams decode failed: %w", err)
	}

	streams := &ActivityStreams{}
	for _, e := range entries {
		switch e.Type {
		case "distance":
			streams.Distance = e.Data
		case "heartrate":
			streams.Heartrate = e.Data
		}
	}

	return streams, nil
}

// FetchActivityStreamsRaw fetches the streams in Strava's key_by_type=true
// shape and returns the response bytes unchanged. The accompanying http
// headers are returned so callers can inspect rate-limit state.
func (c *Client) FetchActivityStreamsRaw(accessToken string, activityID int64, keys []string) ([]byte, http.Header, error) {
	return c.doStreamsRequest(accessToken, activityID, keys, true)
}

// FetchActivitiesPage fetches a single page of activities with configurable pagination.
func (c *Client) FetchActivitiesPage(accessToken string, page, perPage int) ([]json.RawMessage, error) {
	params := url.Values{
		"page":     {strconv.Itoa(page)},
		"per_page": {strconv.Itoa(perPage)},
	}

	req, err := http.NewRequest("GET", stravaAPI+"/athlete/activities?"+params.Encode(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("strava API request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("strava API error: %d %s", resp.StatusCode, body)
	}

	var activities []json.RawMessage
	if err := json.NewDecoder(resp.Body).Decode(&activities); err != nil {
		return nil, fmt.Errorf("activities decode failed: %w", err)
	}

	return activities, nil
}

func (c *Client) FetchActivities(accessToken string, after, before int64) ([]json.RawMessage, error) {
	params := url.Values{
		"after":    {strconv.FormatInt(after, 10)},
		"before":   {strconv.FormatInt(before, 10)},
		"per_page": {"100"},
	}

	req, err := http.NewRequest("GET", stravaAPI+"/athlete/activities?"+params.Encode(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("strava API request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("strava API error: %d %s", resp.StatusCode, body)
	}

	var activities []json.RawMessage
	if err := json.NewDecoder(resp.Body).Decode(&activities); err != nil {
		return nil, fmt.Errorf("activities decode failed: %w", err)
	}

	return activities, nil
}
