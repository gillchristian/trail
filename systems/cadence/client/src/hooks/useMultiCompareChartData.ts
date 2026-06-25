import { useMemo } from 'react';
import type { ActivityDetailResponse } from '../types';
import { formatPace, formatHeartRate, formatDuration } from '../lib/format';

export interface MultiCompareChartPoint {
  km: string;
  [key: string]: string | number | null;
}

function speedToPaceSeconds(speed: number): number | null {
  if (speed <= 0) return null;
  return 1000 / speed;
}

export function useMultiCompareChartData(activities: ActivityDetailResponse[]): MultiCompareChartPoint[] {
  return useMemo(() => {
    if (activities.length === 0) return [];

    const maxKm = Math.max(...activities.map(a => a.splits.length));
    const points: MultiCompareChartPoint[] = [];
    const cumTimes = activities.map(() => 0);

    for (let i = 0; i < maxKm; i++) {
      const point: MultiCompareChartPoint = { km: '' };

      let kmLabel = String(i + 1);
      for (const activity of activities) {
        const split = activity.splits[i];
        if (split && i === activity.splits.length - 1 && split.distance < 900) {
          kmLabel = (split.distance / 1000).toFixed(1);
          break;
        }
      }
      point.km = kmLabel;

      for (let j = 0; j < activities.length; j++) {
        const split = activities[j].splits[i] ?? null;
        if (split) cumTimes[j] += split.elapsed_time;

        point[`pace_${j}`] = split ? speedToPaceSeconds(split.average_speed) : null;
        point[`hr_${j}`] = split?.average_heartrate ?? null;
        point[`time_${j}`] = split ? cumTimes[j] : null;
        point[`rawPace_${j}`] = split ? formatPace(split.average_speed) : '--';
        point[`rawHr_${j}`] = formatHeartRate(split?.average_heartrate ?? undefined);
        point[`rawTime_${j}`] = split ? formatDuration(cumTimes[j]) : '--';
      }

      points.push(point);
    }

    return points;
  }, [activities]);
}
