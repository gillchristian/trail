import { useMemo } from 'react';
import type { ComparisonData } from './useCompareData';
import { formatPace, formatHeartRate, formatDuration } from '../lib/format';

export interface CompareChartPoint {
  km: string;
  paceA: number | null;
  paceB: number | null;
  hrA: number | null;
  hrB: number | null;
  timeA: number | null;
  timeB: number | null;
  rawPaceA: string;
  rawPaceB: string;
  rawHrA: string;
  rawHrB: string;
  rawTimeA: string;
  rawTimeB: string;
}

function speedToPaceSeconds(speed: number): number | null {
  if (speed <= 0) return null;
  return 1000 / speed;
}

export function useCompareChartData(data: ComparisonData | null): CompareChartPoint[] {
  return useMemo(() => {
    if (!data) return [];

    const maxKm = Math.max(data.a.splits.length, data.b.splits.length);
    const points: CompareChartPoint[] = [];

    let cumTimeA = 0;
    let cumTimeB = 0;

    for (let i = 0; i < maxKm; i++) {
      const splitA = data.a.splits[i] ?? null;
      const splitB = data.b.splits[i] ?? null;

      if (splitA) cumTimeA += splitA.elapsed_time;
      if (splitB) cumTimeB += splitB.elapsed_time;

      // Label: use actual distance for partial last km
      const isLastA = splitA && i === data.a.splits.length - 1 && splitA.distance < 900;
      const isLastB = splitB && i === data.b.splits.length - 1 && splitB.distance < 900;
      const kmLabel = (isLastA || isLastB)
        ? ((splitA?.distance ?? splitB?.distance ?? 0) / 1000).toFixed(1)
        : String(i + 1);

      const paceA = splitA ? speedToPaceSeconds(splitA.average_speed) : null;
      const paceB = splitB ? speedToPaceSeconds(splitB.average_speed) : null;

      points.push({
        km: kmLabel,
        paceA,
        paceB,
        hrA: splitA?.average_heartrate ?? null,
        hrB: splitB?.average_heartrate ?? null,
        timeA: splitA ? cumTimeA : null,
        timeB: splitB ? cumTimeB : null,
        rawPaceA: splitA ? formatPace(splitA.average_speed) : '--',
        rawPaceB: splitB ? formatPace(splitB.average_speed) : '--',
        rawHrA: formatHeartRate(splitA?.average_heartrate ?? undefined),
        rawHrB: formatHeartRate(splitB?.average_heartrate ?? undefined),
        rawTimeA: splitA ? formatDuration(cumTimeA) : '--',
        rawTimeB: splitB ? formatDuration(cumTimeB) : '--',
      });
    }

    return points;
  }, [data]);
}
