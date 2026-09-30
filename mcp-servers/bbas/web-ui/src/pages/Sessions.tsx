import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Terminal, Play, Pause, RefreshCw, Loader2, ChevronDown, ChevronUp, Trash2 } from 'lucide-react';
import { Card, CardContent } from '../components/ui';
import { Button, Badge } from '../components/ui';
import { sessionsApi, jobsApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';
import { fmtAgo } from '../utils/date';

export function Sessions() {
  const { activeProject } = useUIStore();
  const qc = useQueryClient();
  const [expanded, setExpanded] = useState<number | null>(null);

  const { data: sessions = [], isLoading } = useQuery({
    queryKey: ['sessions', activeProject?.id],
    queryFn: () => sessionsApi.list(activeProject?.id),
    enabled: !!activeProject,
    refetchInterval: 8000,
  });

  const pauseMut = useMutation({ mutationFn: sessionsApi.pause, onSuccess: () => qc.invalidateQueries({ queryKey: ['sessions'] }) });
  const resumeMut = useMutation({ mutationFn: sessionsApi.resume, onSuccess: () => qc.invalidateQueries({ queryKey: ['sessions'] }) });
  const delMut = useMutation({ mutationFn: sessionsApi.delete, onSuccess: () => qc.invalidateQueries({ queryKey: ['sessions'] }) });

  const badge = (st: string) => {
    const v: Record<string, any> = { running: 'info', completed: 'success', failed: 'destructive', paused: 'warning' };
    return <Badge variant={v[st] || 'secondary'} className="text-xs">{st}</Badge>;
  };

  if (!activeProject) return (
    <div className="text-center py-16"><Terminal className="w-16 h-16 text-muted-foreground mx-auto mb-4" /><h2 className="text-xl font-bold">Selecciona un proyecto</h2></div>
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-bold tracking-tight">Sesiones</h1>
        <p className="text-muted-foreground">{sessions.length} sesiones de scan</p></div>
        <Button variant="outline" onClick={() => qc.invalidateQueries({ queryKey: ['sessions'] })}><RefreshCw className="w-4 h-4 mr-2" />Refrescar</Button>
      </div>

      <Card><CardContent className="p-0">
        {isLoading ? (
          <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto my-16" />
        ) : sessions.length === 0 ? (
          <div className="text-center py-16"><Terminal className="w-14 h-14 mx-auto mb-3 opacity-50 text-muted-foreground" /><p className="text-muted-foreground">Sin sesiones. Lanza un scan en Recon.</p></div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="border-b border-border bg-muted/50 text-left text-muted-foreground">
                <th className="p-3 w-10"></th><th className="p-3">Sesión</th><th className="p-3">Estado</th><th className="p-3">Inicio</th><th className="p-3"></th>
              </tr></thead>
              <tbody>
                {sessions.map(s => (
                  <React.Fragment key={s.id}>
                    <tr className="border-b border-border/50 hover:bg-muted/50 cursor-pointer" onClick={() => setExpanded(expanded === s.id ? null : s.id)}>
                      <td className="p-3 text-center">{expanded === s.id ? <ChevronUp className="w-4 h-4 mx-auto" /> : <ChevronDown className="w-4 h-4 mx-auto text-muted-foreground" />}</td>
                      <td className="p-3 font-medium">{s.name}</td>
                      <td className="p-3">{badge(s.status)}</td>
                      <td className="p-3 text-muted-foreground whitespace-nowrap">{fmtAgo(s.started_at)}</td>
                      <td className="p-3">
                        <div className="flex gap-1 justify-end">
                          {s.status === 'running' && <Button variant="ghost" size="icon" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); pauseMut.mutate(s.id); }}><Pause className="w-3.5 h-3.5" /></Button>}
                          {s.status === 'paused' && <Button variant="ghost" size="icon" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); resumeMut.mutate(s.id); }}><Play className="w-3.5 h-3.5" /></Button>}
                          {(s.status === 'completed' || s.status === 'failed') && <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={(e) => { e.stopPropagation(); delMut.mutate(s.id); }}><Trash2 className="w-3.5 h-3.5" /></Button>}
                        </div>
                      </td>
                    </tr>
                    {expanded === s.id && <tr className="bg-muted/30"><td colSpan={5} className="p-4"><SessionJobs sessionId={s.id} /></td></tr>}
                  </React.Fragment>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CardContent></Card>
    </div>
  );
}

function SessionJobs({ sessionId }: { sessionId: number }) {
  const { data: jobs = [], isLoading } = useQuery({
    queryKey: ['jobs', sessionId],
    queryFn: () => jobsApi.list(sessionId),
  });

  if (isLoading) return <Loader2 className="w-5 h-5 animate-spin text-primary mx-auto py-4" />;
  if (!jobs.length) return <p className="text-sm text-muted-foreground px-2">Sin jobs en esta sesión.</p>;

  return (
    <div className="space-y-2">
      {jobs.map(j => (
        <motion.div key={j.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="bg-background border rounded-lg p-3">
          <div className="flex items-center justify-between mb-2 flex-wrap gap-2">
            <div><p className="font-medium text-sm">{j.job_type} · {j.target_pattern}</p>
            <p className="text-xs text-muted-foreground">{j.completed_targets}/{j.total_targets} targets</p></div>
            <Badge variant={j.status === 'running' ? 'info' : j.status === 'completed' ? 'success' : j.status === 'failed' ? 'destructive' : 'secondary'} className="text-xs">{j.status}</Badge>
          </div>
          <WorkUnits jobId={j.id} />
        </motion.div>
      ))}
    </div>
  );
}

function WorkUnits({ jobId }: { jobId: number }) {
  const { data: units = [] } = useQuery({
    queryKey: ['workunits', jobId],
    queryFn: () => jobsApi.workUnits(jobId),
  });
  if (!units.length) return null;
  return (
    <details>
      <summary className="text-xs text-muted-foreground cursor-pointer hover:text-foreground">Work units ({units.length})</summary>
      <div className="mt-1.5 space-y-1 max-h-56 overflow-y-auto">
        {units.slice(0, 30).map(wu => (
          <div key={wu.id} className="flex items-center justify-between p-1.5 bg-muted/50 rounded text-xs">
            <span className="flex items-center gap-2 min-w-0"><Badge variant="outline" className="text-xs shrink-0">{wu.unit_type}</Badge>
            <span className="font-mono truncate">{wu.target_host}</span></span>
            <span className="flex items-center gap-1.5 shrink-0">
              <Badge variant={wu.status === 'completed' ? 'success' : wu.status === 'running' ? 'info' : wu.status === 'failed' ? 'destructive' : 'secondary'} className="text-xs">{wu.status}</Badge>
              {wu.error_message && <span className="text-red-500 truncate max-w-[180px]" title={wu.error_message}>{wu.error_message}</span>}
            </span>
          </div>
        ))}
      </div>
    </details>
  );
}
