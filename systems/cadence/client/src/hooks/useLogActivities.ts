import { useState, useEffect, useRef, useMemo } from 'react';
import { apiFetch } from '../lib/api';
import { rangeToApiParams } from '../lib/dateRange';
import type { DateRange } from '../lib/dateRange';
import type { StravaActivity } from '../types';

export function useLogActivities(range: DateRange | null) {
  const [activities, setActivities] = useState<StravaActivity[]>([]);
  const [loading, setLoading] = useState(false);
  const cache = useRef<Map<string, StravaActivity[]>>(new Map());

  const key = useMemo(() => (range ? rangeToApiParams(range) : null), [range]);

  useEffect(() => {
    if (!key) return;

    const cached = cache.current.get(key);
    if (cached) {
      setActivities(cached);
      return;
    }

    let cancelled = false;
    setLoading(true);
    apiFetch<StravaActivity[]>(`/api/activities?${key}`)
      .then((data) => {
        if (cancelled) return;
        cache.current.set(key, data);
        setActivities(data);
      })
      .catch((err) => {
        if (cancelled) return;
        console.error('Failed to fetch log activities:', err);
        setActivities([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [key]);

  return { activities, loading };
}
