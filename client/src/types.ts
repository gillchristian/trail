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
}

export interface ActivityDetailResponse {
  activity: ActivitySummary;
  splits: ActivitySplit[];
}
