import { useMemo } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CompareView } from '../components/CompareView';
import { decodeCompareIds } from '../lib/compareUrl';
import { getSessionToken } from '../lib/api';

export function CompareSharePage() {
  const { encoded } = useParams<{ encoded: string }>();
  const ids = useMemo(() => decodeCompareIds(encoded ?? ''), [encoded]);
  const isAuthenticated = !!getSessionToken();

  if (ids.length === 0) {
    return (
      <div className="flex min-h-screen flex-col bg-gray-50">
        <div className="mx-auto w-full max-w-4xl flex-1 px-4 py-8">
          <p className="py-12 text-center text-gray-400">Invalid comparison link.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col bg-gray-50">
      <div className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">
        {isAuthenticated && (
          <div className="mb-6">
            <Link to="/compare" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
              &larr; Compare your own
            </Link>
          </div>
        )}
        <CompareView ids={ids} showActivityInfo />
      </div>
      <footer className="py-6 text-center text-sm text-gray-400">
        <p>
          <a href="https://instagram.com/run.the.process" className="hover:text-gray-600 transition-colors">run.the.process</a>
        </p>
        <p>
          <a href="https://gillchristian.xyz" className="hover:text-gray-600 transition-colors">@gillchristian</a> &copy; {new Date().getFullYear()}
        </p>
      </footer>
    </div>
  );
}
