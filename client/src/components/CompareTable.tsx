import type { ComparisonData } from '../hooks/useCompareData';
import { formatPace, formatHeartRate, formatDuration } from '../lib/format';

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

export function CompareTable({ data }: { data: ComparisonData }) {
  const maxKm = Math.max(data.a.splits.length, data.b.splits.length);

  let cumTimeA = 0;
  let cumTimeB = 0;

  const rows: { km: string; splitA: typeof data.a.splits[0] | null; splitB: typeof data.b.splits[0] | null; cumA: number; cumB: number }[] = [];
  for (let i = 0; i < maxKm; i++) {
    const splitA = data.a.splits[i] ?? null;
    const splitB = data.b.splits[i] ?? null;

    if (splitA) cumTimeA += splitA.elapsed_time;
    if (splitB) cumTimeB += splitB.elapsed_time;

    const isLastA = splitA && i === data.a.splits.length - 1 && splitA.distance < 900;
    const isLastB = splitB && i === data.b.splits.length - 1 && splitB.distance < 900;
    const kmLabel = (isLastA || isLastB)
      ? ((splitA?.distance ?? splitB?.distance ?? 0) / 1000).toFixed(1)
      : String(i + 1);

    rows.push({ km: kmLabel, splitA, splitB, cumA: cumTimeA, cumB: cumTimeB });
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-gray-200 text-gray-500">
            <th rowSpan={2} className="py-2 pr-2 text-left font-medium">km</th>
            <th colSpan={3} className="border-l border-gray-200 px-2 py-1 text-center font-medium">Pace</th>
            <th colSpan={3} className="border-l border-gray-200 px-2 py-1 text-center font-medium">HR</th>
            <th colSpan={3} className="border-l border-gray-200 px-2 py-1 text-center font-medium">Time</th>
          </tr>
          <tr className="border-b border-gray-200 text-gray-400 text-xs">
            <th className="border-l border-gray-200 px-2 py-1 text-right font-medium">A</th>
            <th className="px-2 py-1 text-right font-medium">B</th>
            <th className="px-2 py-1 text-right font-medium">Diff</th>
            <th className="border-l border-gray-200 px-2 py-1 text-right font-medium">A</th>
            <th className="px-2 py-1 text-right font-medium">B</th>
            <th className="px-2 py-1 text-right font-medium">Diff</th>
            <th className="border-l border-gray-200 px-2 py-1 text-right font-medium">A</th>
            <th className="px-2 py-1 text-right font-medium">B</th>
            <th className="px-2 py-1 text-right font-medium">Diff</th>
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {rows.map((row) => (
            <tr key={row.km} className="border-b border-gray-100 hover:bg-gray-50">
              <td className="py-2 pr-2 text-gray-500">{row.km}</td>
              <td className="border-l border-gray-200 px-2 py-2 text-right">
                {row.splitA ? formatPace(row.splitA.average_speed) : '--'}
              </td>
              <td className="px-2 py-2 text-right">
                {row.splitB ? formatPace(row.splitB.average_speed) : '--'}
              </td>
              <td className="px-2 py-2 text-right text-gray-400">
                {row.splitA && row.splitB
                  ? formatPaceDiff(row.splitA.average_speed, row.splitB.average_speed)
                  : '--'}
              </td>
              <td className="border-l border-gray-200 px-2 py-2 text-right">
                {formatHeartRate(row.splitA?.average_heartrate ?? undefined)}
              </td>
              <td className="px-2 py-2 text-right">
                {formatHeartRate(row.splitB?.average_heartrate ?? undefined)}
              </td>
              <td className="px-2 py-2 text-right text-gray-400">
                {formatHrDiff(row.splitA?.average_heartrate ?? null, row.splitB?.average_heartrate ?? null)}
              </td>
              <td className="border-l border-gray-200 px-2 py-2 text-right">
                {row.splitA ? formatDuration(row.cumA) : '--'}
              </td>
              <td className="px-2 py-2 text-right">
                {row.splitB ? formatDuration(row.cumB) : '--'}
              </td>
              <td className="px-2 py-2 text-right text-gray-400">
                {row.splitA && row.splitB
                  ? formatTimeDiff(row.cumA, row.cumB)
                  : '--'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
