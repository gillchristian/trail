import { useRef, useCallback, useState } from 'react';
import { apiFetch } from '../lib/api';
import type { ActivityDetailResponse } from '../types';

export function useActivityDetailCache() {
  const cache = useRef<Record<string, Promise<ActivityDetailResponse>>>({});
  const [data, setData] = useState<Record<string, ActivityDetailResponse>>({});
  const [loading, setLoading] = useState<Record<string, boolean>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});

  const fetchActivity = useCallback((id: string) => {
    if (id in cache.current) return;

    setLoading(prev => ({ ...prev, [id]: true }));

    const promise = apiFetch<ActivityDetailResponse>(`/api/activities/${id}/detail`);
    cache.current[id] = promise;

    promise
      .then((result) => {
        setData(prev => ({ ...prev, [id]: result }));
        setLoading(prev => ({ ...prev, [id]: false }));
      })
      .catch((err) => {
        setErrors(prev => ({ ...prev, [id]: err.message || 'Failed to load' }));
        setLoading(prev => ({ ...prev, [id]: false }));
      });
  }, []);

  return { data, loading, errors, fetchActivity };
}
