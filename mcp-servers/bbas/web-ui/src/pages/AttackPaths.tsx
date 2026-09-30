import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Plus, GitBranch, Edit, Trash2, X, Loader2 } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Input, Select, Badge, Textarea } from '../components/ui';
import { pathsApi, findingsApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';
import { fmtAgo } from '../utils/date';

const statusOptions = ['theoretical', 'testing', 'confirmed', 'exploited'];
const severityOptions = ['critical', 'high', 'medium', 'low'];
const techniques = ['idor', 'auth_bypass', 'sqli', 'xss', 'ssrf', 'rce', 'privilege_escalation', 'other'];

export function AttackPaths() {
  const { activeProject } = useUIStore();
  const qc = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [np, setNp] = useState({ name: '', description: '', severity: 'medium', bounty_potential: 'medium', steps: [] as any[] });

  const { data: paths = [], isLoading } = useQuery({
    queryKey: ['paths', activeProject?.id],
    queryFn: () => pathsApi.list(activeProject!.id),
    enabled: !!activeProject,
  });
  const { data: findings = [] } = useQuery({
    queryKey: ['findings-all', activeProject?.id],
    queryFn: () => findingsApi.list({ project_id: activeProject!.id, limit: 300 }),
    enabled: !!activeProject,
  });

  const createMut = useMutation({
    mutationFn: (d: any) => pathsApi.create(activeProject!.id, d),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['paths'] }); setCreating(false); setNp({ name: '', description: '', severity: 'medium', bounty_potential: 'medium', steps: [] }); },
  });
  const updMut = useMutation({
    mutationFn: ({ id, updates }: any) => pathsApi.update(id, updates),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['paths'] }),
  });
  const delMut = useMutation({
    mutationFn: (id: number) => pathsApi.delete(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['paths'] }),
  });

  if (!activeProject) return (
    <div className="text-center py-16"><GitBranch className="w-16 h-16 text-muted-foreground mx-auto mb-4" /><h2 className="text-xl font-bold">Selecciona un proyecto</h2></div>
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-bold tracking-tight">Attack Paths</h1>
        <p className="text-muted-foreground">Cadenas de explotación</p></div>
        <Button onClick={() => setCreating(true)}><Plus className="w-4 h-4 mr-2" />Nuevo attack path</Button>
      </div>

      {creating && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setCreating(false)}>
          <div className="bg-card border rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto space-y-4" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between"><h2 className="text-lg font-bold">Crear attack path</h2><Button variant="ghost" size="icon" onClick={() => setCreating(false)}><X /></Button></div>
            <Input label="Nombre" placeholder="IDOR → Auth bypass → ATO" value={np.name} onChange={(e) => setNp({ ...np, name: e.target.value })} />
            <Textarea label="Descripción" value={np.description} onChange={(e) => setNp({ ...np, description: e.target.value })} />
            <div className="grid grid-cols-2 gap-4">
              <Select label="Severidad" value={np.severity} onChange={(e) => setNp({ ...np, severity: e.target.value })} options={severityOptions.map(s => ({ value: s, label: s }))} />
              <Select label="Potencial de bounty" value={np.bounty_potential} onChange={(e) => setNp({ ...np, bounty_potential: e.target.value })} options={['high','medium','low'].map(s => ({ value: s, label: s }))} />
            </div>
            <div>
              <div className="flex justify-between items-center mb-2"><span className="font-medium text-sm">Pasos</span>
                <Button variant="outline" size="sm" onClick={() => setNp({ ...np, steps: [...np.steps, { order: np.steps.length + 1, title: '', technique: '', target: '' }] })}><Plus className="w-3 h-3 mr-1" />Paso</Button></div>
              {np.steps.map((st, i) => (
                <div key={i} className="p-3 border rounded-lg mb-2 space-y-2">
                  <div className="flex justify-between"><Badge variant="secondary">#{i + 1}</Badge>
                    <Button variant="ghost" size="icon" className="h-6 w-6 text-red-500" onClick={() => setNp({ ...np, steps: np.steps.filter((_, j) => j !== i).map((s, k) => ({ ...s, order: k + 1 })) })}><Trash2 className="w-3.5 h-3.5" /></Button></div>
                  <Input placeholder="Título del paso" value={st.title}
                    onChange={(e) => setNp({ ...np, steps: np.steps.map((s, j) => j === i ? { ...s, title: e.target.value } : s) })} />
                  <Input placeholder="Target (host)" value={st.target || ''}
                    onChange={(e) => setNp({ ...np, steps: np.steps.map((s, j) => j === i ? { ...s, target: e.target.value } : s) })} />
                  <Select value={st.technique || ''} onChange={(e) => setNp({ ...np, steps: np.steps.map((s, j) => j === i ? { ...s, technique: e.target.value } : s) })}
                    options={[{ value: '', label: 'Técnica...' }, ...techniques.map(t => ({ value: t, label: t }))]} />
                </div>
              ))}
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setCreating(false)}>Cancelar</Button>
              <Button disabled={!np.name.trim() || createMut.isPending} onClick={() => createMut.mutate(np)}>Crear</Button>
            </div>
          </div>
        </div>
      )}

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Paths ({paths.length})</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <Loader2 className="w-6 h-6 animate-spin text-primary mx-auto py-8" />
          ) : paths.length === 0 ? (
            <div className="text-center py-10"><GitBranch className="w-12 h-12 mx-auto mb-3 opacity-50 text-muted-foreground" /><p className="text-muted-foreground mb-4">Sin attack paths aún.</p></div>
          ) : (
            <div className="space-y-4">
              {paths.map(p => (
                <motion.div key={p.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="border rounded-lg p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-semibold">{p.name}</h3>
                        <Badge variant={p.severity as any} className={clsx('text-xs',
                          p.severity === 'critical' && 'bg-red-600 text-white',
                          p.severity === 'high' && 'bg-orange-600 text-white',
                          p.severity === 'medium' && 'bg-yellow-500 text-black',
                          p.severity === 'low' && 'bg-blue-500 text-white')}>{p.severity}</Badge>
                        <Badge variant={p.status === 'exploited' ? 'success' : p.status === 'confirmed' ? 'default' : p.status === 'testing' ? 'info' : 'secondary'} className="text-xs">{p.status}</Badge>
                        <Badge variant="outline" className="text-xs">{p.bounty_potential} bounty</Badge>
                      </div>
                      {p.description && <p className="text-sm text-muted-foreground mt-1">{p.description}</p>}
                    </div>
                    <div className="flex gap-1 shrink-0">
                      <Select value={p.status} onChange={(e) => updMut.mutate({ id: p.id, updates: { status: e.target.value } })}
                        options={statusOptions.map(s => ({ value: s, label: s }))} className="w-32 h-8" />
                      <Button variant="ghost" size="icon" className="text-red-500" onClick={() => delMut.mutate(p.id)}><Trash2 className="w-4 h-4" /></Button>
                    </div>
                  </div>
                  {p.steps.length > 0 && (
                    <div className="mt-3 space-y-1.5 border-t pt-3">
                      {p.steps.map((st: any) => (
                        <div key={st.order} className="flex items-center gap-2 text-sm bg-muted/50 rounded px-2 py-1.5">
                          <span className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">{st.order}</span>
                          <span className="truncate flex-1">{st.title}</span>
                          {st.technique && <Badge variant="secondary" className="text-xs">{st.technique}</Badge>}
                        </div>
                      ))}
                    </div>
                  )}
                  <p className="text-xs text-muted-foreground mt-2">{fmtAgo(p.created_at)}</p>
                </motion.div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
