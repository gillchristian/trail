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
  const [inputA, setInputA] = useState('');
  const [inputB, setInputB] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [resolving, setResolving] = useState<'A' | 'B' | null>(null);

  const canCompare = selectedA && selectedB;

  const handleCompare = () => {
    if (selectedA && selectedB) {
      navigate(`/compare/${selectedA.id}/${selectedB.id}`);
    }
  };

  const handlePasteResolve = async (input: string, slot: 'A' | 'B') => {
    if (!input.trim()) return;
    setError(null);
    setResolving(slot);

    try {
      const id = await resolveInput(input.trim());
      if (!id) {
        setError('Could not resolve activity URL or ID');
        setResolving(null);
        return;
      }
      const result: SearchResult = {
        id: Number(id),
        name: `Activity ${id}`,
        distance: 0,
        moving_time: 0,
        start_date_local: '',
        sport_type: 'Run',
      };
      if (slot === 'A') {
        setSelectedA(result);
        setInputA('');
      } else {
        setSelectedB(result);
        setInputB('');
      }
    } catch {
      setError('Failed to resolve Strava link');
    } finally {
      setResolving(null);
    }
  };

  return (
    <Layout>
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="mb-6">
          <Link to="/" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
            &larr; Back to dashboard
          </Link>
        </div>

        <h1 className="mb-2 text-2xl font-bold text-gray-900">Compare Runs</h1>
        <p className="mb-4 text-gray-500">
          Select two runs to compare them km by km.
        </p>

        {/* Selection slots — inputs when empty, cards when filled */}
        <div className="mb-3 grid grid-cols-2 gap-3">
          <SelectionSlot
            label="A"
            activity={selectedA}
            input={inputA}
            onInputChange={(v) => { setInputA(v); setError(null); }}
            onResolve={() => handlePasteResolve(inputA, 'A')}
            onClear={() => setSelectedA(null)}
            resolving={resolving === 'A'}
          />
          <SelectionSlot
            label="B"
            activity={selectedB}
            input={inputB}
            onInputChange={(v) => { setInputB(v); setError(null); }}
            onResolve={() => handlePasteResolve(inputB, 'B')}
            onClear={() => setSelectedB(null)}
            resolving={resolving === 'B'}
          />
        </div>

        {error && <p className="mb-3 text-sm text-red-500">{error}</p>}

        {/* Compare button */}
        <button
          onClick={handleCompare}
          disabled={!canCompare}
          className="mb-4 w-full rounded-md bg-orange-500 py-2 text-sm font-medium text-white hover:bg-orange-600 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
        >
          Compare
        </button>

        {/* Search panel — fills remaining height */}
        <ActivitySearchPanel
          selectedA={selectedA}
          selectedB={selectedB}
          onSelectA={setSelectedA}
          onSelectB={setSelectedB}
        />
      </div>
    </Layout>
  );
}

interface SlotProps {
  label: string;
  activity: SearchResult | null;
  input: string;
  onInputChange: (value: string) => void;
  onResolve: () => void;
  onClear: () => void;
  resolving: boolean;
}

function SelectionSlot({ label, activity, input, onInputChange, onResolve, onClear, resolving }: SlotProps) {
  if (!activity) {
    return (
      <input
        type="text"
        value={input}
        onChange={(e) => onInputChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); onResolve(); } }}
        placeholder={`Activity ${label} — URL or ID`}
        disabled={resolving}
        className="w-full rounded-md border border-gray-300 px-3 py-3 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500 disabled:opacity-50"
      />
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
      {activity.start_date_local && (
        <p className="text-xs text-gray-500">
          {formatDate(activity.start_date_local)} &middot; {formatDistance(activity.distance)} km
        </p>
      )}
    </div>
  );
}
