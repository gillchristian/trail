import type { StravaActivity } from '../types';

export type DateRange = { from: Date; to: Date };

export function parseRange(range: string): DateRange | null {
  const today = new Date();
  today.setHours(23, 59, 59, 999);

  switch (range) {
    case '1m': {
      const from = new Date(today);
      from.setMonth(from.getMonth() - 1);
      from.setHours(0, 0, 0, 0);
      return { from, to: today };
    }
    case '3m': {
      const from = new Date(today);
      from.setMonth(from.getMonth() - 3);
      from.setHours(0, 0, 0, 0);
      return { from, to: today };
    }
    case 'ytd': {
      const from = new Date(today.getFullYear(), 0, 1);
      return { from, to: today };
    }
    case '1y': {
      const from = new Date(today);
      from.setFullYear(from.getFullYear() - 1);
      from.setHours(0, 0, 0, 0);
      return { from, to: today };
    }
    default: {
      // Custom range: YYYY-MM-DD:YYYY-MM-DD
      const parts = range.split(':');
      if (parts.length !== 2) return null;
      const from = new Date(parts[0] + 'T00:00:00');
      const to = new Date(parts[1] + 'T23:59:59');
      if (isNaN(from.getTime()) || isNaN(to.getTime())) return null;
      if (to < from) return null;
      return { from, to };
    }
  }
}

export function rangeToApiParams(range: DateRange): string {
  const fmt = (d: Date) => d.toISOString().slice(0, 10);
  return `from=${fmt(range.from)}&to=${fmt(range.to)}`;
}

export function rangeToParam(from: Date, to: Date): string {
  const fmt = (d: Date) => d.toISOString().slice(0, 10);
  return `${fmt(from)}:${fmt(to)}`;
}

export function rangeLabel(range: string): string {
  switch (range) {
    case '1m': return '1 Month';
    case '3m': return '3 Months';
    case 'ytd': return 'Year to Date';
    case '1y': return '1 Year';
    default: {
      const parsed = parseRange(range);
      if (!parsed) return range;
      const fmt = (d: Date) =>
        d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
      return `${fmt(parsed.from)} – ${fmt(parsed.to)}`;
    }
  }
}

export function formatRangeDisplay(from: Date, to: Date): string {
  const sameYear = from.getFullYear() === to.getFullYear();
  const sameMonth = sameYear && from.getMonth() === to.getMonth();

  if (sameMonth) {
    return `${from.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} – ${to.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
  }
  if (sameYear) {
    return `${from.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })} – ${to.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}`;
  }
  return `${from.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })} – ${to.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}`;
}

// Get Monday-based day index (0=Mon, 6=Sun)
function getMondayIndex(date: Date): number {
  return (date.getDay() + 6) % 7;
}

// Get ISO week start (Monday) for a date
function getWeekStart(date: Date): Date {
  const d = new Date(date);
  const dayIdx = getMondayIndex(d);
  d.setDate(d.getDate() - dayIdx);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function groupByDay(activities: StravaActivity[]): Map<string, StravaActivity[]> {
  const map = new Map<string, StravaActivity[]>();
  for (const a of activities) {
    const key = a.start_date_local.slice(0, 10);
    const arr = map.get(key) || [];
    arr.push(a);
    map.set(key, arr);
  }
  return map;
}

export function groupByWeek(activities: StravaActivity[]): Map<string, StravaActivity[]> {
  const map = new Map<string, StravaActivity[]>();
  for (const a of activities) {
    const date = new Date(a.start_date_local);
    const weekStart = getWeekStart(date);
    const key = weekStart.toISOString().slice(0, 10);
    const arr = map.get(key) || [];
    arr.push(a);
    map.set(key, arr);
  }
  return map;
}

export function groupByMonth(activities: StravaActivity[]): Map<string, StravaActivity[]> {
  const map = new Map<string, StravaActivity[]>();
  for (const a of activities) {
    const key = a.start_date_local.slice(0, 7); // YYYY-MM
    const arr = map.get(key) || [];
    arr.push(a);
    map.set(key, arr);
  }
  return map;
}

export interface CalendarDay {
  date: number;
  dateStr: string; // YYYY-MM-DD
  activities: StravaActivity[];
  totalDistance: number; // meters
}

export interface CalendarMonth {
  year: number;
  month: number; // 0-indexed
  label: string;
  days: (CalendarDay | null)[]; // null = empty cell for grid offset
  totalDistance: number; // meters
}

export function buildCalendarMonths(
  from: Date,
  to: Date,
  byDay: Map<string, StravaActivity[]>,
): CalendarMonth[] {
  const months: CalendarMonth[] = [];
  const startMonth = new Date(from.getFullYear(), from.getMonth(), 1);
  const endMonth = new Date(to.getFullYear(), to.getMonth(), 1);

  const current = new Date(startMonth);
  while (current <= endMonth) {
    const year = current.getFullYear();
    const month = current.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const firstDayOffset = getMondayIndex(new Date(year, month, 1));

    const label = new Date(year, month, 1).toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
    const days: (CalendarDay | null)[] = [];

    // Leading empty cells
    for (let i = 0; i < firstDayOffset; i++) {
      days.push(null);
    }

    let monthTotal = 0;
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const acts = byDay.get(dateStr) || [];
      const totalDistance = acts.reduce((sum, a) => sum + a.distance, 0);
      monthTotal += totalDistance;
      days.push({ date: d, dateStr, activities: acts, totalDistance });
    }

    months.push({ year, month, label, days, totalDistance: monthTotal });
    current.setMonth(current.getMonth() + 1);
  }

  return months;
}
