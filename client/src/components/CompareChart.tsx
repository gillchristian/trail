import { useState } from 'react';
import { ResponsiveContainer, LineChart, XAxis, YAxis, Tooltip, Line, Legend } from 'recharts';
import type { CompareChartPoint } from '../hooks/useCompareChartData';

type Metric = 'pace' | 'hr' | 'time';

const METRICS: { key: Metric; label: string; color: string; keyA: keyof CompareChartPoint; keyB: keyof CompareChartPoint; rawA: keyof CompareChartPoint; rawB: keyof CompareChartPoint }[] = [
  { key: 'pace', label: 'Pace', color: '#3b82f6', keyA: 'paceA', keyB: 'paceB', rawA: 'rawPaceA', rawB: 'rawPaceB' },
  { key: 'hr', label: 'Heart Rate', color: '#ef4444', keyA: 'hrA', keyB: 'hrB', rawA: 'rawHrA', rawB: 'rawHrB' },
  { key: 'time', label: 'Time', color: '#10b981', keyA: 'timeA', keyB: 'timeB', rawA: 'rawTimeA', rawB: 'rawTimeB' },
];

function formatYAxis(value: number, metric: Metric): string {
  if (metric === 'pace') {
    const minutes = Math.floor(value / 60);
    const seconds = Math.round(value % 60);
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  }
  if (metric === 'hr') return String(Math.round(value));
  if (metric === 'time') {
    const h = Math.floor(value / 3600);
    const m = Math.floor((value % 3600) / 60);
    if (h > 0) return `${h}h${String(m).padStart(2, '0')}`;
    return `${m}m`;
  }
  return String(value);
}

function CustomTooltip({ active, payload, label, nameA, nameB, metric }: {
  active?: boolean;
  payload?: { dataKey: string; color: string; payload: CompareChartPoint }[];
  label?: string;
  nameA: string;
  nameB: string;
  metric: Metric;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload;
  const m = METRICS.find((m) => m.key === metric)!;

  return (
    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm shadow-md">
      <p className="mb-1 font-medium text-gray-700">km {label}</p>
      <p style={{ color: m.color }}>{nameA}: {data[m.rawA] as string}</p>
      <p style={{ color: m.color }} className="opacity-60">{nameB}: {data[m.rawB] as string}</p>
    </div>
  );
}

export function CompareChart({ data, nameA, nameB }: { data: CompareChartPoint[]; nameA: string; nameB: string }) {
  const [metric, setMetric] = useState<Metric>('pace');

  if (data.length === 0) return null;

  const m = METRICS.find((m) => m.key === metric)!;

  return (
    <div className="mb-8 rounded-lg bg-white p-4 shadow-sm">
      <div className="mb-4 flex gap-1">
        {METRICS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setMetric(tab.key)}
            className={`rounded-md px-3 py-1.5 text-sm transition-colors ${
              metric === tab.key
                ? 'bg-gray-900 text-white'
                : 'text-gray-500 hover:bg-gray-100'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data}>
          <XAxis dataKey="km" tick={{ fontSize: 12 }} />
          <YAxis
            tick={{ fontSize: 12 }}
            tickFormatter={(v) => formatYAxis(v, metric)}
            reversed={metric === 'pace'}
            domain={['auto', 'auto']}
          />
          <Tooltip content={<CustomTooltip nameA={nameA} nameB={nameB} metric={metric} />} />
          <Legend />
          <Line
            type="monotone"
            dataKey={m.keyA as string}
            name={nameA}
            stroke={m.color}
            strokeWidth={2}
            dot={{ r: 2 }}
            connectNulls
          />
          <Line
            type="monotone"
            dataKey={m.keyB as string}
            name={nameB}
            stroke={m.color}
            strokeWidth={2}
            strokeDasharray="5 5"
            dot={{ r: 2 }}
            connectNulls
            opacity={0.6}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
