import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Target, Search, Globe, Lock, AlertTriangle, CheckCircle, Loader2, RefreshCw, Bug } from 'lucide-react';
import { Card, CardContent } from '../components/ui';
import { Button, Input, Select, Badge } from '../components/ui';
import { targetsApi, findingsApi } from '../services/api';
import { useUIStore } from '../store';
import { clsx } from 'clsx';
import { fmtAgo } from '../utils/date';

export function Targets() {
  const { activeProject } = useUIStore();
  const [search, setSearch] = useState('');
  const [locked, setLocked] = useState<'all' | 'locked' | 'unlocked'>('all');
  const [sortBy, setSortBy] = useState<'score' | 'host' | 'status_code' | 'updated_at'>('score');

  const { data: targets = [], isLoading, refetch } = useQuery({
    queryKey: ['targets', activeProject?.id],
    queryFn: () => targetsApi.list(activeProject!.id, 500),
    enabled: !!activeProject,
  });
  const { data: findings = [] } = useQuery({
    queryKey: ['findings-all-t', activeProject?.id],
    queryFn: () => findingsApi.list({ project_id: activeProject!.id, limit: 1000 }),
    enabled: !!activeProject,
  });

  const byHost = findings.reduce((acc: Record<string, any[]>, f) => {
    (acc[f.target_host] ||= []).push(f); return acc;
  }, {});

  const filtered = targets
    .filter(t => {
      if (search && !t.host.toLowerCase().includes(search.toLowerCase()) && !(t.title || '').toLowerCase().includes(search.toLowerCase())) return false;
      if (locked === 'locked' && !t.locked_type) return false;
      if (locked === 'unlocked' && t.locked_type) return false;
      return true;
    })
    .sort((a, b) => {
      let av = a[sortBy], bv = b[sortBy];
      if (sortBy === 'updated_at') { av = new Date(a.updated_at).getTime(); bv = new Date(b.updated_at).getTime(); }
      if (typeof av === 'string') { av = String(av).toLowerCase(); bv = String(bv).toLowerCase(); }
      return sortBy === 'host' ? (av < bv ? -1 : 1) : ((bv as number) - (av as number));
    });

  const statusColor = (c: number) =>
    c >= 200 && c < 300 ? 'text-green-500' : c >= 300 && c < 400 ? 'text-yellow-500' : c === 401 || c === 403 ? 'text-orange-500' : c >= 400 ? 'text-red-500' : 'text-muted-foreground';

  if (!activeProject) return (
    <div className="text-center py-16"><Target className="w-16 h-16 text-muted-foreground mx-auto mb-4" /><h2 className="text-xl font-bold">Selecciona un proyecto</h2></div>
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-3xl font-bold tracking-tight">Targets</h1>
        <p className="text-muted-foreground">{targets.length} descubiertos</p></div>
        <Button variant="outline" onClick={() => refetch()}><RefreshCw className="w-4 h-4 mr-2" />Refrescar</Button>
      </div>

      <div className="flex flex-wrap gap-2">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input placeholder="Buscar host/título..." value={search} onChange={(e) => setSearch(e.target.value)} className="pl-10" />
        </div>
        <Select value={locked} onChange={(e) => setLocked(e.target.value as any)}
          options={[{value:'all',label:'Todos'},{value:'unlocked',label:'Activos'},{value:'locked',label:'Locked / falsas alarmas'}]} className="w-56" />
        <Select value={sortBy} onChange={(e) => setSortBy(e.target.value as any)}
          options={[{value:'score',label:'Score'},{value:'status_code',label:'Status'},{value:'updated_at',label:'Actualizado'}]} className="w-40" />
      </div>

      <Card><CardContent className="p-0">
        {isLoading ? (
          <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto my-16" />
        ) : filtered.length === 0 ? (
          <div className="text-center py-16"><Target className="w-14 h-14 mx-auto mb-3 opacity-50 text-muted-foreground" /><p className="text-muted-foreground">Sin targets. Lanza un scan recon primero.</p></div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="border-b border-border bg-muted/50 text-left text-muted-foreground">
                <th className="p-3">Score</th><th className="p-3">Host</th><th className="p-3">Status</th><th className="p-3">Tech</th><th className="p-3">Findings</th><th className="p-3">Estado</th><th className="p-3">Actualizado</th>
              </tr></thead>
              <tbody>
                {filtered.map(t => {
                  const fs = byHost[t.host] || [];
                  const crit = fs.filter(f => f.severity === 'critical').length;
                  const high = fs.filter(f => f.severity === 'high').length;
                  return (
                    <tr key={t.id} className="border-b border-border/50 hover:bg-muted/50">
                      <td className="p-3"><div className="flex items-center gap-2">
                        <div className="w-14 h-2 bg-muted rounded-full overflow-hidden"><div className="h-full bg-primary" style={{ width: `${Math.min(t.score, 100)}%` }} /></div>
                        <span className="font-mono font-bold">{t.score}</span></div></td>
                      <td className="p-3"><p className="font-mono font-medium">{t.host}</p>{t.title && <p className="text-xs text-muted-foreground truncate max-w-xs">{t.title}</p>}</td>
                      <td className={clsx('p-3 font-mono', statusColor(t.status_code))}>{t.status_code || '—'}</td>
                      <td className="p-3"><div className="flex flex-wrap gap-1 max-w-xs">
                        {t.tech_stack.slice(0, 4).map(x => <Badge key={x} variant="secondary" className="text-xs">{x}</Badge>)}
                        {t.tech_stack.length > 4 && <Badge variant="outline" className="text-xs">+{t.tech_stack.length - 4}</Badge>}
                      </div></td>
                      <td className="p-3"><div className="flex gap-1">
                        {crit > 0 && <Badge variant="destructive" className="text-xs">{crit}</Badge>}
                        {high > 0 && <Badge variant="high" className="text-xs">{high}</Badge>}
                        {fs.length - crit - high > 0 && <Badge variant="secondary" className="text-xs">{fs.length - crit - high}</Badge>}
                        {!fs.length && <span className="text-muted-foreground text-xs">—</span>}
                      </div></td>
                      <td className="p-3">{t.locked_type
                        ? <span className="flex items-center gap-1.5 text-red-500 text-xs"><AlertTriangle className="w-3.5 h-3.5" />{t.locked_type.replace('-', ' ')}</span>
                        : <CheckCircle className="w-4 h-4 text-green-500" />}</td>
                      <td className="p-3 text-muted-foreground whitespace-nowrap">{fmtAgo(t.updated_at)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </CardContent></Card>
    </div>
  );
}
