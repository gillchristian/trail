import { Link } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { ActivitiesTable } from '../components/ActivitiesTable';
import { TrendsChart } from '../components/TrendsChart';
import { RefreshButton } from '../components/RefreshButton';
import { useActivities } from '../hooks/useActivities';

export function DashboardPage({ logout }: { logout: () => void }) {
  const { activities, loading, lastFetched, refresh } = useActivities(true);

  return (
    <Layout>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Cadence</h1>
          {lastFetched && (
            <p className="text-xs text-gray-400">
              Last updated: {new Date(lastFetched).toLocaleString()}
            </p>
          )}
        </div>
        <div className="flex items-center gap-2">
          <Link
            to="/log/ytd"
            className="rounded-md px-3 py-1.5 text-sm text-orange-600 hover:bg-orange-50 transition-colors"
          >
            Running Log
          </Link>
          <Link
            to="/compare"
            className="rounded-md px-3 py-1.5 text-sm text-orange-600 hover:bg-orange-50 transition-colors"
          >
            Compare Runs
          </Link>
          <RefreshButton loading={loading} onClick={refresh} />
          <button
            onClick={logout}
            className="rounded-md px-3 py-1.5 text-sm text-gray-500 hover:bg-gray-200 transition-colors"
          >
            Logout
          </button>
        </div>
      </div>
      <TrendsChart activities={activities} />
      <ActivitiesTable activities={activities} />
    </Layout>
  );
}
