import type {
  Project,
  ScopeRule,
  Target,
  Finding,
  AttackPath,
  Session,
  ScanJob,
  WorkUnit,
  ScanRequest,
  FindingFilter,
} from '../types';

const API_BASE = '/api';

async function fetchApi<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_BASE}${endpoint}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: `HTTP ${response.status}` }));
    const msg = typeof error.detail === 'string' ? error.detail : JSON.stringify(error.detail || error);
    throw new Error(msg);
  }

  return response.json();
}

// Projects
export const projectsApi = {
  list: () => fetchApi<Project[]>('/projects'),
  get: (id: string) => fetchApi<Project>(`/projects/${id}`),
  create: (data: { name: string; program_url?: string; config?: Record<string, any> }) =>
    fetchApi<Project>('/projects', { method: 'POST', body: JSON.stringify(data) }),
  delete: (id: string) => fetchApi<void>(`/projects/${id}`, { method: 'DELETE' }),
};

// Scope
export const scopeApi = {
  list: (projectId: string) => fetchApi<ScopeRule[]>(`/projects/${projectId}/scope`),
  add: (projectId: string, data: { target: string; type?: string; until?: string; note?: string; excluded?: boolean }) =>
    fetchApi<ScopeRule>(`/projects/${projectId}/scope`, { method: 'POST', body: JSON.stringify(data) }),
  update: (projectId: string, ruleId: number, data: { target?: string; type?: string; until?: string; note?: string; excluded?: boolean }) =>
    fetchApi<ScopeRule>(`/projects/${projectId}/scope/${ruleId}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (projectId: string, ruleId: number) =>
    fetchApi<void>(`/projects/${projectId}/scope/${ruleId}`, { method: 'DELETE' }),
  check: (projectId: string, target: string, type: string = 'recon') =>
    fetchApi<{ authorized: boolean }>(`/projects/${projectId}/scope/check?target=${encodeURIComponent(target)}&type=${type}`),
};

// Sessions
export const sessionsApi = {
  list: (projectId?: string) => fetchApi<Session[]>(`/sessions${projectId ? `?project_id=${projectId}` : ''}`),
  get: (id: number) => fetchApi<Session>(`/sessions/${id}`),
  create: (data: { project_id: string; name?: string; config?: Record<string, any> }) =>
    fetchApi<Session>('/sessions', { method: 'POST', body: JSON.stringify(data) }),
  pause: (id: number) => fetchApi<void>(`/sessions/${id}/pause`, { method: 'POST' }),
  resume: (id: number) => fetchApi<void>(`/sessions/${id}/resume`, { method: 'POST' }),
  delete: (id: number) => fetchApi<void>(`/sessions/${id}`, { method: 'DELETE' }),
};

// Scan Jobs
export const jobsApi = {
  list: (sessionId: number) => fetchApi<ScanJob[]>(`/sessions/${sessionId}/jobs`),
  get: (id: number) => fetchApi<ScanJob>(`/jobs/${id}`),
  workUnits: (jobId: number, status?: string) =>
    fetchApi<WorkUnit[]>(`/jobs/${jobId}/workunits${status ? `?status=${status}` : ''}`),
};

// Findings
export const findingsApi = {
  list: (filter: FindingFilter) =>
    fetchApi<Finding[]>('/findings/filter', { method: 'POST', body: JSON.stringify(filter) }),
  get: (id: number) => fetchApi<Finding>(`/findings/${id}`),
  create: (data: Partial<Finding>) =>
    fetchApi<Finding>('/findings', { method: 'POST', body: JSON.stringify(data) }),
  update: (id: number, updates: Partial<Finding>) =>
    fetchApi<void>(`/findings/${id}`, { method: 'PATCH', body: JSON.stringify(updates) }),
  delete: (id: number) => fetchApi<void>(`/findings/${id}`, { method: 'DELETE' }),
};

// Attack Paths
export const pathsApi = {
  list: (projectId: string, status?: string) =>
    fetchApi<AttackPath[]>(`/projects/${projectId}/attack-paths${status ? `?status=${status}` : ''}`),
  create: (projectId: string, data: Partial<AttackPath>) =>
    fetchApi<AttackPath>(`/projects/${projectId}/attack-paths`, { method: 'POST', body: JSON.stringify(data) }),
  update: (id: number, updates: Partial<AttackPath>) =>
    fetchApi<void>(`/attack-paths/${id}`, { method: 'PATCH', body: JSON.stringify(updates) }),
  delete: (id: number) => fetchApi<void>(`/attack-paths/${id}`, { method: 'DELETE' }),
};

// Targets
export const targetsApi = {
  list: (projectId: string, limit = 100, offset = 0) =>
    fetchApi<Target[]>(`/projects/${projectId}/targets?limit=${limit}&offset=${offset}`),
  get: (id: number) => fetchApi<Target>(`/targets/${id}`),
};

// Scan
export const scanApi = {
  quick: (data: ScanRequest & { project_id: string }) =>
    fetchApi<{ session_id: number; job_id: number; work_units_queued: number }>('/scan', {
      method: 'POST',
      body: JSON.stringify(data),
    }),
};

// Stats
export const statsApi = {
  get: () => fetchApi<{ workers: any; queue: any }>('/stats'),
};
