import { useEffect, useMemo, type ReactNode } from 'react';
import { CompareChart } from './CompareChart';
import { CompareTable } from './CompareTable';
import { useActivityDetailCache } from '../hooks/useActivityDetailCache';
import { useMultiCompareChartData } from '../hooks/useMultiCompareChartData';
import { ACTIVITY_COLORS } from '../lib/colors';

interface Props {
  ids: string[];
  shareButton?: ReactNode;
}

export function CompareView({ ids, shareButton }: Props) {
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

  return (
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
