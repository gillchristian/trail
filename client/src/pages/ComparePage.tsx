import { useState, useMemo } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { ActivitySearchPanel } from '../components/ActivitySearchPanel';
import { CompareView } from '../components/CompareView';
import { parseActivityId, isStravaShortLink } from '../lib/parseActivityId';
import { encodeCompareIds } from '../lib/compareUrl';
import { ACTIVITY_COLORS } from '../lib/colors';
import { apiFetch } from '../lib/api';
import type { SearchResult } from '../types';

const MAX_ACTIVITIES = 10;

export function ComparePage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const idsParam = searchParams.get('ids') ?? '';
  const selectedIds = useMemo(
    () => idsParam ? [...new Set(idsParam.split(',').filter(Boolean))] : [],
    [idsParam],
  );

  const [inputValue, setInputValue] = useState('');
  const [resolving, setResolving] = useState(false);
  const [inputError, setInputError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

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

  const removeActivity = (id: string) => {
    setIds(selectedIds.filter(i => i !== id));
  };

  const toggleActivity = (activity: SearchResult) => {
    const id = String(activity.id);
    if (selectedIds.includes(id)) {
      removeActivity(id);
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

  const handleShare = () => {
    const encoded = encodeCompareIds(selectedIds);
    const url = `${window.location.origin}/compare/v/${encoded}`;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const shareButton = (
    <button
      onClick={handleShare}
      className="rounded-md border border-gray-200 px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50 transition-colors"
    >
      {copied ? 'Copied!' : 'Copy link'}
    </button>
  );

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Search sidebar */}
      <aside className="flex w-80 shrink-0 flex-col border-r border-gray-200 bg-white">
        <div className="border-b border-gray-200 px-4 py-3">
          <Link to="/" className="text-sm text-gray-400 hover:text-gray-600 transition-colors">
            &larr; Dashboard
          </Link>
          <h1 className="mt-1 text-lg font-bold text-gray-900">Compare Runs</h1>
        </div>
        <div className="flex min-h-0 flex-1 flex-col gap-3 p-4">
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
          <ActivitySearchPanel
            selectedIds={selectedIds}
            onToggle={toggleActivity}
            maxSelections={MAX_ACTIVITIES}
          />
        </div>
      </aside>

      {/* Selection column */}
      <SelectionColumn
        selectedIds={selectedIds}
        onRemove={removeActivity}
        onClear={() => setIds([])}
      />

      {/* Main content */}
      <main className="flex-1 overflow-auto p-8">
        <div className="mx-auto max-w-5xl">
          <CompareView ids={selectedIds} shareButton={shareButton} />
        </div>
      </main>
    </div>
  );
}

function SelectionColumn({ selectedIds, onRemove, onClear }: {
  selectedIds: string[];
  onRemove: (id: string) => void;
  onClear: () => void;
}) {
  return (
    <div className="flex w-48 shrink-0 flex-col border-r border-gray-200 bg-white">
      {selectedIds.length > 0 ? (
        <>
          <div className="flex items-center justify-between border-b border-gray-200 px-3 py-3">
            <span className="text-xs font-medium text-gray-500">
              Selected ({selectedIds.length})
            </span>
            <button
              onClick={onClear}
              className="text-xs text-gray-400 hover:text-red-500 transition-colors"
            >
              Clear
            </button>
          </div>
          <div className="flex-1 overflow-y-auto p-2">
            {selectedIds.map((id, i) => (
              <div
                key={id}
                className="group flex items-center gap-2 rounded px-2 py-1.5 hover:bg-gray-50"
              >
                <span
                  className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
                  style={{ backgroundColor: ACTIVITY_COLORS[i % ACTIVITY_COLORS.length] }}
                >
                  {String.fromCharCode(65 + i)}
                </span>
                <span className="min-w-0 flex-1 truncate text-xs text-gray-700">
                  {id}
                </span>
                <button
                  onClick={() => onRemove(id)}
                  className="shrink-0 text-gray-300 opacity-0 group-hover:opacity-100 hover:text-red-500 transition-all"
                  aria-label="Remove"
                >
                  &times;
                </button>
              </div>
            ))}
          </div>
        </>
      ) : (
        <div className="flex flex-1 items-start px-3 pt-4">
          <p className="text-xs text-gray-400">
            Click activities to add them here
          </p>
        </div>
      )}
    </div>
  );
}
