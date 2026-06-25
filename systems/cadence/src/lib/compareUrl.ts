import Sqids from 'sqids';

const sqids = new Sqids({
  minLength: 6,
  alphabet: 'k3rw8gxf6m1aqt5bnhj2ycpvs947edzu',
});

export function encodeCompareIds(ids: string[]): string {
  return sqids.encode(ids.map(Number));
}

export function decodeCompareIds(encoded: string): string[] {
  return sqids.decode(encoded).map(String);
}
