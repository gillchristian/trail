import { useMemo } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { CompareView } from '../components/CompareView';
import { decodeCompareIds } from '../lib/compareUrl';
import { getSessionToken } from '../lib/api';

export function CompareSharePage() {
  const { encoded } = useParams<{ encoded: string }>();
  const ids = useMemo(() => decodeCompareIds(encoded ?? ''), [encoded]);
  const isAuthenticated = !!getSessionToken();

  if (ids.length === 0) {
    return (
      <Layout>
        <p className="py-12 text-center text-gray-400">Invalid comparison link.</p>
      </Layout>
    );
  }

  return (
    <Layout>
      {isAuthenticated && (
        <div className="mb-6">
          <Link to="/compare" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
            &larr; Compare your own
          </Link>
        </div>
      )}
      <CompareView ids={ids} />
    </Layout>
  );
}
