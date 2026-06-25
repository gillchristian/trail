import { useState, useEffect, useRef, useCallback } from 'react';
import { apiFetch } from '../lib/api';
import type { BackfillStatus } from '../types';

export function useBackfill() {
  const [status, setStatus] = useState<BackfillStatus>({ running: false, complete: false, total_stored: 0 });
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const mountedRef = useRef(true);

  const poll = useCallback(async () => {
    try {
      const data = await apiFetch<BackfillStatus>('/api/backfill/status');
      if (!mountedRef.current) return;
      setStatus(data);
      if (data.complete && !data.running && intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    } catch {
      // Silently ignore polling errors
    }
  }, []);

  useEffect(() => {
    mountedRef.current = true;
    poll(); // Initial check
    intervalRef.current = setInterval(poll, 2000);

    return () => {
      mountedRef.current = false;
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [poll]);

  return { syncing: status.running, complete: status.complete, totalStored: status.total_stored };
}
