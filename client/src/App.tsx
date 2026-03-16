import { Routes, Route, useLocation } from 'react-router-dom';
import { Layout } from './components/Layout';
import { LoginButton } from './components/LoginButton';
import { useAuth } from './hooks/useAuth';
import { DashboardPage } from './pages/DashboardPage';
import { CompareInputPage } from './pages/CompareInputPage';
import { CompareResultPage } from './pages/CompareResultPage';

function App() {
  const { authenticated, loading: authLoading, login, logout } = useAuth();
  const location = useLocation();

  // Compare result pages are publicly accessible (served from cache)
  const isPublicRoute = /^\/compare\/\d+\/\d+/.test(location.pathname);

  if (!isPublicRoute) {
    if (authLoading) {
      return (
        <Layout>
          <p className="py-12 text-center text-gray-400">Loading...</p>
        </Layout>
      );
    }

    if (!authenticated) {
      return (
        <Layout>
          <h1 className="mb-2 text-2xl font-bold text-gray-900">Cadence</h1>
          <p className="mb-8 text-gray-500">A monthly snapshot of your running metrics.</p>
          <LoginButton onClick={login} />
        </Layout>
      );
    }
  }

  return (
    <Routes>
      <Route path="/" element={<DashboardPage logout={logout} />} />
      <Route path="/compare" element={<CompareInputPage />} />
      <Route path="/compare/:idA/:idB" element={<CompareResultPage />} />
    </Routes>
  );
}

export default App;
