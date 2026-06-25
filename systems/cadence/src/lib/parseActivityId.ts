export function parseActivityId(input: string): string | null {
  const trimmed = input.trim();
  if (/^\d+$/.test(trimmed)) return trimmed;
  const match = trimmed.match(/strava\.com\/activities\/(\d+)/);
  if (match) return match[1];
  // strava.app.link short URLs need server-side resolution
  if (/strava\.app\.link\//.test(trimmed)) return null;
  return null;
}

export function isStravaShortLink(input: string): boolean {
  return /strava\.app\.link\//.test(input.trim());
}
