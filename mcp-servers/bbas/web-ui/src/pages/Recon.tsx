import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Plus, Search, Play, Pause, RefreshCw, Target, Zap, Loader2, CheckCircle, AlertCircle, Clock, Settings as SettingsIcon, XCircle, Trash2 } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Input, Badge } from '../components/ui';
import { scanApi, sessionsApi, scopeApi } from '../services/api';
import { useUIStore } from '../store';
import { LiveTerminal } from '../components/LiveTerminal';
import { clsx } from 'clsx';
import { fmtAgo } from '../utils/date';

const JOB_TYPES = [
  { value: 'recon', label: 'Recon', desc: 'subfinder + httpx + nuclei' },
  { value: 'scan', label: 'Vuln Scan', desc: 'solo nuclei' },
  { value: 'enum', label: 'Enum', desc: 'gobuster + nmap' },
] as const;

export function Recon() {
  const { activeProject, addNotification, liveSessions, setLiveSession, clearLiveSession } = useUIStore();
  const qc = useQueryClient();
  const [targetsText, setTargetsText] = useState('');
  const [liveSid, setLiveSid] = useState<number | null>(() =>
    activeProject ? liveSessions[activeProject.id] ?? null : null);
  const [jobType, setJobType] = useState<'recon' | 'scan' | 'enum'>('recon');
  const [deep, setDeep] = useState(false);

  // Auto-resume: reconectar a la última sesión en curso del proyecto
  useEffect(() => {
    if (!activeProject) return;
    let cancelled = false;
    sessionsApi.list(activeProject.id).then((list) => {
      if (cancelled) return;
      const running = list.find((s) => s.status === 'running');
      if (running) {
        setLiveSession(activeProject.id, running.id);
        setLiveSid((prev) => prev ?? running.id);
      }
    }).catch(() => {});
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeProject?.id]);

  const { data: sessions = [], isLoading: sLoading } = useQuery({
    queryKey: ['sessions', activeProject?.id],
    queryFn: () => sessionsApi.list(activeProject?.id),
    enabled: !!activeProject,
    refetchInterval: 8000,
  });
  const { data: scope = [] } = useQuery({
    queryKey: ['scope', activeProject?.id],
    queryFn: () => scopeApi.list(activeProject!.id),
    enabled: !!activeProject,
  });

  const scanMut = useMutation({
    mutationFn: (d: { project_id: string; targets: string[]; job_type: 'recon' | 'scan' | 'enum'; deep: boolean }) => scanApi.quick(d),
    onSuccess: (d) => {
      addNotification({ type: 'success', title: 'Scan iniciado', message: `Sesión ${d.session_id} · ${d.work_units_queued} work units` });
      qc.invalidateQueries({ queryKey: ['sessions'] });
      setTargetsText('');
      setLiveSid(d.session_id);
      if (activeProject) setLiveSession(activeProject.id, d.session_id);
    },
    onError: (e: Error) => addNotification({ type: 'error', title: 'Error', message: e.message }),
  });

const loadScopeTargets = async () => {
    if (!activeProject) return;
    try {
      const rules = await scopeApi.list(activeProject.id);
      const norm = (t: string) => t.trim().toLowerCase()
        .replace(/^https?:\/\//, '').split('/')[0].replace(/^\*\./, '');
      const seeds = Array.from(new Set(rules.filter(r => !r.excluded).map(r => norm(r.target))))
        .filter((x) => x.includes('.'));
      setTargetsText((prev) =>
        Array.from(new Set([...prev.split('\n').map(s => s.trim()).filter(Boolean), ...seeds])).join('\n'));
      addNotification({ type: 'success', title: 'Scope cargado',
        message: `${seeds.length} targets añadidos desde el scope autorizado` });
    } catch (e: any) {
      addNotification({ type: 'error', title: 'Error', message: e.message });
    }
  };

  const launch = () => {
    const valid = targetsText.split('\n').map(t => t.trim()).filter(Boolean);
    if (!valid.length) return addNotification({ type: 'error', title: 'Sin targets', message: 'Agrega al menos un target' });
    if (!activeProject) return addNotification({ type: 'error', title: 'Sin proyecto', message: 'Selecciona un proyecto en Dashboard/Settings' });
    scanMut.mutate({ project_id: activeProject.id, targets: valid, job_type: jobType, deep });
  };

  const badge = (st: string) => {
    const v: Record<string, any> = { running: 'info', completed: 'success', failed: 'destructive', paused: 'warning' };
    return <Badge variant={v[st] || 'secondary'} className="text-xs">{st}</Badge>;
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Reconocimiento</h1>
        <p className="text-muted-foreground">Lanza scans contra targets autorizados</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader><CardTitle>Nuevo Scan</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium">
                  Targets{' '}<span className="text-muted-foreground font-normal">
                    ({targetsText.split('\n').map(t => t.trim()).filter(Boolean).length})
                  </span>
                </label>
                <Button variant="outline" size="sm" onClick={loadScopeTargets}
                        disabled={!activeProject}>
                  <Target className="w-3.5 h-3.5 mr-1" /> Cargar scope autorizado
                </Button>
              </div>
              <textarea
                className="flex min-h-[110px] w-full rounded-lg border border-input bg-background px-3 py-2 text-sm font-mono placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                placeholder={'*.ejemplo.com\nejemplo.com\napi.ejemplo.com'}
                value={targetsText}
                onChange={(e) => setTargetsText(e.target.value)}
              />
              <p className="text-xs text-muted-foreground">Un target por línea — los wildcards se expanden automáticamente.</p>
            </div>

            <div>
              <label className="text-sm font-medium">Tipo de scan</label>
              <div className="grid gap-2 sm:grid-cols-3 mt-2">
                {JOB_TYPES.map(j => (
                  <button key={j.value} onClick={() => setJobType(j.value)}
                    className={clsx('p-3 rounded-lg border-2 text-left transition-all',
                      jobType === j.value ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50')}>
                    <Search className="w-4 h-4 mb-1 text-primary" />
                    <p className="font-medium text-sm">{j.label}</p>
                    <p className="text-xs text-muted-foreground">{j.desc}</p>
                  </button>
                ))}
              </div>
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={deep} onChange={(e) => setDeep(e.target.checked)}
                className="w-4 h-4 rounded border-border accent-[hsl(var(--primary))]" />
              <span className="text-sm">Deep scan (incluye nuclei)</span>
            </label>

            <Button size="lg" className="w-full" onClick={launch} disabled={scanMut.isPending}>
              {scanMut.isPending ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" />Lanzando...</> : <><Play className="w-4 h-4 mr-2" />Lanzar scan</>}
            </Button>
          </CardContent>
        </Card>

        {liveSid && (
          <LiveTerminal
            sessionId={liveSid}
            onEnded={() => activeProject && clearLiveSession(activeProject.id)}
          />
        )}

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">Scope autorizado</CardTitle>
            <Badge variant="outline" className="text-xs">{scope.length}</Badge>
          </CardHeader>
          <CardContent>
            {!activeProject ? (
              <p className="text-sm text-muted-foreground">Selecciona un proyecto primero.</p>
            ) : scope.length === 0 ? (
              <div className="text-center py-6 text-muted-foreground">
                <Target className="w-10 h-10 mx-auto mb-2 opacity-50" />
                <p className="text-sm">Sin reglas de scope. Agrégalas en Settings.</p>
              </div>
            ) : (
              <div className="space-y-2 max-h-80 overflow-y-auto">
                {scope.map(r => (
                  <div key={r.id} className={clsx('flex items-center gap-2 p-2 rounded-lg', r.excluded ? 'bg-red-500/10' : 'bg-muted/50')}>
                    {r.excluded ? <AlertCircle className="w-4 h-4 text-red-500 shrink-0" /> : <CheckCircle className="w-4 h-4 text-green-500 shrink-0" />}
                    <span className="font-mono text-xs truncate flex-1">{r.target}</span>
                    <Badge variant={r.excluded ? 'destructive' : 'outline'} className="text-xs">{r.type}</Badge>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Sesiones</CardTitle>
          <Button variant="ghost" size="icon" onClick={() => qc.invalidateQueries({ queryKey: ['sessions'] })}><RefreshCw className="w-4 h-4" /></Button>
        </CardHeader>
        <CardContent>
          {sLoading ? (
            <Loader2 className="w-6 h-6 animate-spin text-primary mx-auto py-8" />
          ) : sessions.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground"><Clock className="w-12 h-12 mx-auto mb-2 opacity-50" /><p>Sin sesiones aún.</p></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-border text-left text-muted-foreground">
                  <th className="p-2">Nombre</th><th className="p-2">Estado</th><th className="p-2">Inicio</th><th className="p-2 w-40">Progreso</th><th className="p-2"></th>
                </tr></thead>
                <tbody>
                  {sessions.map(s => (
                    <tr key={s.id} className="border-b border-border/50 hover:bg-muted/50">
                      <td className="p-2 font-medium">{s.name}</td>
                      <td className="p-2">{badge(s.status)}</td>
                      <td className="p-2 text-muted-foreground">{fmtAgo(s.started_at)}</td>
                      <td className="p-2"><div className="h-2 bg-muted rounded-full overflow-hidden"><div className={clsx('h-full', s.status === 'running' ? 'bg-primary animate-pulse' : s.status === 'completed' ? 'bg-green-500' : s.status === 'failed' ? 'bg-red-500' : 'bg-yellow-500')} style={{ width: `${(s.stats?.progress ?? 0)}%` }} /></div></td>
                      <td className="p-2 flex gap-1 justify-end">
                        {s.status === 'running' && <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => sessionsApi.pause(s.id).then(() => qc.invalidateQueries({ queryKey: ['sessions'] }))}><Pause className="w-3.5 h-3.5" /></Button>}
                        {s.status === 'paused' && <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => sessionsApi.resume(s.id).then(() => qc.invalidateQueries({ queryKey: ['sessions'] }))}><Play className="w-3.5 h-3.5" /></Button>}
                        {(s.status === 'completed' || s.status === 'failed') && <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => sessionsApi.delete(s.id).then(() => qc.invalidateQueries({ queryKey: ['sessions'] }))}><Trash2 className="w-3.5 h-3.5" /></Button>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
