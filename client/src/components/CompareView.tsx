import { useEffect, useMemo, type ReactNode } from 'react';
import { CompareChart } from './CompareChart';
import { CompareTable } from './CompareTable';
import { useActivityDetailCache } from '../hooks/useActivityDetailCache';
import { useMultiCompareChartData } from '../hooks/useMultiCompareChartData';
import { ACTIVITY_COLORS } from '../lib/colors';
import { formatDistance, formatDuration, formatDate } from '../lib/format';
import type { ActivityDetailResponse } from '../types';

interface Props {
  ids: string[];
  shareButton?: ReactNode;
  showActivityInfo?: boolean;
}

export function CompareView({ ids, shareButton, showActivityInfo }: Props) {
  const { data, loading, errors, fetchActivity } = useActivityDetailCache();

  useEffect(() => {
    for (const id of ids) {
      fetchActivity(id);
    }
  }, [ids, fetchActivity]);

  const activityEntries = useMemo(() => {
    return ids
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
  }, [ids, data]);

  const chartData = useMultiCompareChartData(activityEntries.map(e => e.detail));
  const chartActivities = activityEntries.map(e => ({
    name: e.detail.activity.name,
    color: e.color,
  }));

  const hasSelected = ids.length > 0;
  const anyLoading = ids.some(id => loading[id]);
  const failedIds = ids.filter(id => errors[id]);

  const mainContent = (
    <>
      {shareButton && activityEntries.length > 0 && (
        <div className="mb-4 flex justify-end">
          {shareButton}
        </div>
      )}

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
    </>
  );

  if (showActivityInfo && activityEntries.length > 0) {
    return (
      <div className="flex gap-8">
        <div className="min-w-0 flex-1">{mainContent}</div>
        <ActivityInfoPanel entries={activityEntries} />
      </div>
    );
  }

  return mainContent;
}

function ActivityInfoPanel({ entries }: {
  entries: { detail: ActivityDetailResponse; label: string; color: string }[];
}) {
  return (
    <div className="w-56 shrink-0">
      <div className="sticky top-8 space-y-3">
        {entries.map((entry) => (
          <div key={entry.detail.activity.id} className="rounded-md border border-gray-200 bg-white p-3">
            <div className="mb-1 flex items-center gap-2">
              <span
                className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
                style={{ backgroundColor: entry.color }}
              >
                {entry.label}
              </span>
              <p className="truncate text-sm font-medium text-gray-900">
                {entry.detail.activity.name}
              </p>
            </div>
            <p className="pl-7 text-xs text-gray-500">
              {formatDate(entry.detail.activity.start_date_local)} &middot; {formatDistance(entry.detail.activity.distance)} km &middot; {formatDuration(entry.detail.activity.moving_time)}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

function CompareSkeleton({ animate }: { animate: boolean }) {
  return (
    <div className={animate ? 'animate-pulse' : ''}>
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
