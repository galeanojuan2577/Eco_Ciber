// Parseo tolerante de fechas de SQLite ("YYYY-MM-DD HH:MM:SS") e ISO.
export function toDate(v?: string | null): Date {
  if (!v) return new Date();
  const d = new Date(String(v).trim().replace(' ', 'T'));
  return isNaN(d.getTime()) ? new Date() : d;
}

export function fmtAgo(v?: string | null): string {
  const d = toDate(v);
  const diff = Date.now() - d.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return 'justo ahora';
  if (min < 60) return `hace ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24) return `hace ${h} h`;
  const days = Math.floor(h / 24);
  if (days < 30) return `hace ${days} d`;
  return d.toLocaleDateString();
}
