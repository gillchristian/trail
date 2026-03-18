import { useMemo } from 'react';
import type { StravaActivity } from '../types';
import { groupByDay, buildCalendarMonths } from '../lib/dateRange';
import type { DateRange, CalendarDay } from '../lib/dateRange';

const DAY_HEADERS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

function DayCell({ day, maxDistance }: { day: CalendarDay; maxDistance: number }) {
  const barHeight = maxDistance > 0 ? Math.max(2, (day.totalDistance / maxDistance) * 16) : 0;

  return (
    <div className="flex flex-col items-center gap-0.5 py-0.5">
      <span className="text-[10px] text-gray-400">{day.date}</span>
      {day.totalDistance > 0 ? (
        <div
          className="w-1.5 rounded-sm bg-orange-500"
          style={{ height: `${barHeight}px` }}
          title={`${(day.totalDistance / 1000).toFixed(1)} km`}
        />
      ) : (
        <div className="w-1.5" style={{ height: '2px' }} />
      )}
    </div>
  );
}

function MonthBox({ month, maxDistance }: {
  month: { year: number; month: number; label: string; days: (CalendarDay | null)[]; totalDistance: number };
  maxDistance: number;
}) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3">
      <div className="mb-2 flex items-baseline justify-between">
        <span className="text-xs font-semibold tracking-wide text-gray-500">{month.label}</span>
        <div>
          <span className="text-lg font-bold text-gray-900">
            {(month.totalDistance / 1000).toFixed(0)}
          </span>
          <span className="ml-1 text-xs text-gray-400">km</span>
        </div>
      </div>
      <div className="grid grid-cols-7 gap-px">
        {DAY_HEADERS.map((d, i) => (
          <div key={i} className="text-center text-[9px] font-medium text-gray-300">
            {d}
          </div>
        ))}
        {month.days.map((day, i) =>
          day === null ? (
            <div key={`empty-${i}`} />
          ) : (
            <DayCell key={day.dateStr} day={day} maxDistance={maxDistance} />
          ),
        )}
      </div>
    </div>
  );
}

export function LogCalendar({ activities, range }: { activities: StravaActivity[]; range: DateRange }) {
  const { months, maxDistance } = useMemo(() => {
    const byDay = groupByDay(activities);
    const months = buildCalendarMonths(range.from, range.to, byDay);

    let max = 0;
    for (const month of months) {
      for (const day of month.days) {
        if (day && day.totalDistance > max) max = day.totalDistance;
      }
    }

    return { months, maxDistance: max };
  }, [activities, range.from, range.to]);

  if (months.length === 0) return null;

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-3 lg:grid-cols-4">
      {months.map((month) => (
        <MonthBox
          key={`${month.year}-${month.month}`}
          month={month}
          maxDistance={maxDistance}
        />
      ))}
    </div>
  );
}
