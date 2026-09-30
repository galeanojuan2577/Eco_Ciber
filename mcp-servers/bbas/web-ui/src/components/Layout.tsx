import React from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LayoutDashboard,
  Search,
  Bug,
  GitBranch,
  Settings,
  ChevronLeft,
  ChevronRight,
  Bell,
  Moon,
  Sun,
  FolderKanban as ProjectIcon,
  Filter,
  Link2,
  Database,
  Terminal,
} from 'lucide-react';
import { useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useUIStore } from '../store';
import { projectsApi } from '../services/api';
import { clsx } from 'clsx';

const navigation = [
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'Recon', href: '/recon', icon: Search },
  { name: 'Findings', href: '/findings', icon: Bug },
  { name: 'Attack Paths', href: '/paths', icon: GitBranch },
  { name: 'Importar', href: '/import', icon: Link2 },
  { name: 'Targets', href: '/targets', icon: Database },
  { name: 'Sessions', href: '/sessions', icon: Terminal },
  { name: 'Settings', href: '/settings', icon: Settings },
];

export function Sidebar() {
  const { sidebarOpen, toggleSidebar, darkMode, toggleDarkMode, activeProject, notifications } = useUIStore();
  const location = useLocation();

  return (
    <aside
      className={clsx(
        'fixed left-0 top-0 z-40 h-screen bg-card border-r border-border transition-all duration-300',
        sidebarOpen ? 'w-64' : 'w-20'
      )}
    >
      <div className="flex flex-col h-full">
        {/* Header */}
        <div className="flex items-center justify-between h-16 px-4 border-b border-border">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            className={clsx('flex items-center gap-2', sidebarOpen ? '' : 'justify-center')}
          >
            <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
              <Bug className="w-5 h-5 text-primary-foreground" />
            </div>
            {sidebarOpen && <span className="font-semibold text-lg">BBAS</span>}
          </motion.div>
          <button
            onClick={toggleSidebar}
            className="p-2 rounded-lg hover:bg-accent transition-colors"
            aria-label={sidebarOpen ? 'Collapse sidebar' : 'Expand sidebar'}
          >
            {sidebarOpen ? <ChevronLeft className="w-5 h-5" /> : <ChevronRight className="w-5 h-5" />}
          </button>
        </div>

        {/* Project Selector */}
        {sidebarOpen && (
          <div className="p-4 border-b border-border">
            <label className="block text-sm font-medium text-muted-foreground mb-2">Active Project</label>
            <SidebarProjectSelect />
          </div>
        )}

        {/* Navigation */}
        <nav className="flex-1 p-2 space-y-1 overflow-y-auto" role="navigation" aria-label="Main navigation">
          {navigation.map((item) => {
            const isActive = location.pathname === item.href || (item.href !== '/' && location.pathname.startsWith(item.href));
            return (
              <NavLink
                key={item.name}
                to={item.href}
                className={({ isActive }) =>
                  clsx(
                    'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-primary text-primary-foreground'
                      : 'text-muted-foreground hover:bg-accent hover:text-foreground',
                    sidebarOpen ? '' : 'justify-center'
                  )
                }
                title={sidebarOpen ? undefined : item.name}
              >
                <item.icon className="w-5 h-5 flex-shrink-0" aria-hidden="true" />
                {sidebarOpen && <span>{item.name}</span>}
              </NavLink>
            );
          })}
        </nav>

        {/* Bottom Actions */}
        <div className="p-2 border-t border-border space-y-1">
          <button
            onClick={toggleDarkMode}
            className={clsx(
              'w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-muted-foreground hover:bg-accent hover:text-foreground transition-colors',
              sidebarOpen ? '' : 'justify-center'
            )}
            title={sidebarOpen ? undefined : darkMode ? 'Light mode' : 'Dark mode'}
          >
            {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            {sidebarOpen && <span>{darkMode ? 'Light Mode' : 'Dark Mode'}</span>}
          </button>

          <button
            className={clsx(
              'w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-muted-foreground hover:bg-accent hover:text-foreground transition-colors relative',
              sidebarOpen ? '' : 'justify-center'
            )}
            title={sidebarOpen ? undefined : 'Notifications'}
          >
            <Bell className="w-5 h-5" />
            {sidebarOpen && <span>Notifications</span>}
            {notifications.length > 0 && (
              <span className={clsx('absolute top-1 right-1 w-4 h-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center', sidebarOpen ? '' : 'top-0 right-0')}>
                {notifications.length > 9 ? '9+' : notifications.length}
              </span>
            )}
          </button>
        </div>
      </div>
    </aside>
  );
}

export function Layout({ children }: { children: React.ReactNode }) {
  const { sidebarOpen } = useUIStore();

  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <div className={clsx('transition-all duration-300', sidebarOpen ? 'lg:pl-64' : 'lg:pl-20')}>
        <header className="sticky top-0 z-30 h-16 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-b border-border">
          <div className="flex items-center justify-between h-full px-6">
            <h1 className="text-xl font-semibold">BBAS</h1>
            <div className="flex items-center gap-4">
              <div className="hidden sm:flex items-center gap-2 px-3 py-1 bg-muted rounded-lg text-sm text-muted-foreground">
                <Terminal className="w-4 h-4" />
                <span>API: Connected</span>
              </div>
            </div>
          </div>
        </header>
        <main className="p-6">
          <AnimatePresence mode="wait">
            {children}
          </AnimatePresence>
        </main>
      </div>
    </div>
  );
}


function SidebarProjectSelect() {
  const { activeProject, activeProjectId, setActiveProject } = useUIStore();
  const { data: projects = [] } = useQuery({ queryKey: ['projects'], queryFn: projectsApi.list });

  // Rehidratar el proyecto activo al cargar (fetch directo, sin esperar la lista)
  useEffect(() => {
    if (!activeProject && activeProjectId) {
      let cancelled = false;
      projectsApi.get(activeProjectId)
        .then((p) => { if (!cancelled) setActiveProject(p); })
        .catch(() => {});
      return () => { cancelled = true; };
    }
  }, [activeProject, activeProjectId]);

  return (
    <select
      value={activeProject?.id || ''}
      onChange={(e) => {
        const p = projects.find((x) => x.id === e.target.value);
        if (p) setActiveProject(p);
      }}
      className="w-full px-3 py-2 bg-input border border-border rounded-lg text-sm focus:ring-2 focus:ring-primary"
    >
      <option value="">Selecciona proyecto…</option>
      {projects.map((p) => (
        <option key={p.id} value={p.id}>{p.name}</option>
      ))}
    </select>
  );
}
