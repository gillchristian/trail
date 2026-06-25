import { useState, useRef, useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { toPng } from 'html-to-image';
import { formatRangeDisplay } from '../lib/dateRange';
import type { DateRange } from '../lib/dateRange';

const FONTS = [
  { label: 'Helvetica', value: 'Helvetica, Arial, sans-serif' },
  { label: 'Arial', value: 'Arial, Helvetica, sans-serif' },
  { label: 'Georgia', value: 'Georgia, serif' },
  { label: 'Courier', value: '"Courier New", Courier, monospace' },
  { label: 'Verdana', value: 'Verdana, Geneva, sans-serif' },
  { label: 'Trebuchet', value: '"Trebuchet MS", sans-serif' },
];

type Alignment = 'left' | 'center' | 'right';

function luminance(hex: string): number {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  const toLinear = (c: number) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

function checkerboardColors(textColor: string): [string, string] {
  const isLight = luminance(textColor) > 0.4;
  return isLight ? ['#374151', '#4b5563'] : ['#d1d5db', '#f3f4f6'];
}

interface ShareOverlayProps {
  range: DateRange;
  rangeParam: string;
  totalKm: number;
  onClose: () => void;
}

export function ShareOverlay({ range, rangeParam, totalKm, onClose }: ShareOverlayProps) {
  const captureRef = useRef<HTMLDivElement>(null);
  const [font, setFont] = useState(FONTS[0].value);
  const [align, setAlign] = useState<Alignment>('left');
  const [allCaps, setAllCaps] = useState(false);
  const [color, setColor] = useState('#ffffff');
  const [downloading, setDownloading] = useState(false);

  const rangeText = formatRangeDisplay(range.from, range.to);
  const kmText = `${Math.round(totalKm).toLocaleString('de-DE')}km`;

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    },
    [onClose],
  );

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  const handleDownload = async () => {
    if (!captureRef.current) return;
    setDownloading(true);
    try {
      const dataUrl = await toPng(captureRef.current, {
        backgroundColor: undefined,
        pixelRatio: 3,
      });
      const link = document.createElement('a');
      link.download = `cadence-${rangeParam}.png`;
      link.href = dataUrl;
      link.click();
    } catch (err) {
      console.error('Failed to generate PNG:', err);
    } finally {
      setDownloading(false);
    }
  };

  const displayRange = allCaps ? rangeText.toUpperCase() : rangeText;
  const displayKm = allCaps ? kmText.toUpperCase() : kmText;

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="mx-4 w-full max-w-2xl rounded-xl bg-white p-6 shadow-2xl" onClick={(e) => e.stopPropagation()}>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Share</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
        </div>

        <div className="flex gap-6">
          {/* Preview */}
          <div className="flex-1 min-w-0">
            <div
              className="rounded-lg border border-gray-200 overflow-hidden"
              style={{
                backgroundImage:
                  `repeating-conic-gradient(${checkerboardColors(color)[0]} 0% 25%, ${checkerboardColors(color)[1]} 0% 50%)`,
                backgroundSize: '16px 16px',
              }}
            >
              <div
                ref={captureRef}
                className="px-8 py-6"
                style={{
                  display: 'block',
                  width: '100%',
                  boxSizing: 'border-box',
                  fontFamily: font,
                  textAlign: align,
                  color,
                }}
              >
                <div className="text-sm font-bold opacity-80" style={{ fontFamily: font }}>
                  {displayRange}
                </div>
                <div className="text-4xl font-bold" style={{ fontFamily: font }}>
                  {displayKm}
                </div>
              </div>
            </div>
          </div>

          {/* Config */}
          <div className="w-48 space-y-4">
            <div>
              <label className="mb-1 block text-xs font-medium text-gray-500">Font</label>
              <select
                value={font}
                onChange={(e) => setFont(e.target.value)}
                className="w-full rounded-md border border-gray-200 px-2 py-1.5 text-sm"
              >
                {FONTS.map((f) => (
                  <option key={f.label} value={f.value}>
                    {f.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-gray-500">Alignment</label>
              <div className="flex gap-1">
                {(['left', 'center', 'right'] as const).map((a) => (
                  <button
                    key={a}
                    onClick={() => setAlign(a)}
                    className={`flex-1 rounded-md px-2 py-1 text-xs transition-colors ${
                      align === a
                        ? 'bg-orange-50 text-orange-600 font-medium'
                        : 'text-gray-500 hover:text-gray-700 border border-gray-200'
                    }`}
                  >
                    {a.charAt(0).toUpperCase() + a.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="flex items-center gap-2 text-xs font-medium text-gray-500">
                <input
                  type="checkbox"
                  checked={allCaps}
                  onChange={(e) => setAllCaps(e.target.checked)}
                  className="rounded border-gray-300"
                />
                All caps
              </label>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-gray-500">Color</label>
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  value={color}
                  onChange={(e) => setColor(e.target.value)}
                  className="h-8 w-8 cursor-pointer rounded border border-gray-200"
                />
                <span className="text-xs text-gray-400">{color}</span>
              </div>
            </div>

            <button
              onClick={handleDownload}
              disabled={downloading}
              className="w-full rounded-md bg-orange-500 px-3 py-2 text-sm font-medium text-white hover:bg-orange-600 transition-colors disabled:opacity-50"
            >
              {downloading ? 'Generating...' : 'Download PNG'}
            </button>
          </div>
        </div>
      </div>
    </div>,
    document.body,
  );
}
