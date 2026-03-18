import { useState, useMemo } from 'react';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip } from 'recharts';
import type { StravaActivity } from '../types';
import { groupByWeek } from '../lib/dateRange';
import { formatPace } from '../lib/format';

type Mode = 'activities' | 'weekly';

interface ActivityPoint {
  date: string;
  distance: number;
  name: string;
  pace: string;
}

interface WeeklyPoint {
  week: string;
  distance: number;
  runs: number;
}

function ActivityTooltip({ active, payload }: { active?: boolean; payload?: { payload: ActivityPoint }[] }) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm shadow-md">
      <p className="font-medium text-gray-700">{d.date}</p>
      <p className="text-gray-600">{d.name}</p>
      <p style={{ color: '#f97316' }}>{d.distance.toFixed(2)} km</p>
      <p className="text-gray-500">{d.pace} /km</p>
    </div>
  );
}

function WeeklyTooltip({ active, payload }: { active?: boolean; payload?: { payload: WeeklyPoint }[] }) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm shadow-md">
      <p className="font-medium text-gray-700">Week of {d.week}</p>
      <p style={{ color: '#f97316' }}>{d.distance.toFixed(1)} km</p>
      <p className="text-gray-500">{d.runs} run{d.runs !== 1 ? 's' : ''}</p>
    </div>
  );
}

export function LogBarChart({ activities }: { activities: StravaActivity[] }) {
  const [mode, setMode] = useState<Mode>('weekly');

  const activityData = useMemo((): ActivityPoint[] => {
    return [...activities]
      .sort((a, b) => a.start_date_local.localeCompare(b.start_date_local))
      .map((a) => ({
        date: new Date(a.start_date_local).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
        distance: a.distance / 1000,
        name: a.name,
        pace: formatPace(a.average_speed),
      }));
  }, [activities]);

  const weeklyData = useMemo((): WeeklyPoint[] => {
    const weeks = groupByWeek(activities);
    return [...weeks.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([weekStart, acts]) => ({
        week: new Date(weekStart + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
        distance: acts.reduce((sum, a) => sum + a.distance, 0) / 1000,
        runs: acts.length,
      }));
  }, [activities]);

  if (activities.length === 0) return null;

  const data = mode === 'activities' ? activityData : weeklyData;

  return (
    <div className="mb-8 rounded-lg bg-white p-4 shadow-sm">
      <div className="mb-4 flex items-center gap-1">
        {(['activities', 'weekly'] as const).map((m) => (
          <button
            key={m}
            onClick={() => setMode(m)}
            className={`rounded-md px-3 py-1 text-sm transition-colors ${
              mode === m
                ? 'bg-orange-50 text-orange-600 font-medium'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {m === 'activities' ? 'Activities' : 'Weekly'}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data}>
          <XAxis
            dataKey={mode === 'activities' ? 'date' : 'week'}
            tick={{ fontSize: 11 }}
            interval="preserveStartEnd"
          />
          <YAxis
            tick={{ fontSize: 12 }}
            tickFormatter={(v: number) => `${v}`}
            label={{ value: 'km', angle: -90, position: 'insideLeft', style: { fontSize: 12 } }}
          />
          <Tooltip
            content={mode === 'activities' ? <ActivityTooltip /> : <WeeklyTooltip />}
          />
          <Bar dataKey="distance" fill="#f97316" radius={[2, 2, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
