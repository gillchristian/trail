// `<trail-map>` custom element. Wraps Leaflet so we can render
// a map from Elm with one `Html.node "trail-map" [...] []` call.
//
// Inputs are passed as attributes:
//   track="[[lat,lon],...]"
//   markers='[{"lat":N,"lon":N,"label":"S","name":"…","index":N}]'
//
// We deliberately do NOT use ports here. A custom element keeps
// the Leaflet life-cycle local to one DOM node: when Elm removes
// the node, the map's `_container` goes with it.

import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// Leaflet's default-marker icon paths assume a bundler that bundles
// images alongside CSS. Vite serves the leaflet/dist/images/ folder
// via the CSS import, but the JS still references the icons by URL.
// Override the default icon options with explicit, bundler-resolved
// URLs so markers actually render.
import iconUrl from 'leaflet/dist/images/marker-icon.png'
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png'
import shadowUrl from 'leaflet/dist/images/marker-shadow.png'

L.Icon.Default.mergeOptions({
  iconUrl,
  iconRetinaUrl,
  shadowUrl,
})

class TrailMap extends HTMLElement {
  static get observedAttributes() {
    return ['track', 'markers']
  }

  connectedCallback() {
    if (this._mounted) return
    this._mounted = true

    this._inner = document.createElement('div')
    this._inner.style.width = '100%'
    this._inner.style.height = '100%'
    this.appendChild(this._inner)

    this._map = L.map(this._inner, {
      zoomControl: true,
      attributionControl: true,
    }).setView([46.0, 7.0], 6)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(this._map)

    this._renderAll()
  }

  disconnectedCallback() {
    if (this._map) {
      this._map.remove()
      this._map = null
    }
    this._mounted = false
  }

  attributeChangedCallback() {
    if (this._map) this._renderAll()
  }

  _renderAll() {
    if (!this._map) return

    if (this._trackLayer) {
      this._map.removeLayer(this._trackLayer)
      this._trackLayer = null
    }
    if (this._markerLayer) {
      this._map.removeLayer(this._markerLayer)
      this._markerLayer = null
    }

    const track = parseJSONAttr(this.getAttribute('track'))
    const markers = parseJSONAttr(this.getAttribute('markers'))

    if (Array.isArray(track) && track.length > 1) {
      // Simple ghost-glow effect: a thick translucent halo behind a thin core line.
      const halo = L.polyline(track, { color: '#E52E3A', weight: 8, opacity: 0.25, lineJoin: 'round', lineCap: 'round' })
      const core = L.polyline(track, { color: '#ff5f6a', weight: 3, opacity: 1, lineJoin: 'round', lineCap: 'round' })
      this._trackLayer = L.layerGroup([halo, core]).addTo(this._map)
      this._map.fitBounds(core.getBounds(), { padding: [24, 24] })
    }

    if (Array.isArray(markers) && markers.length > 0) {
      const ms = markers
        .filter((m) => Number.isFinite(m?.lat) && Number.isFinite(m?.lon))
        .map((m) => L.marker([m.lat, m.lon], { icon: iconForMarker(m), zIndexOffset: zIndexFor(m) }).bindPopup(popupForMarker(m)))
      this._markerLayer = L.layerGroup(ms).addTo(this._map)
    }
  }
}

const SERVICE_EMOJI = {
  water: '💧',
  food: '🍌',
  warm_food: '🍲',
  medical: '⛑',
  wc: '🚻',
  drop_bag: '🎒',
}

const SERVICE_LABEL = {
  water: 'Water',
  food: 'Food',
  warm_food: 'Warm food',
  medical: 'Medical',
  wc: 'WC',
  drop_bag: 'Drop bag',
}

function iconForMarker(m) {
  if (m.kind === 'start') {
    return L.divIcon({
      html:
        '<div style="background:#22c55e;color:#0b0b21;border:3px solid #0b0b21;border-radius:9999px;width:32px;height:32px;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;box-shadow:0 0 0 1px #22c55e, 0 2px 6px rgba(0,0,0,.4);">▶</div>',
      className: '',
      iconSize: [32, 32],
      iconAnchor: [16, 16],
    })
  }
  if (m.kind === 'finish') {
    return L.divIcon({
      html:
        '<div style="background:#0b0b21;color:#fbbf24;border:3px solid #fbbf24;border-radius:9999px;width:32px;height:32px;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;box-shadow:0 0 0 1px #fbbf24, 0 2px 6px rgba(0,0,0,.4);">🏁</div>',
      className: '',
      iconSize: [32, 32],
      iconAnchor: [16, 16],
    })
  }
  return L.divIcon({
    html:
      '<div style="background:#fbbf24;color:#0b0b21;border:2px solid #0b0b21;border-radius:9999px;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;box-shadow:0 0 0 1px #fbbf24;">' +
      escapeHtml(m.index ?? '★') +
      '</div>',
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  })
}

function zIndexFor(m) {
  if (m.kind === 'start' || m.kind === 'finish') return 1000
  return 0
}

function popupForMarker(m) {
  if (m.kind === 'start') {
    return '<div style="font-family:system-ui,sans-serif;"><strong style="color:#16a34a;">▶ Start</strong></div>'
  }
  if (m.kind === 'finish') {
    return (
      '<div style="font-family:system-ui,sans-serif;"><strong style="color:#a16207;">🏁 ' +
      escapeHtml(m.name || 'Finish') +
      '</strong></div>'
    )
  }
  const services = Array.isArray(m.services) ? m.services : []
  const servicesRow = services.length
    ? '<div style="margin-top:6px;display:flex;flex-wrap:wrap;gap:4px;">' +
      services
        .map(
          (s) =>
            '<span style="display:inline-flex;align-items:center;gap:3px;padding:2px 6px;background:#fef3c7;border-radius:6px;font-size:11px;">' +
            (SERVICE_EMOJI[s] || '•') +
            ' ' +
            (SERVICE_LABEL[s] || s) +
            '</span>'
        )
        .join('') +
      '</div>'
    : ''
  const km = Number.isFinite(m.distanceKm) ? m.distanceKm.toFixed(1) + ' km' : ''
  const restMin =
    Number.isFinite(m.restSeconds) && m.restSeconds > 0 ? Math.round(m.restSeconds / 60) + ' min rest' : ''
  const meta = [km, restMin].filter(Boolean).join(' · ')
  return (
    '<div style="font-family:system-ui,sans-serif;min-width:160px;">' +
    '<strong>' +
    escapeHtml(m.index || '★') +
    ' · ' +
    escapeHtml(m.name || 'Aid station') +
    '</strong>' +
    (meta ? '<div style="color:#475569;font-size:12px;margin-top:2px;">' + meta + '</div>' : '') +
    servicesRow +
    '</div>'
  )
}

function parseJSONAttr(raw) {
  if (!raw) return null
  try {
    return JSON.parse(raw)
  } catch (_) {
    return null
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

if (!customElements.get('trail-map')) {
  customElements.define('trail-map', TrailMap)
}
