import { useEffect } from 'react';
import { Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { useUIStore } from './store';
import { Dashboard } from './pages/Dashboard';
import { Recon } from './pages/Recon';
import { Findings } from './pages/Findings';
import { AttackPaths } from './pages/AttackPaths';
import { Targets } from './pages/Targets';
import { Sessions } from './pages/Sessions';
import { Settings } from './pages/Settings';
import { ImportProgram } from './pages/ImportProgram';

export default function App() {
  const darkMode = useUIStore((st) => st.darkMode);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', darkMode);
  }, [darkMode]);

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/recon" element={<Recon />} />
        <Route path="/findings" element={<Findings />} />
        <Route path="/paths" element={<AttackPaths />} />
        <Route path="/targets" element={<Targets />} />
        <Route path="/sessions" element={<Sessions />} />
        <Route path="/import" element={<ImportProgram />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Layout>
  );
}
