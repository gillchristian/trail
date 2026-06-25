export const DISTANCE_PRESETS = [
  { label: '5K',       min: 4800,  max: 5500  },
  { label: '10K',      min: 9500,  max: 10800 },
  { label: 'Half',     min: 20500, max: 21800 },
  { label: 'Marathon', min: 41500, max: 43200 },
  { label: '50K',      min: 49000, max: 52000 },
  { label: '100K+',    min: 95000, max: 0     },  // 0 = no upper bound
] as const;
