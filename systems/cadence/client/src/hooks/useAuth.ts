import { useState, useEffect } from 'react';
import { apiFetch, API_URL, getSessionToken, setSessionToken, clearSessionToken } from '../lib/api';

interface AuthStatus {
  authenticated: boolean;
  athleteId: number | null;
}

export function useAuth() {
  const [authenticated, setAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check URL for ?token= param from OAuth callback
    const params = new URLSearchParams(window.location.search);
    const token = params.get('token');
    if (token) {
      setSessionToken(token);
      // Clean URL
      window.history.replaceState({}, '', window.location.pathname);
    }

    // Check auth status if we have a session token
    if (getSessionToken()) {
      apiFetch<AuthStatus>('/auth/status')
        .then((data) => setAuthenticated(data.authenticated))
        .catch(() => {
          clearSessionToken();
          setAuthenticated(false);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  function login() {
    window.location.href = API_URL + '/auth/strava';
  }

  async function logout() {
    await apiFetch('/auth/logout', { method: 'POST' });
    clearSessionToken();
    setAuthenticated(false);
  }

  return { authenticated, loading, login, logout };
}
