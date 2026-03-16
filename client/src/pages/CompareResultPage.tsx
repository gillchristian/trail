import { Link, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { CompareChart } from '../components/CompareChart';
import { CompareTable } from '../components/CompareTable';
import { useCompareData } from '../hooks/useCompareData';
import { useCompareChartData } from '../hooks/useCompareChartData';
import { formatDistance, formatDuration, formatDate } from '../lib/format';
import { getSessionToken } from '../lib/api';

function ActivityBadge({ label, name, date, distance, time }: {
  label: string;
  name: string;
  date: string;
  distance: number;
  time: number;
}) {
  return (
    <div className="flex-1 rounded-md border border-gray-200 p-3">
      <p className="mb-1 text-xs font-medium text-gray-400">{label}</p>
      <p className="font-medium text-gray-900">{name}</p>
      <p className="text-sm text-gray-500">
        {formatDate(date)} &middot; {formatDistance(distance)} km &middot; {formatDuration(time)}
      </p>
    </div>
  );
}

export function CompareResultPage() {
  const { idA, idB } = useParams<{ idA: string; idB: string }>();
  const { data, loading, error } = useCompareData(idA!, idB!);
  const chartData = useCompareChartData(data);
  const isAuthenticated = !!getSessionToken();

  return (
    <Layout>
      {isAuthenticated && (
        <div className="mb-6">
          <Link to="/compare" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
            &larr; Compare another pair
          </Link>
        </div>
      )}

      {loading && (
        <p className="py-12 text-center text-gray-400">Loading activities...</p>
      )}

      {error && (
        <div className="py-12 text-center">
          <p className="mb-2 text-red-500">{error}</p>
          {isAuthenticated && (
            <Link to="/compare" className="text-sm text-orange-600 hover:underline">
              Try different activities
            </Link>
          )}
        </div>
      )}

      {data && (
        <>
          <div className="mb-6 flex gap-4">
            <ActivityBadge
              label="Activity A"
              name={data.a.activity.name}
              date={data.a.activity.start_date_local}
              distance={data.a.activity.distance}
              time={data.a.activity.moving_time}
            />
            <ActivityBadge
              label="Activity B"
              name={data.b.activity.name}
              date={data.b.activity.start_date_local}
              distance={data.b.activity.distance}
              time={data.b.activity.moving_time}
            />
          </div>

          <CompareChart
            data={chartData}
            nameA={data.a.activity.name}
            nameB={data.b.activity.name}
          />
          <CompareTable data={data} />
        </>
      )}
    </Layout>
  );
}
