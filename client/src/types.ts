export interface StravaActivity {
  id: number;
  name: string;
  type: string;
  sport_type: string;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  average_speed: number;
  average_heartrate?: number;
  max_heartrate?: number;
  start_date_local: string;
  start_date: string;
}

export interface CachedActivities {
  activities: StravaActivity[];
  fetchedAt: number;
}

export interface ActivitySplit {
  km: number;
  distance: number;
  elapsed_time: number;
  moving_time: number;
  average_speed: number;
  elevation_difference: number;
  average_heartrate: number | null;
}

export interface ActivitySummary {
  id: number;
  name: string;
  distance: number;
  moving_time: number;
  start_date_local: string;
  type: string;
  athlete_id?: number;
  athlete_name?: string;
}

export interface ActivityDetailResponse {
  activity: ActivitySummary;
  splits: ActivitySplit[];
}

export interface SearchResult {
  id: number;
  name: string;
  distance: number;
  moving_time: number;
  start_date_local: string;
  sport_type: string;
}

export interface SearchResponse {
  activities: SearchResult[];
  total: number;
  limit: number;
  offset: number;
}

export interface BackfillStatus {
  running: boolean;
  complete: boolean;
  total_stored: number;
}
