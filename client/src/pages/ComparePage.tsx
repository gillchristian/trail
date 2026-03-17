import { useState, useEffect, useMemo } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { ActivitySearchPanel } from '../components/ActivitySearchPanel';
import { CompareChart } from '../components/CompareChart';
import { CompareTable } from '../components/CompareTable';
import { useActivityDetailCache } from '../hooks/useActivityDetailCache';
import { useMultiCompareChartData } from '../hooks/useMultiCompareChartData';
import { parseActivityId, isStravaShortLink } from '../lib/parseActivityId';
import { apiFetch } from '../lib/api';
import type { SearchResult } from '../types';

const ACTIVITY_COLORS = [
  '#f97316', '#3b82f6', '#10b981', '#8b5cf6', '#ef4444',
  '#06b6d4', '#f59e0b', '#ec4899', '#6366f1', '#14b8a6',
];

const MAX_ACTIVITIES = 10;

export function ComparePage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const idsParam = searchParams.get('ids') ?? '';
  const selectedIds = useMemo(
    () => idsParam ? [...new Set(idsParam.split(',').filter(Boolean))] : [],
    [idsParam],
  );

  const { data, loading, errors, fetchActivity } = useActivityDetailCache();
  const [inputValue, setInputValue] = useState('');
  const [resolving, setResolving] = useState(false);
  const [inputError, setInputError] = useState<string | null>(null);

  // Fetch data for all selected activities
  useEffect(() => {
    for (const id of selectedIds) {
      fetchActivity(id);
    }
  }, [selectedIds, fetchActivity]);

  const setIds = (ids: string[]) => {
    if (ids.length > 0) {
      setSearchParams({ ids: ids.join(',') }, { replace: true });
    } else {
      setSearchParams({}, { replace: true });
    }
  };

  const addActivity = (id: string) => {
    if (selectedIds.includes(id) || selectedIds.length >= MAX_ACTIVITIES) return;
    setIds([...selectedIds, id]);
  };

  const toggleActivity = (activity: SearchResult) => {
    const id = String(activity.id);
    if (selectedIds.includes(id)) {
      setIds(selectedIds.filter(i => i !== id));
    } else {
      addActivity(id);
    }
  };

  const handleInputChange = async (value: string) => {
    setInputValue(value);
    setInputError(null);
    if (!value.trim()) return;

    const id = parseActivityId(value.trim());
    if (id) {
      addActivity(id);
      setInputValue('');
      return;
    }

    if (isStravaShortLink(value.trim())) {
      setResolving(true);
      try {
        const res = await apiFetch<{ id: string }>(
          `/api/resolve-link?url=${encodeURIComponent(value.trim())}`,
        );
        addActivity(res.id);
        setInputValue('');
      } catch {
        setInputError('Failed to resolve link');
      } finally {
        setResolving(false);
      }
    }
  };

  // Build entries preserving selectedIds order and original index for stable colors/labels
  const activityEntries = useMemo(() => {
    return selectedIds
      .map((id, i) => {
        const detail = data[id];
        if (!detail) return null;
        return {
          detail,
          label: String.fromCharCode(65 + i),
          color: ACTIVITY_COLORS[i % ACTIVITY_COLORS.length],
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);
  }, [selectedIds, data]);

  const chartData = useMultiCompareChartData(activityEntries.map(e => e.detail));
  const chartActivities = activityEntries.map(e => ({
    name: e.detail.activity.name,
    color: e.color,
  }));

  const hasSelected = selectedIds.length > 0;
  const anyLoading = selectedIds.some(id => loading[id]);
  const failedIds = selectedIds.filter(id => errors[id]);

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="flex w-80 shrink-0 flex-col border-r border-gray-200 bg-white">
        <div className="border-b border-gray-200 px-4 py-3">
          <Link to="/" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
            &larr; Dashboard
          </Link>
          <h1 className="mt-1 text-lg font-bold text-gray-900">Compare Runs</h1>
        </div>
        <div className="flex min-h-0 flex-1 flex-col gap-3 p-4">
          {/* URL/ID input */}
          <div>
            <input
              type="text"
              value={inputValue}
              onChange={(e) => handleInputChange(e.target.value)}
              placeholder="Add by URL or ID"
              disabled={resolving || selectedIds.length >= MAX_ACTIVITIES}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500 disabled:opacity-50"
            />
            {inputError && <p className="mt-1 text-xs text-red-500">{inputError}</p>}
            {resolving && <p className="mt-1 text-xs text-gray-400">Resolving link...</p>}
          </div>

          {/* Activity search panel */}
          <ActivitySearchPanel
            selectedIds={selectedIds}
            onToggle={toggleActivity}
            maxSelections={MAX_ACTIVITIES}
          />
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto p-8">
        <div className="mx-auto max-w-5xl">
          {!hasSelected && <CompareSkeleton animate={false} />}
          {hasSelected && activityEntries.length === 0 && anyLoading && (
            <CompareSkeleton animate />
          )}

          {failedIds.length > 0 && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-3">
              {failedIds.map(id => (
                <p key={id} className="text-sm text-red-600">
                  Activity {id}: {errors[id]}
                </p>
              ))}
            </div>
          )}

          {activityEntries.length > 0 && (
            <>
              <CompareChart data={chartData} activities={chartActivities} />
              <CompareTable entries={activityEntries} />
            </>
          )}

          {activityEntries.length > 0 && anyLoading && (
            <p className="mt-4 text-center text-sm text-gray-400">Loading more activities...</p>
          )}
        </div>
      </main>
    </div>
  );
}

function CompareSkeleton({ animate }: { animate: boolean }) {
  return (
    <div className={animate ? 'animate-pulse' : ''}>
      {/* Chart skeleton */}
      <div className="mb-8 rounded-lg bg-white shadow-sm">
        <div className="border-b border-gray-200 p-3">
          <div className="flex justify-center gap-8">
            <div className="h-4 w-12 rounded bg-gray-200" />
            <div className="h-4 w-20 rounded bg-gray-200" />
            <div className="h-4 w-12 rounded bg-gray-200" />
          </div>
        </div>
        <div className="p-4">
          <div className="h-[300px] rounded bg-gray-100" />
        </div>
      </div>
      {/* Table skeleton */}
      <div className="rounded-lg bg-white p-4 shadow-sm">
        <div className="space-y-3">
          <div className="flex gap-4">
            <div className="h-4 w-8 rounded bg-gray-200" />
            <div className="h-4 flex-1 rounded bg-gray-200" />
            <div className="h-4 flex-1 rounded bg-gray-200" />
            <div className="h-4 flex-1 rounded bg-gray-200" />
          </div>
          {Array.from({ length: 8 }, (_, i) => (
            <div key={i} className="flex gap-4">
              <div className="h-4 w-8 rounded bg-gray-100" />
              <div className="h-4 flex-1 rounded bg-gray-100" />
              <div className="h-4 flex-1 rounded bg-gray-100" />
              <div className="h-4 flex-1 rounded bg-gray-100" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
