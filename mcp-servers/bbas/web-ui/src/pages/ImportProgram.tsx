import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { useQueryClient } from '@tanstack/react-query';
import { Link2, Loader2, Search, CheckCircle, XCircle, ShieldAlert, Play, FileText } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui';
import { Button, Input, Badge, Textarea } from '../components/ui';
import { clsx } from 'clsx';
import { useUIStore } from '../store';
import { LiveTerminal } from '../components/LiveTerminal';

interface AnalyzeResult {
  ok?: boolean;
  platform?: string;
  source?: string;
  program?: string;
  url?: string;
  in_scope?: string[];
  out_scope?: string[];
  can_do?: string[];
  cant_do?: string[];
  flags?: Record<string, any>;
  error?: string;
}

export function ImportProgram() {
  const { setActiveProject, addNotification } = useUIStore();
  const queryClient = useQueryClient();
  const [url, setUrl] = useState('');
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState<AnalyzeResult | null>(null);
  const [selIn, setSelIn] = useState<Set<string>>(new Set());
  const [selOut, setSelOut] = useState<Set<string>>(new Set());
  const [programName, setProgramName] = useState('');
  const [projectId, setProjectId] = useState('');
  const [consent, setConsent] = useState(false);
  const [committing, setCommitting] = useState<'scope' | 'recon' | null>(null);
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);
  const [scanInfo, setScanInfo] = useState<any>(null);
  const [liveSid, setLiveSid] = useState<number | null>(null);

  const analyze = async () => {
    if (!url.trim()) return;
    setAnalyzing(true); setResult(null); setMsg(null); setScanInfo(null);
    try {
      const r = await fetch('/api/import/analyze', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url }),
      });
      const d = await r.json();
      if (!r.ok) throw new Error(d.detail || 'Error analizando');
      setResult(d);
      setSelIn(new Set(d.in_scope || []));
      setSelOut(new Set(d.out_scope || []));
      setProgramName(d.program || '');
    } catch (e: any) {
      setMsg({ type: 'err', text: e.message });
    } finally {
      setAnalyzing(false);
    }
  };

  const toggle = (set: Set<string>, v: string, apply: (s: Set<string>) => void) => {
    const n = new Set(set);
    n.has(v) ? n.delete(v) : n.add(v);
    apply(n);
  };

  const commit = async (launch: boolean) => {
    if (!consent) { setMsg({ type: 'err', text: 'Marca la casilla de autorización/legalidad para continuar.' }); return; }
    setCommitting(launch ? 'recon' : 'scope'); setMsg(null); setScanInfo(null);
    try {
      const r = await fetch('/api/import/commit', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          program: programName || url,
          url,
          project_id: projectId || undefined,
          in_scope: [...selIn],
          out_scope: [...selOut],
          consent: true,
          launch_recon: launch,
        }),
      });
      const d = await r.json();
      if (!r.ok) throw new Error(typeof d.detail === 'string' ? d.detail : JSON.stringify(d.detail));
      setMsg({
        type: 'ok',
        text: `Proyecto ${d.project_name} · ${d.added_in} in-scope y ${d.added_out} OOS importados` +
              (d.scan ? ` · Recon lanzado (${d.scan.work_units_queued} unidades)` : ''),
      });
      setProjectId(d.project_id);
      queryClient.invalidateQueries({ queryKey: ['projects'] });
      if (d.scan) { setScanInfo(d.scan); setLiveSid(d.scan.session_id); }
      try {
        const pr = await fetch(`/api/projects/${d.project_id}`);
        if (pr.ok) {
          const pj = await pr.json();
          setActiveProject(pj);
          addNotification({ type: 'success', title: 'Proyecto activo', message: `${pj.name} seleccionado` });
        }
      } catch {}
    } catch (e: any) {
      setMsg({ type: 'err', text: e.message });
    } finally {
      setCommitting(null);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Importar Programa</h1>
        <p className="text-muted-foreground">
          Pega el enlace del programa (Bugcrowd, HackerOne…), analiza su alcance e importa el scope.
        </p>
      </div>

      {/* Paso 1: URL */}
      <Card>
        <CardContent className="pt-6 flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1">
            <Link2 className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <input
              className="flex h-10 w-full rounded-lg border border-input bg-background pl-10 pr-3 py-2 text-sm"
              placeholder="https://bugcrowd.com/engagements/optus-mbb-og#targets"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && analyze()}
            />
          </div>
          <Button onClick={analyze} disabled={analyzing || !url.trim()}>
            {analyzing ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" />Analizando…</> : <><Search className="w-4 h-4 mr-2" />Analizar programa</>}
          </Button>
        </CardContent>
      </Card>

      {msg && (
        <div className={clsx('p-3 rounded-lg border text-sm',
          msg.type === 'ok' ? 'bg-green-500/10 border-green-500/30 text-green-600'
                            : 'bg-red-500/10 border-red-500/30 text-red-600')}>
          {msg.text}
          {scanInfo && (
            <p className="mt-1 text-xs opacity-80">Sesión #{scanInfo.session_id} · semillas: {scanInfo.seeds.join(', ')}</p>
          )}
        </div>
      )}

      {liveSid && <LiveTerminal sessionId={liveSid} />}

      {/* Resultado */}
      {result && (
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
          <div className="flex items-center gap-2 flex-wrap">
            <Badge variant="info">{result.platform}</Badge>
            <Badge variant="outline">fuente: {result.source}</Badge>
            <span className="text-sm text-muted-foreground">{result.in_scope?.length || 0} in-scope · {result.out_scope?.length || 0} fuera</span>
          </div>

          <div className="grid gap-6 lg:grid-cols-3">
            <Card className="lg:col-span-2">
              <CardHeader><CardTitle className="text-lg">Alcance detectado</CardTitle></CardHeader>
              <CardContent className="space-y-4">
                <Input label="Nombre del proyecto" value={programName}
                       onChange={(e) => setProgramName(e.target.value)} />

                <div>
                  <p className="text-sm font-medium mb-2 flex items-center gap-2">
                    <CheckCircle className="w-4 h-4 text-green-500" /> In-scope (importados marcados)
                  </p>
                  <div className="max-h-64 overflow-y-auto space-y-1 border rounded-lg p-2">
                    {(result.in_scope || []).map((t) => (
                      <label key={t} className="flex items-center gap-2 p-1.5 hover:bg-muted/50 rounded cursor-pointer">
                        <input type="checkbox" checked={selIn.has(t)} onChange={() => toggle(selIn, t, setSelIn)} />
                        <span className="font-mono text-xs">{t}</span>
                      </label>
                    ))}
                  </div>
                </div>

                <div>
                  <p className="text-sm font-medium mb-2 flex items-center gap-2">
                    <XCircle className="w-4 h-4 text-red-500" /> Fuera de alcance (se guardarán como excluidos)
                  </p>
                  <div className="max-h-40 overflow-y-auto space-y-1 border border-red-500/20 bg-red-500/5 rounded-lg p-2">
                    {(result.out_scope || []).map((t) => (
                      <label key={t} className="flex items-center gap-2 p-1.5 hover:bg-muted/50 rounded cursor-pointer">
                        <input type="checkbox" checked={selOut.has(t)} onChange={() => toggle(selOut, t, setSelOut)} />
                        <span className="font-mono text-xs line-through decoration-red-400">{t}</span>
                      </label>
                    ))}
                    {!result.out_scope?.length && <p className="text-xs text-muted-foreground p-1">Sin exclusiones detectadas.</p>}
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader><CardTitle className="text-lg flex items-center gap-2"><ShieldAlert className="w-5 h-5 text-yellow-500" />Reglas</CardTitle></CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <p className="text-xs font-semibold text-green-600 mb-1">✓ Puedes hacer</p>
                  <ul className="space-y-1">
                    {(result.can_do || []).map((c, i) => (
                      <li key={i} className="text-xs text-muted-foreground">• {c}</li>
                    ))}
                  </ul>
                </div>
                <div>
                  <p className="text-xs font-semibold text-red-600 mb-1">✗ No puedes hacer</p>
                  <ul className="space-y-1">
                    {(result.cant_do || []).map((c, i) => (
                      <li key={i} className="text-xs text-muted-foreground">• {c}</li>
                    ))}
                  </ul>
                </div>
                <label className="flex items-start gap-2 cursor-pointer pt-2 border-t">
                  <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)}
                         className="mt-0.5 accent-[hsl(var(--primary))]" />
                  <span className="text-xs text-muted-foreground">
                    Confirmo que este programa está autorizado y acepto sus términos antes de
                    ejecutar cualquier reconocimiento.
                  </span>
                </label>
                <div className="space-y-2">
                  <Button className="w-full" variant="outline"
                          disabled={!selIn.size && !selOut.size || committing !== null}
                          onClick={() => commit(false)}>
                    {committing === 'scope' ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <FileText className="w-4 h-4 mr-2" />}
                    Importar al scope
                  </Button>
                  <Button className="w-full"
                          disabled={!consent || !selIn.size || committing !== null}
                          onClick={() => commit(true)}>
                    {committing === 'recon' ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Play className="w-4 h-4 mr-2" />}
                    Importar + Reconocimiento automático
                  </Button>
                  {projectId && (
                    <a href="/targets" className="block text-center text-xs text-primary hover:underline pt-1">
                      Ver targets del proyecto →
                    </a>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </motion.div>
      )}
    </div>
  );
}
