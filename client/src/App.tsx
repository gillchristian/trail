import { Routes, Route, useLocation, useParams, Navigate } from 'react-router-dom';
import { Layout } from './components/Layout';
import { LoginButton } from './components/LoginButton';
import { useAuth } from './hooks/useAuth';
import { DashboardPage } from './pages/DashboardPage';
import { ComparePage } from './pages/ComparePage';
import { CompareSharePage } from './pages/CompareSharePage';
import { LogPage } from './pages/LogPage';
import { encodeCompareIds } from './lib/compareUrl';

function CompareRedirect() {
  const { idA, idB } = useParams<{ idA: string; idB: string }>();
  const encoded = encodeCompareIds([idA!, idB!]);
  return <Navigate to={`/compare/v/${encoded}`} replace />;
}

function App() {
  const { authenticated, loading: authLoading, login, logout } = useAuth();
  const location = useLocation();

  const isPublicRoute = location.pathname.startsWith('/compare/v/');

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
      <Route path="/compare" element={<ComparePage />} />
      <Route path="/compare/v/:encoded" element={<CompareSharePage />} />
      <Route path="/compare/:idA/:idB" element={<CompareRedirect />} />
      <Route path="/log" element={<Navigate to="/log/ytd" replace />} />
      <Route path="/log/:range" element={<LogPage />} />
    </Routes>
  );
}

export default App;
