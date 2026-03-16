export function parseActivityId(input: string): string | null {
  const trimmed = input.trim();
  if (/^\d+$/.test(trimmed)) return trimmed;
  const match = trimmed.match(/strava\.com\/activities\/(\d+)/);
  return match ? match[1] : null;
}
