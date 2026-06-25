import { useState, useEffect, useRef, useCallback } from 'react';
import { apiFetch } from '../lib/api';
import type { SearchResult, SearchResponse } from '../types';

export interface SearchFilters {
  minDistance?: number; // meters
  maxDistance?: number; // meters
  query?: string;
}

export function useActivitySearch() {
  const [filters, setFilters] = useState<SearchFilters>({});
  const [results, setResults] = useState<SearchResult[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [offset, setOffset] = useState(0);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const limit = 50;

  const fetchResults = useCallback(async (f: SearchFilters, newOffset: number) => {
    const params = new URLSearchParams();
    if (f.minDistance) params.set('min_distance', String(f.minDistance));
    if (f.maxDistance) params.set('max_distance', String(f.maxDistance));
    if (f.query) params.set('q', f.query);
    params.set('limit', String(limit));
    params.set('offset', String(newOffset));

    setLoading(true);
    try {
      const data = await apiFetch<SearchResponse>(`/api/activities/search?${params}`);
      if (newOffset === 0) {
        setResults(data.activities);
      } else {
        setResults(prev => [...prev, ...data.activities]);
      }
      setTotal(data.total);
      setOffset(newOffset);
    } catch {
      // Silently handle search errors
    } finally {
      setLoading(false);
    }
  }, []);

  // Debounced search on filter changes
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      fetchResults(filters, 0);
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [filters, fetchResults]);

  const loadMore = useCallback(() => {
    if (!loading && results.length < total) {
      fetchResults(filters, offset + limit);
    }
  }, [loading, results.length, total, filters, offset, fetchResults]);

  return { results, total, loading, filters, setFilters, loadMore, hasMore: results.length < total };
}
