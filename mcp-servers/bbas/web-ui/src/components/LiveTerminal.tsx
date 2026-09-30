import React, { useEffect, useRef, useState } from 'react';
import { Terminal, Radio } from 'lucide-react';

interface Stats { pending: number; running: number; completed: number; failed: number; live: number }

export function LiveTerminal({ sessionId, onEnded }: { sessionId: number; onEnded?: () => void }) {
  const [lines, setLines] = useState<string[]>([`conectando a la sesión #${sessionId}…`]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [ended, setEnded] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const es = new EventSource(`/api/sessions/${sessionId}/stream`);
    es.addEventListener('log', (ev) => {
      try {
        const d = JSON.parse((ev as MessageEvent).data);
        setLines((prev) => [...prev.slice(-400), d.line]);
      } catch {}
    });
    es.addEventListener('stats', (ev) => {
      try { setStats(JSON.parse((ev as MessageEvent).data)); } catch {}
    });
    es.addEventListener('end', () => { setEnded(true); es.close(); onEnded?.(); });
    es.onerror = () => { /* reconexión automática del navegador */ };
    return () => es.close();
  }, [sessionId]);

  useEffect(() => {
    boxRef.current?.scrollTo({ top: boxRef.current.scrollHeight });
  }, [lines]);

  return (
    <div className="rounded-lg border border-border overflow-hidden">
      <div className="flex items-center justify-between px-3 py-2 bg-muted/60 border-b border-border">
        <span className="flex items-center gap-2 text-sm font-medium">
          <Terminal className="w-4 h-4" /> Recon en vivo
          <span className="text-xs text-muted-foreground">· sesión #{sessionId}</span>
        </span>
        <span className="flex items-center gap-3 text-xs text-muted-foreground">
          <Radio className={`w-3.5 h-3.5 ${ended ? 'text-gray-500' : 'text-red-500 animate-pulse'}`} />
          {ended ? 'finalizado' : 'LIVE'}
          {stats && (
            <>
              <span>pend:{stats.pending}</span>
              <span>run:{stats.running}</span>
              <span className="text-green-600">hechos:{stats.completed}</span>
              <span className="text-blue-600">vivos:{stats.live}</span>
            </>
          )}
        </span>
      </div>
      <div ref={boxRef}
           className="h-56 overflow-y-auto bg-[#020617] text-slate-200 font-mono text-[11px] leading-5 px-3 py-2">
        {lines.map((l, i) => (
          <div key={i} className="whitespace-pre-wrap break-all">{l}</div>
        ))}
        {!ended && <div className="animate-pulse text-green-500">▌</div>}
      </div>
    </div>
  );
}
