import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Plus, FolderKanban as ProjectIcon, Shield, Terminal as TermIcon, Settings as Cog, Loader2, Trash2, CheckCircle, Link2, X } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Input, Select, Badge } from '../components/ui';
import { projectsApi, scopeApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';

const typeOptions = ['recon', 'scan', 'enumerate', 'exploit', 'post-exploit', 'dos', 'phishing', 'all'];
const TABS = [
  { id: 'projects', label: 'Proyectos', icon: ProjectIcon },
  { id: 'scope', label: 'Scope', icon: Shield },
  { id: 'tools', label: 'Herramientas', icon: TermIcon },
  { id: 'general', label: 'General', icon: Cog },
] as const;

export function Settings() {
  const { activeProject, setActiveProject } = useUIStore();
  const qc = useQueryClient();
  const [tab, setTab] = useState<string>('projects');
  const [creating, setCreating] = useState(false);
  const [np, setNp] = useState({ name: '', program_url: '' });
  const [scopeForm, setScopeForm] = useState({ target: '', type: 'all', note: '', excluded: false });

  const { data: projects = [], isLoading: pLoading } = useQuery({ queryKey: ['projects'], queryFn: projectsApi.list });
  const { data: scope = [], isLoading: sLoading } = useQuery({
    queryKey: ['scope', activeProject?.id],
    queryFn: () => scopeApi.list(activeProject!.id),
    enabled: !!activeProject,
  });

  const createProj = useMutation({
    mutationFn: (d: any) => projectsApi.create(d),
    onSuccess: (p) => { qc.invalidateQueries({ queryKey: ['projects'] }); setCreating(false); setNp({ name: '', program_url: '' }); setActiveProject(p); },
  });
  const delProj = useMutation({
    mutationFn: (id: string) => projectsApi.delete(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['projects'] }),
  });
  const addScope = useMutation({
    mutationFn: (d: any) => scopeApi.add(activeProject!.id, d),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['scope'] }); setScopeForm({ target: '', type: 'all', note: '', excluded: false }); },
  });
  const delScope = useMutation({
    mutationFn: (ruleId: number) => scopeApi.delete(activeProject!.id, ruleId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['scope'] }),
  });

  return (
    <div className="space-y-6">
      <div><h1 className="text-3xl font-bold tracking-tight">Configuración</h1>
      <p className="text-muted-foreground">Gestiona proyectos, scope y herramientas</p></div>

      <div className="border-b border-border flex gap-1">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={clsx('flex items-center gap-2 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors',
              tab === t.id ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')}>
            <t.icon className="w-4 h-4" />{t.label}
          </button>
        ))}
      </div>

      {tab === 'projects' && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
          <div className="flex justify-end"><Button onClick={() => setCreating(true)}><Plus className="w-4 h-4 mr-2" />Nuevo proyecto</Button></div>
          {creating && (
            <Card><CardContent className="pt-6 space-y-3">
              <Input label="Nombre" value={np.name} onChange={(e) => setNp({ ...np, name: e.target.value })} placeholder="acme-corp" />
              <Input label="URL del programa" value={np.program_url} onChange={(e) => setNp({ ...np, program_url: e.target.value })} placeholder="https://hackerone.com/acme" />
              <div className="flex justify-end gap-2">
                <Button variant="outline" onClick={() => setCreating(false)}>Cancelar</Button>
                <Button disabled={!np.name.trim() || createProj.isPending} onClick={() => createProj.mutate(np)}>Crear</Button>
              </div>
            </CardContent></Card>
          )}
          <Card><CardContent className="p-0">
            {pLoading ? <Loader2 className="w-6 h-6 animate-spin text-primary mx-auto my-10" /> : projects.length === 0 ? (
              <p className="text-center text-muted-foreground py-10">Sin proyectos. Crea el primero.</p>
            ) : (
              <table className="w-full text-sm">
                <thead><tr className="border-b border-border bg-muted/50 text-left text-muted-foreground"><th className="p-3">Proyecto</th><th className="p-3">Programa</th><th className="p-3"></th></tr></thead>
                <tbody>{projects.map(p => (
                  <tr key={p.id} className="border-b border-border/50">
                    <td className="p-3"><div className="flex items-center gap-2">
                      <ProjectIcon className="w-4 h-4 text-primary" /><div><p className="font-medium">{p.name}</p><p className="text-xs text-muted-foreground font-mono">{p.id}</p></div></div></td>
                    <td className="p-3">{p.program_url && <a href={p.program_url} target="_blank" rel="noreferrer" className="text-primary flex items-center gap-1 text-xs">{p.program_url}<Link2 className="w-3 h-3" /></a>}</td>
                    <td className="p-3"><div className="flex gap-1 justify-end">
                      {activeProject?.id === p.id
                        ? <Button size="sm" disabled><CheckCircle className="w-3.5 h-3.5 mr-1" />Activo</Button>
                        : <Button variant="outline" size="sm" onClick={() => setActiveProject(p)}>Seleccionar</Button>}
                      <Button variant="ghost" size="icon" className="text-red-500 h-8 w-8" onClick={() => confirm('¿Borrar proyecto?') && delProj.mutate(p.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
                    </div></td>
                  </tr>
                ))}</tbody>
              </table>
            )}
          </CardContent></Card>
        </motion.div>
      )}

      {tab === 'scope' && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
          {!activeProject ? <p className="text-muted-foreground">Selecciona un proyecto en la pestaña Proyectos.</p> : (
            <>
              <Card><CardContent className="pt-6 space-y-3">
                <Input label="Target (soporta *.dominio.com)" value={scopeForm.target} onChange={(e) => setScopeForm({ ...scopeForm, target: e.target.value })} placeholder="*.ejemplo.com" />
                <Select label="Tipo" value={scopeForm.type} onChange={(e) => setScopeForm({ ...scopeForm, type: e.target.value })} options={typeOptions.map(t => ({ value: t, label: t }))} />
                <Input label="Nota de autorización" value={scopeForm.note} onChange={(e) => setScopeForm({ ...scopeForm, note: e.target.value })} />
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={scopeForm.excluded} onChange={(e) => setScopeForm({ ...scopeForm, excluded: e.target.checked })} className="accent-[hsl(var(--primary))]" />
                  <span className="text-sm">Excluido del scope (OOS)</span>
                </label>
                <Button disabled={!scopeForm.target.trim() || addScope.isPending} onClick={() => addScope.mutate(scopeForm)}>Agregar regla</Button>
              </CardContent></Card>
              <Card><CardContent className="p-0">
                {sLoading ? <Loader2 className="w-5 h-5 animate-spin mx-auto my-8 text-primary" /> : scope.length === 0 ? (
                  <p className="text-center text-muted-foreground py-8">Sin reglas de scope.</p>
                ) : (
                  <table className="w-full text-sm">
                    <thead><tr className="border-b border-border bg-muted/50 text-left text-muted-foreground"><th className="p-3">Target</th><th className="p-3">Tipo</th><th className="p-3">Nota</th><th className="p-3"></th></tr></thead>
                    <tbody>{scope.map(r => (
                      <tr key={r.id} className={clsx('border-b border-border/50', r.excluded && 'bg-red-500/10')}>
                        <td className="p-3 font-mono">{r.target}</td>
                        <td className="p-3"><Badge variant={r.excluded ? 'destructive' : 'outline'} className="text-xs">{r.excluded ? 'excluded' : r.type}</Badge></td>
                        <td className="p-3 text-muted-foreground truncate max-w-xs">{r.note || '—'}</td>
                        <td className="p-3 text-right"><Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => delScope.mutate(r.id)}><Trash2 className="w-3.5 h-3.5" /></Button></td>
                      </tr>
                    ))}</tbody>
                  </table>
                )}
              </CardContent></Card>
            </>
          )}
        </motion.div>
      )}

      {tab === 'tools' && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <p className="text-sm text-muted-foreground mb-4">Verifica manualmente con <code className="bg-muted px-1 rounded">&lt;tool&gt; -version</code>. BBAS los detecta automáticamente al escanear.</p>
          <div className="grid gap-4 md:grid-cols-3">
            {['subfinder','httpx','nuclei','amass','gobuster','zaproxy','nikto','nmap','dnsrecon'].map(t => (
              <Card key={t}><CardContent className="pt-6 flex items-center justify-between">
                <div><h3 className="font-medium capitalize">{t}</h3></div>
                <Badge variant="outline" className="text-xs font-mono">{t}</Badge>
              </CardContent></Card>
            ))}
          </div>
        </motion.div>
      )}

      {tab === 'general' && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <Card><CardHeader><CardTitle>Información</CardTitle></CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p><strong>Daemon:</strong> http://127.0.0.1:9000 (puerto configurable con BBAS_PORT)</p>
            <p><strong>PID file:</strong> /tmp/bbas-daemon.pid · <strong>Logs:</strong> /tmp/bbas-daemon.log</p>
            <p><strong>Gestión:</strong> recon start | stop | status | logs · bbas daemon ...</p>
            <p className="text-muted-foreground pt-2">El scope se valida contra check-scope.sh antes de cada acción activa.</p>
          </CardContent></Card>
        </motion.div>
      )}
    </div>
  );
}
