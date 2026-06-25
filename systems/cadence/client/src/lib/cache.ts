import type { CachedActivities, StravaActivity } from '../types';

const CACHE_KEY = 'cadence-activities';

export function getCachedActivities(): CachedActivities | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setCachedActivities(activities: StravaActivity[]): void {
  const data: CachedActivities = {
    activities,
    fetchedAt: Date.now(),
  };
  localStorage.setItem(CACHE_KEY, JSON.stringify(data));
}

export function shouldAutoFetch(cached: CachedActivities | null): boolean {
  if (!cached || cached.activities.length === 0) return true;

  const today = new Date().toISOString().slice(0, 10);
  const hasRunToday = cached.activities.some(
    (a) => a.start_date_local.slice(0, 10) === today
  );

  return !hasRunToday;
}
