import React, { useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import {
  Target,
  Bug,
  GitBranch,
  AlertTriangle,
  TrendingUp,
  Activity,
  RefreshCw,
  Clock,
  CheckCircle,
  XCircle,
  FileText,
  Loader2,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Badge } from '../components/ui';
import { projectsApi, statsApi, findingsApi, pathsApi, sessionsApi, targetsApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';
import { SEVERITY_COLORS, SEVERITY_ORDER } from '../types';
import { fmtAgo } from '../utils/date';

const severityOrder = ['critical', 'high', 'medium', 'low', 'info'];

export function Dashboard() {
  const { activeProject, setActiveProject, addNotification } = useUIStore();

  // Fetch projects
  const { data: projects = [], isLoading: projectsLoading } = useQuery({
    queryKey: ['projects'],
    queryFn: projectsApi.list,
  });

  // Fetch stats
  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['stats'],
    queryFn: statsApi.get,
    refetchInterval: 10000,
    enabled: !!activeProject,
  });

  // Fetch recent findings
  const { data: findings = [], isLoading: findingsLoading } = useQuery({
    queryKey: ['findings', 'recent', activeProject?.id],
    queryFn: () => findingsApi.list({
      project_id: activeProject?.id || '',
      limit: 10,
      min_severity: 'medium',
    }),
    enabled: !!activeProject,
  });

  // Fetch attack paths
  const { data: paths = [], isLoading: pathsLoading } = useQuery({
    queryKey: ['paths', activeProject?.id],
    queryFn: () => pathsApi.list(activeProject?.id || ''),
    enabled: !!activeProject,
  });

  // Fetch recent sessions
  const { data: sessions = [], isLoading: sessionsLoading } = useQuery({
    queryKey: ['sessions', activeProject?.id],
    queryFn: () => sessionsApi.list(activeProject?.id),
    enabled: !!activeProject,
  });

  // Fetch targets count
  const { data: targets = [], isLoading: targetsLoading } = useQuery({
    queryKey: ['targets', 'count', activeProject?.id],
    queryFn: () => targetsApi.list(activeProject?.id || '', 1, 0),
    enabled: !!activeProject,
  });

  // Auto-select first project if none selected
  useEffect(() => {
    if (!activeProject && projects.length > 0) {
      setActiveProject(projects[0]);
    }
  }, [projects, activeProject, setActiveProject]);

  if (projectsLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (projects.length === 0) {
    return (
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-center py-16">
        <Target className="w-16 h-16 text-muted-foreground mx-auto mb-4" />
        <h2 className="text-2xl font-bold mb-2">No Projects Yet</h2>
        <p className="text-muted-foreground mb-6">Create your first bug bounty project to get started</p>
        <button
          onClick={() => addNotification({ type: 'info', title: 'Navigate to Settings', message: 'Create a project from the Settings page' })}
          className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
        >
          Go to Settings
        </button>
      </motion.div>
    );
  }

  const statsCards = [
    {
      title: 'Total Targets',
      value: targets.length,
      icon: Target,
      color: 'text-blue-500',
      bg: 'bg-blue-500/10',
    },
    {
      title: 'Active Findings',
      value: findings.filter(f => f.status === 'open').length,
      icon: Bug,
      color: 'text-red-500',
      bg: 'bg-red-500/10',
    },
    {
      title: 'Attack Paths',
      value: paths.length,
      icon: GitBranch,
      color: 'text-purple-500',
      bg: 'bg-purple-500/10',
    },
    {
      title: 'Running Sessions',
      value: sessions.filter(s => s.status === 'running').length,
      icon: Activity,
      color: 'text-green-500',
      bg: 'bg-green-500/10',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-muted-foreground">
            {activeProject ? `Project: ${activeProject.name}` : 'Select a project to begin'}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <select
            value={activeProject?.id || ''}
            onChange={(e) => {
              const project = projects.find(p => p.id === e.target.value);
              if (project) setActiveProject(project);
            }}
            className="px-3 py-2 bg-input border border-border rounded-lg text-sm"
          >
            {projects.map(p => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
          <Button variant="outline" size="sm"
            onClick={() => activeProject && window.open(`/api/projects/${activeProject.id}/report.pdf`, '_blank')}>
            <FileText className="w-4 h-4 mr-2" />
            PDF
          </Button>
          <Button variant="outline" size="sm">
            <RefreshCw className="w-4 h-4 mr-2" />
            Refresh
          </Button>
        </div>
      </motion.div>

      {/* Stats Cards */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="grid gap-4 md:grid-cols-2 lg:grid-cols-4"
      >
        {statsCards.map((stat, i) => (
          <motion.div
            key={stat.title}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 + i * 0.05 }}
          >
            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">{stat.title}</p>
                    <p className="text-3xl font-bold mt-1">{stat.value}</p>
                  </div>
                  <div className={clsx('p-3 rounded-full', stat.bg)}>
                    <stat.icon className={clsx('w-6 h-6', stat.color)} />
                  </div>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </motion.div>

      {/* Main Content Grid */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Recent Findings */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="lg:col-span-2"
        >
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle>Recent Findings</CardTitle>
              <Badge variant="outline" className="text-xs">
                {findings.length} total
              </Badge>
            </CardHeader>
            <CardContent>
              {findingsLoading ? (
                <div className="flex items-center justify-center py-8">
                  <Loader2 className="w-6 h-6 animate-spin text-primary" />
                </div>
              ) : findings.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <Bug className="w-12 h-12 mx-auto mb-2 opacity-50" />
                  <p>No findings yet. Run a scan to discover vulnerabilities.</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {findings.slice(0, 8).map((finding) => (
                    <motion.div
                      key={finding.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      className="flex items-center justify-between p-3 bg-muted/50 rounded-lg hover:bg-muted/80 transition-colors"
                    >
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        <Badge
                          variant={finding.severity as keyof typeof SEVERITY_COLORS}
                          className={clsx('text-xs px-2 py-1', SEVERITY_COLORS[finding.severity as keyof typeof SEVERITY_COLORS])}
                        >
                          {finding.severity}
                        </Badge>
                        <div className="min-w-0">
                          <p className="font-medium truncate">{finding.title}</p>
                          <p className="text-sm text-muted-foreground truncate">{finding.target_host}</p>
                        </div>
                        <Badge variant="outline" className="text-xs hidden sm:inline-flex">
                          {finding.tool}
                        </Badge>
                        <Badge
                          variant={
                            finding.bounty_probability === 'high' ? 'success' :
                            finding.bounty_probability === 'medium' ? 'warning' :
                            finding.bounty_probability === 'low' ? 'secondary' : 'outline'
                          }
                          className="text-xs"
                        >
                          {finding.bounty_probability} bounty
                        </Badge>
                      </div>
                      <span className="text-xs text-muted-foreground ml-4 whitespace-nowrap">
                        {fmtAgo(finding.created_at)}
                      </span>
                    </motion.div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>

        {/* Side Panel */}
        <div className="space-y-6">
          {/* Attack Paths */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <Card>
              <CardHeader className="flex flex-row items-center justify-between">
                <CardTitle>Attack Paths</CardTitle>
                <Badge variant="outline" className="text-xs">
                  {paths.length} total
                </Badge>
              </CardHeader>
              <CardContent>
                {pathsLoading ? (
                  <Loader2 className="w-6 h-6 animate-spin text-primary mx-auto" />
                ) : paths.length === 0 ? (
                  <div className="text-center py-6 text-muted-foreground">
                    <GitBranch className="w-10 h-10 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">No attack paths defined</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {paths.slice(0, 5).map((path) => (
                      <motion.div
                        key={path.id}
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        className="p-3 bg-muted/50 rounded-lg hover:bg-muted/80 transition-colors"
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <Badge
                              variant={path.severity as any}
                              className={clsx('text-xs', path.severity === 'critical' && 'bg-red-600 text-white', path.severity === 'high' && 'bg-orange-600 text-white', path.severity === 'medium' && 'bg-yellow-500 text-black', path.severity === 'low' && 'bg-blue-500 text-white')}
                            >
                              {path.severity}
                            </Badge>
                            <span className="font-medium truncate max-w-[200px]">{path.name}</span>
                          </div>
                          <Badge
                            variant={
                              path.status === 'exploited' ? 'success' :
                              path.status === 'confirmed' ? 'default' :
                              path.status === 'testing' ? 'info' : 'secondary'
                            }
                            className="text-xs"
                          >
                            {path.status}
                          </Badge>
                        </div>
                        <p className="text-sm text-muted-foreground mt-1 truncate">{path.description}</p>
                        <div className="flex items-center gap-2 mt-2 text-xs text-muted-foreground">
                          <span>{path.steps.length} steps</span>
                          <span>•</span>
                          <span>{path.findings_ids.length} findings</span>
                        </div>
                      </motion.div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </motion.div>

          {/* Recent Sessions */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <Card>
              <CardHeader className="flex flex-row items-center justify-between">
                <CardTitle>Recent Sessions</CardTitle>
                <Badge variant="outline" className="text-xs">
                  {sessions.length} total
                </Badge>
              </CardHeader>
              <CardContent>
                {sessionsLoading ? (
                  <Loader2 className="w-6 h-6 animate-spin text-primary mx-auto" />
                ) : sessions.length === 0 ? (
                  <div className="text-center py-6 text-muted-foreground">
                    <Clock className="w-10 h-10 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">No sessions yet</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {sessions.slice(0, 5).map((session) => (
                      <motion.div
                        key={session.id}
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        className="flex items-center justify-between p-3 bg-muted/50 rounded-lg hover:bg-muted/80 transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className={clsx(
                              'w-2 h-2 rounded-full',
                              session.status === 'running' && 'bg-green-500 animate-pulse',
                              session.status === 'completed' && 'bg-blue-500',
                              session.status === 'failed' && 'bg-red-500',
                              session.status === 'paused' && 'bg-yellow-500'
                            )}
                          />
                          <div>
                            <p className="font-medium text-sm truncate max-w-[180px]">{session.name}</p>
                            <p className="text-xs text-muted-foreground">
                              {fmtAgo(session.started_at)}
                            </p>
                          </div>
                        </div>
                        <Badge
                          variant={
                            session.status === 'running' ? 'info' :
                            session.status === 'completed' ? 'success' :
                            session.status === 'failed' ? 'destructive' : 'secondary'
                          }
                          className="text-xs"
                        >
                          {session.status}
                        </Badge>
                      </motion.div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </motion.div>

          {/* Quick Actions */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <Card>
              <CardHeader>
                <CardTitle>Quick Actions</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <Button variant="outline" className="w-full justify-start" onClick={() => {}}>
                  <Target className="w-4 h-4 mr-2" />
                  New Recon Scan
                </Button>
                <Button variant="outline" className="w-full justify-start" onClick={() => {}}>
                  <Bug className="w-4 h-4 mr-2" />
                  Vulnerability Scan
                </Button>
                <Button variant="outline" className="w-full justify-start" onClick={() => {}}>
                  <GitBranch className="w-4 h-4 mr-2" />
                  Create Attack Path
                </Button>
                <Button variant="outline" className="w-full justify-start" onClick={() => {}}>
                  <AlertTriangle className="w-4 h-4 mr-2" />
                  Add Manual Finding
                </Button>
                <Button variant="outline" className="w-full justify-start" onClick={() => {}}>
                  <Activity className="w-4 h-4 mr-2" />
                  View Live Workers
                </Button>
              </CardContent>
            </Card>
          </motion.div>
        </div>
      </div>
    </div>
  );
}
