import type { ActivityDetailResponse } from '../types';
import { formatPace, formatHeartRate, formatDuration } from '../lib/format';

interface ActivityEntry {
  detail: ActivityDetailResponse;
  label: string;
  color: string;
}

function formatPaceDiff(speedA: number, speedB: number): string {
  if (speedA <= 0 || speedB <= 0) return '--';
  const paceA = 1000 / speedA;
  const paceB = 1000 / speedB;
  const diff = paceB - paceA;
  const absDiff = Math.abs(diff);
  const minutes = Math.floor(absDiff / 60);
  const seconds = Math.round(absDiff % 60);
  const sign = diff > 0 ? '+' : diff < 0 ? '-' : '';
  if (minutes > 0) return `${sign}${minutes}:${String(seconds).padStart(2, '0')}`;
  return `${sign}${seconds}s`;
}

function formatHrDiff(hrA: number | null, hrB: number | null): string {
  if (hrA == null || hrB == null) return '--';
  const diff = Math.round(hrB - hrA);
  if (diff === 0) return '0';
  return diff > 0 ? `+${diff}` : String(diff);
}

function formatTimeDiff(cumA: number, cumB: number): string {
  const diff = cumB - cumA;
  const absDiff = Math.abs(diff);
  const sign = diff > 0 ? '+' : diff < 0 ? '-' : '';
  const m = Math.floor(absDiff / 60);
  const s = absDiff % 60;
  if (m > 0) return `${sign}${m}:${String(s).padStart(2, '0')}`;
  return `${sign}${s}s`;
}

export function CompareTable({ entries }: { entries: ActivityEntry[] }) {
  const n = entries.length;
  if (n === 0) return null;

  const showDiff = n === 2;
  const maxKm = Math.max(...entries.map(e => e.detail.splits.length));
  const colsPerMetric = n + (showDiff ? 1 : 0);

  const cumTimes = entries.map(() => 0);

  const rows: {
    km: string;
    splits: (typeof entries[0]['detail']['splits'][0] | null)[];
    cumTimes: number[];
  }[] = [];

  for (let i = 0; i < maxKm; i++) {
    const splits = entries.map(e => e.detail.splits[i] ?? null);
    splits.forEach((split, j) => {
      if (split) cumTimes[j] += split.elapsed_time;
    });

    let kmLabel = String(i + 1);
    for (let j = 0; j < entries.length; j++) {
      const split = splits[j];
      if (split && i === entries[j].detail.splits.length - 1 && split.distance < 900) {
        kmLabel = (split.distance / 1000).toFixed(1);
        break;
      }
    }

    rows.push({ km: kmLabel, splits, cumTimes: [...cumTimes] });
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-gray-200 text-gray-500">
            <th rowSpan={2} className="py-2 pr-2 text-left font-medium">km</th>
            <th colSpan={colsPerMetric} className="border-l border-gray-200 px-2 py-1 text-center font-medium">Pace</th>
            <th colSpan={colsPerMetric} className="border-l border-gray-200 px-2 py-1 text-center font-medium">HR</th>
            <th colSpan={colsPerMetric} className="border-l border-gray-200 px-2 py-1 text-center font-medium">Time</th>
          </tr>
          <tr className="border-b border-gray-200 text-xs text-gray-400">
            {/* Pace sub-headers */}
            {entries.map((e, j) => (
              <th key={`pace-${j}`} className={`px-2 py-1 text-right font-medium ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                {e.label}
              </th>
            ))}
            {showDiff && <th className="px-2 py-1 text-right font-medium">Diff</th>}
            {/* HR sub-headers */}
            {entries.map((e, j) => (
              <th key={`hr-${j}`} className={`px-2 py-1 text-right font-medium ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                {e.label}
              </th>
            ))}
            {showDiff && <th className="px-2 py-1 text-right font-medium">Diff</th>}
            {/* Time sub-headers */}
            {entries.map((e, j) => (
              <th key={`time-${j}`} className={`px-2 py-1 text-right font-medium ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                {e.label}
              </th>
            ))}
            {showDiff && <th className="px-2 py-1 text-right font-medium">Diff</th>}
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {rows.map((row) => (
            <tr key={row.km} className="border-b border-gray-100 hover:bg-gray-50">
              <td className="py-2 pr-2 text-gray-500">{row.km}</td>

              {/* Pace columns */}
              {row.splits.map((split, j) => (
                <td key={`pace-${j}`} className={`px-2 py-2 text-right ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                  {split ? formatPace(split.average_speed) : '--'}
                </td>
              ))}
              {showDiff && (
                <td className="px-2 py-2 text-right text-gray-400">
                  {row.splits[0] && row.splits[1]
                    ? formatPaceDiff(row.splits[0].average_speed, row.splits[1].average_speed)
                    : '--'}
                </td>
              )}

              {/* HR columns */}
              {row.splits.map((split, j) => (
                <td key={`hr-${j}`} className={`px-2 py-2 text-right ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                  {formatHeartRate(split?.average_heartrate ?? undefined)}
                </td>
              ))}
              {showDiff && (
                <td className="px-2 py-2 text-right text-gray-400">
                  {formatHrDiff(row.splits[0]?.average_heartrate ?? null, row.splits[1]?.average_heartrate ?? null)}
                </td>
              )}

              {/* Time columns */}
              {row.splits.map((split, j) => (
                <td key={`time-${j}`} className={`px-2 py-2 text-right ${j === 0 ? 'border-l border-gray-200' : ''}`}>
                  {split ? formatDuration(row.cumTimes[j]) : '--'}
                </td>
              ))}
              {showDiff && (
                <td className="px-2 py-2 text-right text-gray-400">
                  {row.splits[0] && row.splits[1]
                    ? formatTimeDiff(row.cumTimes[0], row.cumTimes[1])
                    : '--'}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
