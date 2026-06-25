import { useState, useEffect, useCallback } from 'react';
import type { StravaActivity } from '../types';
import { apiFetch, AuthError } from '../lib/api';
import { getCachedActivities, setCachedActivities, shouldAutoFetch } from '../lib/cache';

export function useActivities(authenticated: boolean) {
  const [activities, setActivities] = useState<StravaActivity[]>([]);
  const [loading, setLoading] = useState(false);
  const [lastFetched, setLastFetched] = useState<number | null>(null);

  const fetchFromApi = useCallback(async () => {
    setLoading(true);
    try {
      const data = await apiFetch<StravaActivity[]>('/api/activities?days=30');
      setActivities(data);
      setCachedActivities(data);
      setLastFetched(Date.now());
    } catch (err) {
      if (err instanceof AuthError) {
        window.location.reload();
      }
      console.error('Failed to fetch activities:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!authenticated) return;

    const cached = getCachedActivities();
    if (cached) {
      setActivities(cached.activities);
      setLastFetched(cached.fetchedAt);
    }

    if (shouldAutoFetch(cached)) {
      fetchFromApi();
    }
  }, [authenticated, fetchFromApi]);

  return { activities, loading, lastFetched, refresh: fetchFromApi };
}
