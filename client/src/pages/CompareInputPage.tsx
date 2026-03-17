import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { ActivitySearchPanel } from '../components/ActivitySearchPanel';
import { parseActivityId, isStravaShortLink } from '../lib/parseActivityId';
import { formatDistance, formatDate } from '../lib/format';
import { apiFetch } from '../lib/api';
import type { SearchResult } from '../types';

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
  const [selectedA, setSelectedA] = useState<SearchResult | null>(null);
  const [selectedB, setSelectedB] = useState<SearchResult | null>(null);
  const [showPaste, setShowPaste] = useState(false);
  const [inputA, setInputA] = useState('');
  const [inputB, setInputB] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [resolving, setResolving] = useState(false);

  const canCompare = selectedA && selectedB;

  const handleCompare = () => {
    if (selectedA && selectedB) {
      navigate(`/compare/${selectedA.id}/${selectedB.id}`);
    }
  };

  const handlePasteSubmit = async (e: React.FormEvent) => {
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

      <h1 className="mb-2 text-2xl font-bold text-gray-900">Compare Runs</h1>
      <p className="mb-6 text-gray-500">
        Select two runs to compare them km by km.
      </p>

      {/* Selection slots */}
      <div className="mb-4 grid grid-cols-2 gap-3">
        <SelectionSlot label="A" activity={selectedA} onClear={() => setSelectedA(null)} />
        <SelectionSlot label="B" activity={selectedB} onClear={() => setSelectedB(null)} />
      </div>

      {/* Compare button */}
      <button
        onClick={handleCompare}
        disabled={!canCompare}
        className="mb-6 w-full rounded-md bg-orange-500 py-2 text-sm font-medium text-white hover:bg-orange-600 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      >
        Compare
      </button>

      {/* Search panel */}
      <ActivitySearchPanel
        selectedA={selectedA}
        selectedB={selectedB}
        onSelectA={setSelectedA}
        onSelectB={setSelectedB}
      />

      {/* Paste URL toggle */}
      <div className="mt-6 border-t border-gray-200 pt-4">
        <button
          onClick={() => setShowPaste(!showPaste)}
          className="text-sm text-gray-400 hover:text-gray-600 transition-colors"
        >
          {showPaste ? 'Hide' : 'Or paste a Strava URL'}
        </button>

        {showPaste && (
          <form onSubmit={handlePasteSubmit} className="mt-3 space-y-3">
            <input
              type="text"
              value={inputA}
              onChange={(e) => { setInputA(e.target.value); setError(null); }}
              placeholder="Activity A — URL or ID"
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
            />
            <input
              type="text"
              value={inputB}
              onChange={(e) => { setInputB(e.target.value); setError(null); }}
              placeholder="Activity B — URL or ID"
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
            />
            {error && <p className="text-sm text-red-500">{error}</p>}
            <button
              type="submit"
              disabled={resolving}
              className="rounded-md bg-orange-500 px-6 py-2 text-sm font-medium text-white hover:bg-orange-600 transition-colors disabled:opacity-50"
            >
              {resolving ? 'Resolving...' : 'Compare'}
            </button>
          </form>
        )}
      </div>
    </Layout>
  );
}

function SelectionSlot({ label, activity, onClear }: { label: string; activity: SearchResult | null; onClear: () => void }) {
  if (!activity) {
    return (
      <div className="flex items-center justify-center rounded-md border-2 border-dashed border-gray-200 px-3 py-4">
        <span className="text-sm text-gray-400">Activity {label}</span>
      </div>
    );
  }

  return (
    <div className="relative rounded-md border border-orange-300 bg-orange-50 px-3 py-2">
      <button
        onClick={onClear}
        className="absolute top-1 right-1 flex h-5 w-5 items-center justify-center rounded-full text-gray-400 hover:bg-orange-100 hover:text-gray-600 transition-colors"
        aria-label={`Clear activity ${label}`}
      >
        &times;
      </button>
      <p className="truncate pr-5 text-sm font-medium text-gray-900">{activity.name}</p>
      <p className="text-xs text-gray-500">
        {formatDate(activity.start_date_local)} &middot; {formatDistance(activity.distance)} km
      </p>
    </div>
  );
}
