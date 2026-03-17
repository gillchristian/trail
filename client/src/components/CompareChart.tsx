import { useState } from 'react';
import { ResponsiveContainer, LineChart, XAxis, YAxis, Tooltip, Line, Legend } from 'recharts';
import type { MultiCompareChartPoint } from '../hooks/useMultiCompareChartData';

type Metric = 'pace' | 'hr' | 'time';

const METRICS: { key: Metric; label: string }[] = [
  { key: 'pace', label: 'Pace' },
  { key: 'hr', label: 'Heart Rate' },
  { key: 'time', label: 'Time' },
];

const RAW_KEY_PREFIX: Record<Metric, string> = {
  pace: 'rawPace',
  hr: 'rawHr',
  time: 'rawTime',
};

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

interface ActivityInfo {
  name: string;
  color: string;
}

function CustomTooltip({ active, payload, label, activities, metric }: {
  active?: boolean;
  payload?: { payload: MultiCompareChartPoint }[];
  label?: string;
  activities: ActivityInfo[];
  metric: Metric;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload;
  const prefix = RAW_KEY_PREFIX[metric];

  return (
    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm shadow-md">
      <p className="mb-1 font-medium text-gray-700">km {label}</p>
      {activities.map((a, i) => (
        <p key={i} style={{ color: a.color }}>
          {a.name}: {String(data[`${prefix}_${i}`])}
        </p>
      ))}
    </div>
  );
}

export function CompareChart({ data, activities }: { data: MultiCompareChartPoint[]; activities: ActivityInfo[] }) {
  const [metric, setMetric] = useState<Metric>('pace');

  if (data.length === 0) return null;

  return (
    <div className="mb-8 rounded-lg bg-white shadow-sm">
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex justify-center space-x-8">
          {METRICS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setMetric(tab.key)}
              className={`border-b-2 px-1 py-3 text-sm font-medium whitespace-nowrap transition-colors ${
                metric === tab.key
                  ? 'border-orange-500 text-orange-600'
                  : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>
      <div className="p-4">
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={data}>
            <XAxis dataKey="km" tick={{ fontSize: 12 }} />
            <YAxis
              tick={{ fontSize: 12 }}
              tickFormatter={(v) => formatYAxis(v, metric)}
              reversed={metric === 'pace'}
              domain={['auto', 'auto']}
            />
            <Tooltip content={<CustomTooltip activities={activities} metric={metric} />} />
            <Legend
              content={() => (
                <div className="flex flex-wrap justify-center gap-4 pt-2 text-sm">
                  {activities.map((a, i) => (
                    <span key={i} className="flex items-center gap-1.5">
                      <svg width="16" height="2">
                        <line x1="0" y1="1" x2="16" y2="1" stroke={a.color} strokeWidth="2" />
                      </svg>
                      <span style={{ color: a.color }}>{a.name}</span>
                    </span>
                  ))}
                </div>
              )}
            />
            {activities.map((a, i) => (
              <Line
                key={i}
                type="monotone"
                dataKey={`${metric}_${i}`}
                name={a.name}
                stroke={a.color}
                strokeWidth={2}
                dot={{ r: 2 }}
                connectNulls
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
