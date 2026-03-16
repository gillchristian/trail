import { useState, useEffect } from 'react';
import { apiFetch, AuthError } from '../lib/api';
import type { ActivityDetailResponse } from '../types';

export interface ComparisonData {
  a: ActivityDetailResponse;
  b: ActivityDetailResponse;
}

export function useCompareData(idA: string, idB: string) {
  const [data, setData] = useState<ComparisonData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    setData(null);

    Promise.all([
      apiFetch<ActivityDetailResponse>(`/api/activities/${idA}/detail`),
      apiFetch<ActivityDetailResponse>(`/api/activities/${idB}/detail`),
    ])
      .then(([a, b]) => {
        if (!cancelled) {
          setData({ a, b });
          setLoading(false);
        }
      })
      .catch((err) => {
        if (cancelled) return;
        if (err instanceof AuthError) {
          setError('Authentication required. This activity may not be cached yet.');
          setLoading(false);
          return;
        }
        setError(err.message || 'Failed to fetch activity data');
        setLoading(false);
      });

    return () => { cancelled = true; };
  }, [idA, idB]);

  return { data, loading, error };
}
