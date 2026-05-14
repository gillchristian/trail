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
        .map((m) => {
          const icon = L.divIcon({
            html:
              '<div style="background:#fbbf24;color:#0b0b21;border:2px solid #0b0b21;border-radius:9999px;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;box-shadow:0 0 0 1px #fbbf24;">' +
              (m.index ?? '★') +
              '</div>',
            className: '',
            iconSize: [28, 28],
            iconAnchor: [14, 14],
          })
          const popup =
            '<strong>' + escapeHtml(m.name || m.label || 'Aid station') + '</strong>'
          return L.marker([m.lat, m.lon], { icon }).bindPopup(popup)
        })
      this._markerLayer = L.layerGroup(ms).addTo(this._map)
    }
  }
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
