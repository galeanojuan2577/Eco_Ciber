import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Project, Finding, AttackPath, Target } from '../types';

interface UIState {
  // Project
  activeProject: Project | null;
  activeProjectId: string;
  setActiveProject: (project: Project | null) => void;

  // Sidebar
  sidebarOpen: boolean;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;

  // Theme
  darkMode: boolean;
  toggleDarkMode: () => void;

  // Notifications
  notifications: Notification[];
  addNotification: (notification: Omit<Notification, 'id'>) => void;
  removeNotification: (id: string) => void;

  // Filters
  findingFilters: FindingFilters;
  setFindingFilters: (filters: Partial<FindingFilters>) => void;
  resetFindingFilters: () => void;

  // Selected items
  selectedFindings: number[];
  toggleFindingSelection: (id: number) => void;
  clearFindingSelection: () => void;

  selectedPaths: number[];
  togglePathSelection: (id: number) => void;
  clearPathSelection: () => void;

  // View mode
  viewMode: 'table' | 'cards' | 'graph';
  setViewMode: (mode: 'table' | 'cards' | 'graph') => void;

  // Sesión en vivo por proyecto (persiste entre pestañas)
  liveSessions: Record<string, number>;
  setLiveSession: (projectId: string, sessionId: number) => void;
  clearLiveSession: (projectId: string) => void;
}

interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message: string;
  duration?: number;
}

interface FindingFilters {
  minSeverity: string;
  tech: string;
  status: string;
  search: string;
}

const defaultFilters: FindingFilters = {
  minSeverity: '',
  tech: '',
  status: '',
  search: '',
};

export const useUIStore = create<UIState>()(
  persist(
    (set, get) => ({
      // Project
      activeProject: null,
      activeProjectId: '',
      setActiveProject: (project) =>
        set({ activeProject: project, activeProjectId: project?.id || '' }),

      // Sidebar
      sidebarOpen: true,
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (open) => set({ sidebarOpen: open }),

      // Theme
      darkMode: false,
      toggleDarkMode: () => set((state) => ({ darkMode: !state.darkMode })),

      // Notifications
      notifications: [],
      addNotification: (notification) => {
        const id = Math.random().toString(36).substr(2, 9);
        set((state) => ({
          notifications: [...state.notifications, { ...notification, id }],
        }));
        if (notification.duration !== 0) {
          setTimeout(() => get().removeNotification(id), notification.duration || 5000);
        }
      },
      removeNotification: (id) =>
        set((state) => ({
          notifications: state.notifications.filter((n) => n.id !== id),
        })),

      // Filters
      findingFilters: defaultFilters,
      setFindingFilters: (filters) =>
        set((state) => ({ findingFilters: { ...state.findingFilters, ...filters } })),
      resetFindingFilters: () => set({ findingFilters: defaultFilters }),

      // Selected items
      selectedFindings: [],
      toggleFindingSelection: (id) =>
        set((state) => ({
          selectedFindings: state.selectedFindings.includes(id)
            ? state.selectedFindings.filter((x) => x !== id)
            : [...state.selectedFindings, id],
        })),
      clearFindingSelection: () => set({ selectedFindings: [] }),

      selectedPaths: [],
      togglePathSelection: (id) =>
        set((state) => ({
          selectedPaths: state.selectedPaths.includes(id)
            ? state.selectedPaths.filter((x) => x !== id)
            : [...state.selectedPaths, id],
        })),
      clearPathSelection: () => set({ selectedPaths: [] }),

      // View mode
      viewMode: 'table',
      setViewMode: (mode) => set({ viewMode: mode }),

      // Live sessions
      liveSessions: {},
      setLiveSession: (projectId, sessionId) =>
        set((state) => ({ liveSessions: { ...state.liveSessions, [projectId]: sessionId } })),
      clearLiveSession: (projectId) =>
        set((state) => {
          const next = { ...state.liveSessions };
          delete next[projectId];
          return { liveSessions: next };
        }),
    }),
    {
      name: 'bbas-ui-store',
      partialize: (state) => ({
        darkMode: state.darkMode,
        sidebarOpen: state.sidebarOpen,
        activeProjectId: state.activeProjectId,
        liveSessions: state.liveSessions,
        findingFilters: state.findingFilters,
        viewMode: state.viewMode,
      }),
    }
  )
);
