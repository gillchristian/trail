import type { StravaActivity } from '../types';
import { formatDistance, formatPace, formatDuration, formatHeartRate, formatDate } from '../lib/format';

export function ActivitiesTable({ activities }: { activities: StravaActivity[] }) {
  if (activities.length === 0) {
    return (
      <p className="py-12 text-center text-gray-500">
        No runs found in the last 30 days.
      </p>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-gray-200 text-gray-500">
            <th className="py-3 pr-4 font-medium">Date</th>
            <th className="py-3 pr-4 font-medium">Name</th>
            <th className="py-3 pr-4 font-medium text-right">Distance</th>
            <th className="py-3 pr-4 font-medium text-right">Duration</th>
            <th className="py-3 pr-4 font-medium text-right">Pace</th>
            <th className="py-3 font-medium text-right">Avg HR</th>
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {activities.map((activity) => (
            <tr key={activity.id} className="border-b border-gray-100 hover:bg-gray-50">
              <td className="py-3 pr-4 text-gray-500">
                {formatDate(activity.start_date_local)}
              </td>
              <td className="py-3 pr-4">
                <a
                  href={`https://www.strava.com/activities/${activity.id}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-orange-600 hover:underline"
                >
                  {activity.name}
                </a>
              </td>
              <td className="py-3 pr-4 text-right">{formatDistance(activity.distance)} km</td>
              <td className="py-3 pr-4 text-right">{formatDuration(activity.moving_time)}</td>
              <td className="py-3 pr-4 text-right">{formatPace(activity.average_speed)} /km</td>
              <td className="py-3 text-right">{formatHeartRate(activity.average_heartrate)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
