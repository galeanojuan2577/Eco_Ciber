import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, X, Bug, Edit, Trash2, CheckCircle, Loader2, ChevronLeft, ChevronRight } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Input, Select, Badge } from '../components/ui';
import { findingsApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';
import { SEVERITY_COLORS } from '../types';
import type { Finding } from '../types';
import { fmtAgo } from '../utils/date';

const statusOptions = ['open', 'confirmed', 'false_positive', 'fixed', 'wont_fix'];
const severityOptions = ['', 'critical', 'high', 'medium', 'low', 'info'];

export function Findings() {
  const { activeProject, selectedFindings, toggleFindingSelection, clearFindingSelection } = useUIStore();
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [sev, setSev] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(0);
  const [editing, setEditing] = useState<Finding | null>(null);
  const pageSize = 50;

  const { data: findings = [], isLoading } = useQuery({
    queryKey: ['findings', activeProject?.id, sev, status, page],
    queryFn: () => findingsApi.list({
      project_id: activeProject?.id || '',
      min_severity: sev || undefined,
      status: status || undefined,
      limit: pageSize,
      offset: page * pageSize,
    }),
    enabled: !!activeProject,
    placeholderData: (p) => p,
  });

  const updMut = useMutation({
    mutationFn: ({ id, updates }: { id: number; updates: Partial<Finding> }) => findingsApi.update(id, updates),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['findings'] }),
  });
  const delMut = useMutation({
    mutationFn: (id: number) => findingsApi.delete(id),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['findings'] }); clearFindingSelection(); },
  });

  const filtered = useMemo(() => {
    if (!search) return findings;
    const t = search.toLowerCase();
    return findings.filter(f =>
      f.title.toLowerCase().includes(t) ||
      f.target_host.toLowerCase().includes(t) ||
      f.tags.some(x => x.toLowerCase().includes(t)));
  }, [findings, search]);

  const stats = useMemo(() => ({
    total: findings.length,
    critical: findings.filter(f => f.severity === 'critical').length,
    high: findings.filter(f => f.severity === 'high').length,
    open: findings.filter(f => f.status === 'open').length,
  }), [findings]);

  if (!activeProject) return (
    <div className="text-center py-16">
      <Bug className="w-16 h-16 text-muted-foreground mx-auto mb-4" />
      <h2 className="text-xl font-bold">Selecciona un proyecto</h2>
    </div>
  );

  const bulk = (action: string) => {
    selectedFindings.forEach(id => action === 'delete' ? delMut.mutate(id) : updMut.mutate({ id, updates: { status: action as any } }));
    clearFindingSelection();
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-bold tracking-tight">Hallazgos</h1>
        <p className="text-muted-foreground">{filtered.length} hallazgos</p></div>
      </div>

      <div className="grid gap-4 sm:grid-cols-4">
        {[{l:'Total',v:stats.total,c:'text-foreground'},{l:'Críticos',v:stats.critical,c:'text-red-500'},{l:'Altos',v:stats.high,c:'text-orange-500'},{l:'Abiertos',v:stats.open,c:'text-green-500'}].map(s => (
          <Card key={s.l}><CardContent className="p-4 text-center"><p className={clsx('text-2xl font-bold', s.c)}>{s.v}</p><p className="text-sm text-muted-foreground">{s.l}</p></CardContent></Card>
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input placeholder="Buscar..." value={search} onChange={(e) => setSearch(e.target.value)} className="pl-10" />
        </div>
        <Select value={sev} onChange={(e) => setSev(e.target.value)} options={severityOptions.map(s => ({ value: s, label: s || 'Toda severidad' }))} className="w-40" />
        <Select value={status} onChange={(e) => setStatus(e.target.value)} options={[{value:'',label:'Todo estado'}, ...statusOptions.map(s => ({ value: s, label: s }))]} className="w-44" />
      </div>

      {selectedFindings.length > 0 && (
        <div className="flex items-center justify-between p-3 bg-primary/10 border border-primary/20 rounded-lg">
          <span className="text-sm font-medium">{selectedFindings.length} seleccionados</span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => bulk('confirmed')}><CheckCircle className="w-3.5 h-3.5 mr-1" />Confirmar</Button>
            <Button variant="outline" size="sm" onClick={() => bulk('false_positive')}>Falso positivo</Button>
            <Button variant="destructive" size="sm" onClick={() => bulk('delete')}><Trash2 className="w-3.5 h-3.5 mr-1" />Borrar</Button>
            <Button variant="ghost" size="sm" onClick={clearFindingSelection}><X className="w-4 h-4" /></Button>
          </div>
        </div>
      )}

      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto my-16" />
          ) : filtered.length === 0 ? (
            <div className="text-center py-16"><Bug className="w-14 h-14 mx-auto mb-3 opacity-50 text-muted-foreground" /><p className="text-muted-foreground">Sin hallazgos. Lanza un scan en Recon.</p></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-border bg-muted/50 text-left text-muted-foreground">
                  <th className="p-3 w-10"></th><th className="p-3">Sev</th><th className="p-3">Título</th><th className="p-3">Target</th><th className="p-3">Tool</th><th className="p-3">Bounty</th><th className="p-3">Estado</th><th className="p-3">Creado</th><th className="p-3 w-20"></th>
                </tr></thead>
                <tbody>
                  {filtered.map(f => (
                    <tr key={f.id} className="border-b border-border/50 hover:bg-muted/50">
                      <td className="p-3"><input type="checkbox" checked={selectedFindings.includes(f.id)} onChange={() => toggleFindingSelection(f.id)} /></td>
                      <td className="p-3"><Badge variant={f.severity as any} className={clsx('text-xs', SEVERITY_COLORS[f.severity])}>{f.severity}</Badge></td>
                      <td className="p-3 max-w-xs"><p className="font-medium truncate">{f.title}</p></td>
                      <td className="p-3 font-mono text-xs">{f.target_host}</td>
                      <td className="p-3"><Badge variant="secondary" className="text-xs">{f.tool}</Badge></td>
                      <td className="p-3"><Badge variant={f.bounty_probability === 'high' ? 'success' : f.bounty_probability === 'medium' ? 'warning' : 'outline'} className="text-xs">{f.bounty_probability}</Badge></td>
                      <td className="p-3">
                        <Select value={f.status} onChange={(e) => updMut.mutate({ id: f.id, updates: { status: e.target.value as any } })}
                          options={statusOptions.map(s => ({ value: s, label: s }))} className="w-32 h-8" />
                      </td>
                      <td className="p-3 text-muted-foreground whitespace-nowrap">{fmtAgo(f.created_at)}</td>
                      <td className="p-3">
                        <div className="flex gap-1">
                          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => setEditing(f)}><Edit className="w-3.5 h-3.5" /></Button>
                          <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => delMut.mutate(f.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="px-4 py-3 border-t border-border flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Página {page + 1}</span>
                <div className="flex gap-2">
                  <Button variant="outline" size="icon" disabled={page === 0} onClick={() => setPage(p => p - 1)}><ChevronLeft className="w-4 h-4" /></Button>
                  <Button variant="outline" size="icon" disabled={findings.length < pageSize} onClick={() => setPage(p => p + 1)}><ChevronRight className="w-4 h-4" /></Button>
                </div>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      <AnimatePresence>
        {editing && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setEditing(null)}>
            <motion.div initial={{ scale: 0.95 }} animate={{ scale: 1 }} exit={{ scale: 0.95 }}
              className="bg-card border rounded-lg p-6 w-full max-w-lg space-y-4" onClick={(e) => e.stopPropagation()}>
              <div className="flex justify-between items-center"><h2 className="text-lg font-bold">Editar hallazgo</h2>
                <Button variant="ghost" size="icon" onClick={() => setEditing(null)}><X className="w-5 h-5" /></Button></div>
              <Input label="Título" value={editing.title} onChange={(e) => setEditing({ ...editing, title: e.target.value })} />
              <Input label="Target" value={editing.target_host} onChange={(e) => setEditing({ ...editing, target_host: e.target.value })} />
              <Select label="Severidad" value={editing.severity}
                onChange={(e) => setEditing({ ...editing, severity: e.target.value as any })}
                options={['critical','high','medium','low','info'].map(s => ({ value: s, label: s }))} />
              <Select label="Probabilidad de bounty" value={editing.bounty_probability}
                onChange={(e) => setEditing({ ...editing, bounty_probability: e.target.value as any })}
                options={['high','medium','low','unknown'].map(s => ({ value: s, label: s }))} />
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" onClick={() => setEditing(null)}>Cancelar</Button>
                <Button onClick={() => { updMut.mutate({ id: editing.id, updates: editing }); setEditing(null); }}>Guardar</Button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
