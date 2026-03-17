import { useState, useCallback } from 'react';
import { useActivitySearch } from '../hooks/useActivitySearch';
import { useBackfill } from '../hooks/useBackfill';
import { DISTANCE_PRESETS } from '../lib/distances';
import { formatDistance, formatDuration, formatDate } from '../lib/format';
import type { SearchResult } from '../types';

interface Props {
  selectedA: SearchResult | null;
  selectedB: SearchResult | null;
  onSelectA: (activity: SearchResult) => void;
  onSelectB: (activity: SearchResult) => void;
}

const SLIDER_MAX_KM = 100;
const SLIDER_STEP_KM = 1;

export function ActivitySearchPanel({ selectedA, selectedB, onSelectA, onSelectB }: Props) {
  const { results, total, loading, filters, setFilters, loadMore, hasMore } = useActivitySearch();
  const { syncing, totalStored } = useBackfill();
  const [activePreset, setActivePreset] = useState<string | null>(null);
  const [sliderMin, setSliderMin] = useState(0);
  const [sliderMax, setSliderMax] = useState(SLIDER_MAX_KM);
  const [textQuery, setTextQuery] = useState('');

  const handlePresetClick = useCallback((preset: typeof DISTANCE_PRESETS[number]) => {
    if (activePreset === preset.label) {
      // Deselect
      setActivePreset(null);
      setSliderMin(0);
      setSliderMax(SLIDER_MAX_KM);
      setFilters({ ...filters, minDistance: undefined, maxDistance: undefined });
    } else {
      setActivePreset(preset.label);
      const minKm = Math.round(preset.min / 1000);
      const maxKm = preset.max > 0 ? Math.round(preset.max / 1000) : SLIDER_MAX_KM;
      setSliderMin(minKm);
      setSliderMax(maxKm);
      setFilters({
        ...filters,
        minDistance: preset.min,
        maxDistance: preset.max || undefined,
      });
    }
  }, [activePreset, filters, setFilters]);

  const handleSliderMinChange = useCallback((value: number) => {
    const clamped = Math.min(value, sliderMax - SLIDER_STEP_KM);
    setSliderMin(clamped);
    setActivePreset(null);
    setFilters({
      ...filters,
      minDistance: clamped > 0 ? clamped * 1000 : undefined,
      maxDistance: sliderMax < SLIDER_MAX_KM ? sliderMax * 1000 : undefined,
    });
  }, [sliderMax, filters, setFilters]);

  const handleSliderMaxChange = useCallback((value: number) => {
    const clamped = Math.max(value, sliderMin + SLIDER_STEP_KM);
    setSliderMax(clamped);
    setActivePreset(null);
    setFilters({
      ...filters,
      minDistance: sliderMin > 0 ? sliderMin * 1000 : undefined,
      maxDistance: clamped < SLIDER_MAX_KM ? clamped * 1000 : undefined,
    });
  }, [sliderMin, filters, setFilters]);

  const handleTextChange = useCallback((value: string) => {
    setTextQuery(value);
    setFilters({ ...filters, query: value || undefined });
  }, [filters, setFilters]);

  const isSelected = (id: number) => selectedA?.id === id || selectedB?.id === id;

  return (
    <div className="space-y-4">
      {/* Sync indicator */}
      {syncing && (
        <p className="text-xs text-gray-400">
          Syncing history... {totalStored} activities
        </p>
      )}

      {/* Text search */}
      <input
        type="text"
        value={textQuery}
        onChange={(e) => handleTextChange(e.target.value)}
        placeholder="Search by name..."
        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm placeholder-gray-400 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
      />

      {/* Preset distance pills */}
      <div className="flex flex-wrap gap-2">
        {DISTANCE_PRESETS.map((preset) => (
          <button
            key={preset.label}
            onClick={() => handlePresetClick(preset)}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              activePreset === preset.label
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {preset.label}
          </button>
        ))}
      </div>

      {/* Distance range slider */}
      <div className="space-y-1">
        <div className="flex justify-between text-xs text-gray-500">
          <span>{sliderMin} km</span>
          <span>{sliderMax >= SLIDER_MAX_KM ? '100+ km' : `${sliderMax} km`}</span>
        </div>
        <div className="relative h-6">
          <input
            type="range"
            min={0}
            max={SLIDER_MAX_KM}
            step={SLIDER_STEP_KM}
            value={sliderMin}
            onChange={(e) => handleSliderMinChange(Number(e.target.value))}
            className="pointer-events-none absolute inset-0 w-full appearance-none bg-transparent [&::-webkit-slider-thumb]:pointer-events-auto [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-orange-500"
          />
          <input
            type="range"
            min={0}
            max={SLIDER_MAX_KM}
            step={SLIDER_STEP_KM}
            value={sliderMax}
            onChange={(e) => handleSliderMaxChange(Number(e.target.value))}
            className="pointer-events-none absolute inset-0 w-full appearance-none bg-transparent [&::-webkit-slider-thumb]:pointer-events-auto [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-orange-500"
          />
          {/* Track background */}
          <div className="pointer-events-none absolute top-1/2 h-1 w-full -translate-y-1/2 rounded bg-gray-200">
            <div
              className="absolute h-full rounded bg-orange-500"
              style={{
                left: `${(sliderMin / SLIDER_MAX_KM) * 100}%`,
                right: `${100 - (sliderMax / SLIDER_MAX_KM) * 100}%`,
              }}
            />
          </div>
        </div>
      </div>

      {/* Results */}
      <div className="max-h-80 space-y-1 overflow-y-auto">
        {results.map((activity) => (
          <div
            key={activity.id}
            className={`flex items-center justify-between rounded-md border px-3 py-2 ${
              isSelected(activity.id)
                ? 'border-orange-300 bg-orange-50'
                : 'border-gray-200 hover:bg-gray-50'
            }`}
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-gray-900">{activity.name}</p>
              <p className="text-xs text-gray-500">
                {formatDate(activity.start_date_local)} &middot; {formatDistance(activity.distance)} km &middot; {formatDuration(activity.moving_time)}
              </p>
            </div>
            <div className="ml-2 flex gap-1">
              <button
                onClick={() => onSelectA(activity)}
                disabled={selectedA?.id === activity.id}
                className={`rounded px-2 py-0.5 text-xs font-medium transition-colors ${
                  selectedA?.id === activity.id
                    ? 'bg-orange-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-orange-100 hover:text-orange-700'
                }`}
              >
                A
              </button>
              <button
                onClick={() => onSelectB(activity)}
                disabled={selectedB?.id === activity.id}
                className={`rounded px-2 py-0.5 text-xs font-medium transition-colors ${
                  selectedB?.id === activity.id
                    ? 'bg-orange-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-orange-100 hover:text-orange-700'
                }`}
              >
                B
              </button>
            </div>
          </div>
        ))}

        {loading && (
          <p className="py-2 text-center text-xs text-gray-400">Loading...</p>
        )}

        {!loading && results.length === 0 && (
          <p className="py-4 text-center text-sm text-gray-400">
            {filters.minDistance || filters.maxDistance || filters.query
              ? 'No matching activities found'
              : 'No activities yet'}
          </p>
        )}
      </div>

      {hasMore && !loading && (
        <button
          onClick={loadMore}
          className="w-full rounded-md border border-gray-200 py-1.5 text-xs text-gray-500 hover:bg-gray-50 transition-colors"
        >
          Load more ({total - results.length} remaining)
        </button>
      )}
    </div>
  );
}
