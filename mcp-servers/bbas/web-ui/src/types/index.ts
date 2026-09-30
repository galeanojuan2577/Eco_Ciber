export interface Project {
  id: string;
  name: string;
  program_url: string;
  scope_file: string;
  created_at: string;
  updated_at: string;
  config: Record<string, any>;
}

export interface ScopeRule {
  id: number;
  project_id: string;
  target: string;
  type: string;
  since: string;
  until: string | null;
  note: string;
  excluded: boolean;
}

export interface Target {
  id: number;
  project_id: string;
  host: string;
  url: string;
  ip: string;
  status_code: number;
  title: string;
  server: string;
  tech_stack: string[];
  cdn: string;
  locked_type: string;
  score: number;
  last_scanned: string | null;
  created_at: string;
  updated_at: string;
}

export interface Finding {
  id: number;
  project_id: string;
  target_id: number | null;
  target_host: string;
  type: 'vuln' | 'exposure' | 'misconfig' | 'info' | 'logic';
  severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
  cvss_score: number | null;
  cwe_id: string;
  cve_id: string;
  title: string;
  description: string;
  poc: string;
  evidence: string;
  tool: string;
  tags: string[];
  status: 'open' | 'confirmed' | 'false_positive' | 'fixed' | 'wont_fix';
  bounty_probability: 'high' | 'medium' | 'low' | 'unknown';
  exploit_difficulty: 'easy' | 'medium' | 'hard';
  created_at: string;
  updated_at: string;
  closed_at: string | null;
}

export interface AttackPath {
  id: number;
  project_id: string;
  name: string;
  description: string;
  steps: AttackPathStep[];
  findings_ids: number[];
  severity: 'critical' | 'high' | 'medium' | 'low';
  bounty_potential: 'high' | 'medium' | 'low';
  status: 'theoretical' | 'testing' | 'confirmed' | 'exploited';
  notes: string;
  created_at: string;
  updated_at: string;
}

export interface AttackPathStep {
  order: number;
  title: string;
  description: string;
  technique: string;
  finding_id?: number;
  target?: string;
  payload?: string;
}

export interface Session {
  id: number;
  project_id: string;
  name: string;
  status: 'running' | 'paused' | 'completed' | 'failed';
  started_at: string;
  ended_at: string | null;
  config: Record<string, any>;
  stats: Record<string, any>;
}

export interface ScanJob {
  id: number;
  session_id: number;
  job_type: 'recon' | 'scan' | 'enum' | 'triage';
  target_pattern: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  priority: number;
  progress: number;
  total_targets: number;
  completed_targets: number;
  error_message: string;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
}

export interface WorkUnit {
  id: number;
  scan_job_id: number;
  unit_type: string;
  target_host: string;
  target_url: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  priority: number;
  attempts: number;
  max_attempts: number;
  result: Record<string, any>;
  error_message: string;
  worker_id: string;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
}

export interface ScanRequest {
  targets: string[];
  job_type: 'recon' | 'scan' | 'enum';
  deep?: boolean;
}

export interface FindingFilter {
  project_id?: string;
  min_severity?: string;
  tech?: string;
  status?: string;
  limit?: number;
  offset?: number;
}

export interface SeverityColor {
  critical: string;
  high: string;
  medium: string;
  low: string;
  info: string;
}

export const SEVERITY_COLORS: SeverityColor = {
  critical: 'bg-red-600 text-white',
  high: 'bg-orange-600 text-white',
  medium: 'bg-yellow-500 text-black',
  low: 'bg-blue-500 text-white',
  info: 'bg-gray-500 text-white',
};

export const SEVERITY_ORDER = {
  critical: 5,
  high: 4,
  medium: 3,
  low: 2,
  info: 1,
};
