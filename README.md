# Cadence

A monthly snapshot of your running metrics. Visualize your Strava activity trends over time.

## Setup

```
npm install
npm --prefix client install
cp client/.env.example client/.env
cp server/.env.example server/.env
```

Add your `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` to `server/.env`.

## Dev

```
cd server && go run -tags fts5 .   # Backend: http://localhost:3001
npm run dev             # Frontend: http://localhost:5173
```

## Deploy

**Frontend** → Vercel (deploy from `client/`). Set `VITE_API_URL` to your fly.io backend URL.

**Backend** → fly.io.

```
fly launch
fly secrets set STRAVA_CLIENT_ID=... STRAVA_CLIENT_SECRET=... FRONTEND_URL=https://your-app.vercel.app API_BASE_URL=https://your-app.fly.dev
fly deploy
```
