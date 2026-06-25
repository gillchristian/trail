import { useMemo } from 'react';
import type { StravaActivity } from '../types';
import { formatDistance, formatPace, formatDuration, formatHeartRate, formatDate } from '../lib/format';

export interface ChartDataPoint {
  date: string;
  distance: number;
  pace: number;
  duration: number;
  hr: number | null;
  rawDistance: string;
  rawPace: string;
  rawDuration: string;
  rawHr: string;
}

function normalize(values: number[]): number[] {
  const min = Math.min(...values);
  const max = Math.max(...values);
  if (min === max) return values.map(() => 0.5);
  return values.map((v) => (v - min) / (max - min));
}

export function useChartData(activities: StravaActivity[]): ChartDataPoint[] {
  return useMemo(() => {
    if (activities.length === 0) return [];

    const sorted = [...activities].reverse(); // oldest first

    const distances = sorted.map((a) => a.distance / 1000);
    const paces = sorted.map((a) => (a.average_speed > 0 ? 1000 / a.average_speed : 0));
    const durations = sorted.map((a) => a.moving_time);
    const rawHrs = sorted.map((a) => a.average_heartrate ?? null);
    const validHrs = rawHrs.filter((v): v is number => v !== null);

    const normDistances = normalize(distances);
    // Invert pace so up = faster (lower pace value = better)
    const normPaces = normalize(paces).map((v) => 1 - v);
    const normDurations = normalize(durations);
    const normHrs = validHrs.length > 0 ? normalize(validHrs) : [];

    let hrIndex = 0;
    return sorted.map((a, i) => ({
      date: formatDate(a.start_date_local),
      distance: normDistances[i],
      pace: normPaces[i],
      duration: normDurations[i],
      hr: rawHrs[i] !== null ? (normHrs[hrIndex++] ?? null) : null,
      rawDistance: `${formatDistance(a.distance)} km`,
      rawPace: `${formatPace(a.average_speed)} /km`,
      rawDuration: formatDuration(a.moving_time),
      rawHr: formatHeartRate(a.average_heartrate),
    }));
  }, [activities]);
}
