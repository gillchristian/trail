import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { parseActivityId, isStravaShortLink } from '../lib/parseActivityId';
import { apiFetch } from '../lib/api';

async function resolveInput(input: string): Promise<string | null> {
  const id = parseActivityId(input);
  if (id) return id;

  if (isStravaShortLink(input)) {
    const res = await apiFetch<{ id: string }>(`/api/resolve-link?url=${encodeURIComponent(input.trim())}`);
    return res.id;
  }

  return null;
}

export function CompareInputPage() {
  const navigate = useNavigate();
  const [inputA, setInputA] = useState('');
  const [inputB, setInputB] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [resolving, setResolving] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setResolving(true);

    try {
      const [idA, idB] = await Promise.all([resolveInput(inputA), resolveInput(inputB)]);

      if (!idA || !idB) {
        setError('Please enter valid Strava activity URLs or IDs');
        setResolving(false);
        return;
      }

      navigate(`/compare/${idA}/${idB}`);
    } catch {
      setError('Failed to resolve one or more Strava links');
      setResolving(false);
    }
  };

  return (
    <Layout>
      <div className="mb-6">
        <Link to="/" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
          &larr; Back to dashboard
        </Link>
      </div>

      <h1 className="mb-2 text-2xl font-bold text-gray-900">Compare Two Runs</h1>
      <p className="mb-8 text-gray-500">
        Paste two Strava activity URLs or IDs to compare them km by km.
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="activityA" className="mb-1 block text-sm font-medium text-gray-700">
            Activity A
          </label>
          <input
            id="activityA"
            type="text"
            value={inputA}
            onChange={(e) => { setInputA(e.target.value); setError(null); }}
            placeholder="https://www.strava.com/activities/123456789"
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
          />
        </div>
        <div>
          <label htmlFor="activityB" className="mb-1 block text-sm font-medium text-gray-700">
            Activity B
          </label>
          <input
            id="activityB"
            type="text"
            value={inputB}
            onChange={(e) => { setInputB(e.target.value); setError(null); }}
            placeholder="https://www.strava.com/activities/987654321"
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
          />
        </div>

        {error && (
          <p className="text-sm text-red-500">{error}</p>
        )}

        <button
          type="submit"
          disabled={resolving}
          className="rounded-md bg-orange-500 px-6 py-2 text-sm font-medium text-white hover:bg-orange-600 transition-colors disabled:opacity-50"
        >
          {resolving ? 'Resolving...' : 'Compare'}
        </button>
      </form>
    </Layout>
  );
}
