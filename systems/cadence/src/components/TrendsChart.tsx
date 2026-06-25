import { useState } from 'react';
import { ResponsiveContainer, LineChart, XAxis, Tooltip, Legend, Line } from 'recharts';
import type { StravaActivity } from '../types';
import { useChartData, type ChartDataPoint } from '../hooks/useChartData';

const LINES = [
  { key: 'distance', name: 'Distance', color: '#f97316', rawKey: 'rawDistance' },
  { key: 'pace', name: 'Pace', color: '#3b82f6', rawKey: 'rawPace' },
  { key: 'duration', name: 'Duration', color: '#10b981', rawKey: 'rawDuration' },
  { key: 'hr', name: 'Avg HR', color: '#ef4444', rawKey: 'rawHr' },
] as const;

function CustomTooltip({ active, payload, label }: {
  active?: boolean;
  payload?: { dataKey: string; color: string; payload: ChartDataPoint }[];
  label?: string;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload;
  return (
    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm shadow-md">
      <p className="mb-1 font-medium text-gray-700">{label}</p>
      {payload.map((entry) => {
        const line = LINES.find((l) => l.key === entry.dataKey);
        if (!line) return null;
        const raw = data[line.rawKey];
        if (raw === '--') return null;
        return (
          <p key={line.key} style={{ color: entry.color }}>
            {line.name}: {raw}
          </p>
        );
      })}
    </div>
  );
}

export function TrendsChart({ activities }: { activities: StravaActivity[] }) {
  const chartData = useChartData(activities);
  const [hidden, setHidden] = useState<Set<string>>(new Set());

  if (chartData.length === 0) return null;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const handleLegendClick = (entry: any) => {
    const key = entry.dataKey as string | undefined;
    if (!key) return;
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  return (
    <div className="mb-8 rounded-lg bg-white p-4 shadow-sm">
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" tick={{ fontSize: 12 }} />
          <Tooltip content={<CustomTooltip />} />
          <Legend
            onClick={handleLegendClick}
            wrapperStyle={{ cursor: 'pointer' }}
          />
          {LINES.map((line) => (
            <Line
              key={line.key}
              type="monotone"
              dataKey={line.key}
              name={line.name}
              stroke={line.color}
              strokeWidth={2}
              dot={{ r: 3 }}
              connectNulls
              hide={hidden.has(line.key)}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
