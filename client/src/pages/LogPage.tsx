import { useState, useMemo } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LogBarChart } from '../components/LogBarChart';
import { LogCalendar } from '../components/LogCalendar';
import { ShareOverlay } from '../components/ShareOverlay';
import { useLogActivities } from '../hooks/useLogActivities';
import { parseRange, rangeToParam } from '../lib/dateRange';
import { formatDuration } from '../lib/format';

const PRESETS = [
  { key: '1m', label: '1M' },
  { key: '3m', label: '3M' },
  { key: 'ytd', label: 'YTD' },
  { key: '1y', label: '1Y' },
];

export function LogPage() {
  const { range: rangeParam = 'ytd' } = useParams<{ range: string }>();
  const navigate = useNavigate();
  const range = useMemo(() => parseRange(rangeParam), [rangeParam]);
  const { activities, loading } = useLogActivities(range);

  const [customFrom, setCustomFrom] = useState('');
  const [customTo, setCustomTo] = useState('');
  const [showShare, setShowShare] = useState(false);

  const stats = useMemo(() => {
    const totalDistance = activities.reduce((sum, a) => sum + a.distance, 0);
    const totalTime = activities.reduce((sum, a) => sum + a.moving_time, 0);
    return {
      totalKm: totalDistance / 1000,
      totalTime,
      count: activities.length,
    };
  }, [activities]);

  const handleCustomApply = () => {
    if (customFrom && customTo) {
      navigate(`/log/${rangeToParam(new Date(customFrom), new Date(customTo))}`);
    }
  };

  const isPreset = PRESETS.some((p) => p.key === rangeParam);

  return (
    <Layout>
      <div className="mb-6">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link to="/" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
              &larr; Dashboard
            </Link>
            <h1 className="text-2xl font-bold text-gray-900">Running Log</h1>
          </div>
          <button
            onClick={() => setShowShare(true)}
            className="rounded-md border border-gray-200 px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50 transition-colors"
          >
            Share
          </button>
        </div>

        {/* Range selector */}
        <div className="flex flex-wrap items-center gap-2">
          {PRESETS.map((p) => (
            <Link
              key={p.key}
              to={`/log/${p.key}`}
              className={`rounded-md px-3 py-1.5 text-sm transition-colors ${
                rangeParam === p.key
                  ? 'bg-orange-50 text-orange-600 font-medium'
                  : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
              }`}
            >
              {p.label}
            </Link>
          ))}
          <span className="mx-1 text-gray-300">|</span>
          <input
            type="date"
            value={customFrom}
            onChange={(e) => setCustomFrom(e.target.value)}
            className="rounded-md border border-gray-200 px-2 py-1 text-sm text-gray-600"
          />
          <span className="text-gray-400 text-sm">to</span>
          <input
            type="date"
            value={customTo}
            onChange={(e) => setCustomTo(e.target.value)}
            className="rounded-md border border-gray-200 px-2 py-1 text-sm text-gray-600"
          />
          <button
            onClick={handleCustomApply}
            disabled={!customFrom || !customTo}
            className="rounded-md bg-orange-500 px-3 py-1 text-sm text-white hover:bg-orange-600 transition-colors disabled:opacity-40"
          >
            Apply
          </button>
          {!isPreset && (
            <span className="ml-2 rounded-md bg-gray-100 px-2 py-1 text-xs text-gray-500">
              Custom range
            </span>
          )}
        </div>
      </div>

      {/* Summary stats */}
      {!loading && activities.length > 0 && (
        <div className="mb-6 flex gap-6 text-sm text-gray-600">
          <div>
            <span className="text-2xl font-bold text-gray-900">{stats.totalKm.toFixed(1)}</span>
            <span className="ml-1 text-gray-400">km</span>
          </div>
          <div>
            <span className="text-2xl font-bold text-gray-900">{formatDuration(stats.totalTime)}</span>
            <span className="ml-1 text-gray-400">time</span>
          </div>
          <div>
            <span className="text-2xl font-bold text-gray-900">{stats.count}</span>
            <span className="ml-1 text-gray-400">runs</span>
          </div>
        </div>
      )}

      {loading && (
        <div className="py-12 text-center text-gray-400">Loading activities...</div>
      )}

      {!loading && activities.length === 0 && (
        <div className="py-12 text-center text-gray-400">No activities found for this period.</div>
      )}

      {!loading && activities.length > 0 && (
        <>
          <LogBarChart activities={activities} />
          {range && <LogCalendar activities={activities} range={range} />}
        </>
      )}

      {showShare && range && (
        <ShareOverlay
          range={range}
          rangeParam={rangeParam}
          totalKm={stats.totalKm}
          onClose={() => setShowShare(false)}
        />
      )}
    </Layout>
  );
}
