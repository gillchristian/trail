# i18n glossary — neutral Spanish term choices

Single source of truth for the **Spanish** side of the i18n epic (ADR-0014,
`i18n-spec.md`). Goal: **neutral Spanish** — understood across Spain and Latin
America, avoiding strongly regional words. Each translation PR (TASK-061–068)
must use these terms and **append** any new domain term it introduces, so the
surface stays consistent across PRs. The user reviews per PR — flag a better
term and it changes here once, everywhere.

## Domain (trail running)

| English | Spanish | Note |
|---|---|---|
| race | carrera | |
| aid station | avituallamiento | std. trail term, pan-Hispanic. Pl. avituallamientos |
| pace | ritmo | |
| target pace | ritmo objetivo | |
| split (per-km) | parcial | pl. parciales |
| section | tramo | (the parking-lot "tramos" term) |
| elevation | elevación | chart: "perfil de elevación" |
| elevation gain / loss | desnivel positivo / negativo | short: D+ / D− (intl. trail) |
| grade / slope | pendiente | |
| climb / uphill | subida | |
| descent / downhill | bajada | |
| steep climb / descent | subida / bajada pronunciada | |
| runnable | corrible | terrain you can run; alt. "rodador" — flag if preferred |
| flat | llano | |
| finish (line) | meta | "finishes the race" → "termina la carrera" |
| start (line) | salida | |
| waypoint | punto de paso | |
| course | recorrido | the GPX track/route |
| effort | esfuerzo | |
| predicted finish | llegada estimada | |
| aid stop (short count) | parada | "N stops" → "N paradas"; full noun stays *avituallamiento* |
| cutoff | corte | |
| rest | descanso | (`formatRest` localizes in TASK-065 — still English in 064) |

### Effort tiers (Conservative / Goal / Push / All-in)
Conservador / Objetivo / Fuerte / Al máximo  *(neutral — avoid "a tope" (ES))*

### Density (Flat … Extreme)
Llano / Ondulado / Accidentado / Montañoso / Muy montañoso / Extremo

### Distance category (Short / Medium / Long / Ultra)
Corta / Media / Larga / Ultra

### Grade class (Steep climb / Climb / Runnable / Descent / Steep descent)
Subida pronunciada / Subida / Corrible / Bajada / Bajada pronunciada

### Aid-station services (Types.elm `serviceLabel`)
Water→Agua · Food→Comida · Warm food→Comida caliente · Medical→Asistencia médica
· WC→Baño · Drop bag→Bolsa de material · Crew access→Acceso para asistencia

### Athlete profile (AthleteProfile.elm labels)
- Presets: Beginner→Principiante · Mid-pack→Intermedio · Strong mid-pack→Intermedio
  avanzado · Sub-elite→Subélite
- Descent skill (Cautious/Average/Confident/Expert): Cauteloso / Normal / Seguro / Experto
- Tech skill (Novice/Average/Experienced/Expert): Principiante / Normal / Con experiencia / Experto
- Aid style (Elite/Lean/Standard/Relaxed): Élite / Ágil / Estándar / Relajado

## App chrome / actions

| English | Spanish |
|---|---|
| Your races | Tus carreras |
| Save | Guardar |
| Cancel | Cancelar |
| Delete | Eliminar |
| Edit | Editar |
| Close | Cerrar |
| Add | Agregar |
| Import / Export | Importar / Exportar |
| Upload | Subir |
| Download | Descargar |
| Replace | Reemplazar |
| Remove | Quitar |
| Map | Mapa |
| Notes | Notas |
| Distance / Time | Distancia / Tiempo |
| Target time | Tiempo objetivo |
| Activity (feed) | Actividad |
| Settings | Ajustes |
| Plans (home section) | Planes |
| Executions (home section) | Completadas |
| Gain / Loss (stat label) | Desnivel + / Desnivel − |
| Density (stat) | Densidad |
| Flat eq. (stat) | Equiv. llano |
| Span (km column) | Rango |
| Cum (column) | Acum. |
| Actual (column/stat) | Real |
| Grade (column) | Pendiente |
| Δ ele / Δ vs plan (columns) | kept verbatim (compact symbols) |
| Plan by `<name>` | Plan de `<name>` |
| Start / Finish (in section labels) | Salida / Meta — **but `section.label` is CSV-canonical; localizing it is TASK-071** |

## Split terms — chosen value (flag if you'd prefer the alternative)

These have a real ES-ES vs ES-419 split; one was picked for consistency:

- **Agregar** (not "Añadir") for *add*.
- **Ajustes** (not "Configuración") for *settings*.
- **Baño** (not "WC"/"Aseo") for the WC service.
- **Eliminar** (not "Borrar") for *delete*.
- **Completadas** (not literal "Ejecuciones") for the *Executions* home section — reads naturally for "runs you came back from"; the English label was itself flagged provisional (TASK-028).

## Formatting conventions (Format.elm — see ADR-0014 / WI-5)

- **Decimal separator:** Spanish `,` · English `.` (e.g. `42,2 km`). Applies to
  *decimal* quantities only.
- **Colon-formatted values stay as-is** in both languages: pace `M:SS`, clock
  `H:MM:SS`, elapsed. No separator swap.
- **Units are not translated** (descoped — TASK-070): `km`, `m`, `m/km`, `D+`,
  `D−`, `/km` render identically. Only surrounding *words* localize.
- **HR:** label "FC" (frecuencia cardíaca) — avg HR → "FC media", max HR → "FC
  máxima", LTHR → "FC umbral"; the bpm unit stays "bpm".
- Proper nouns kept verbatim: **Coros**, **Pace Strategy**, **Strava**, **UTMB**,
  **GPX**, `.trail`.
