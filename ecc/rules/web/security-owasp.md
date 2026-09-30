> Esta regla complementa `rules/web/security.md` con la checklist OWASP 2026 y patrones de seguridad avanzados.

# Security OWASP Rules

## OWASP Top 10 2026 — Checklist por Severidad

### CRÍTICO (bloqueante)
- [ ] Broken Access Control: Verificar RLS en TODAS las tablas Supabase
- [ ] Injection: Zod schemas en todos los inputs, parametrizar queries SQL
- [ ] Auth: Implementar MFA, rotación de refresh tokens, rate limiting en login
- [ ] Sensitive Data Exposure: No exponer service_role_key, no loguear passwords

### ALTO
- [ ] Security Misconfiguration: CSP headers, CORS restrictivo, debug mode OFF
- [ ] XSS: `dangerouslySetInnerHTML` solo con sanitizer, template escaping
- [ ] Insecure Deserialization: Validar JSON parseado, no usar `eval()`
- [ ] SSRF: Validar URLs externas, no permitir redirects a localhost

### MEDIO
- [ ] Known Vulnerabilities: `npm audit` en CI, Dependabot semanal
- [ ] Logging & Monitoring: Loggear accesos denegados, errores de auth
- [ ] Rate Limiting: Token bucket en todos los endpoints POST/PUT/DELETE
- [ ] Dependency Check: Revisar dependencias mensualmente

## Rate Limiting

```typescript
// Configuración por endpoint
const RATE_LIMITS = {
  '/api/auth/login':     { window: 60_000, max: 5 },     // 5/min
  '/api/auth/register':  { window: 3600_000, max: 3 },   // 3/hora
  '/api/todos':          { window: 60_000, max: 100 },   // 100/min
  '/api/reports':        { window: 60_000, max: 10 },    // 10/min
}
```

- Autenticado: 100 req/min por usuario
- No autenticado: 20 req/min por IP
- Login: 5 intentos/min por IP
- Reports/export: 10 req/min por usuario
- Webhooks: 500 req/min por IP

## Security Headers Obligatorios

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Content-Security-Policy: <nonce-based en producción>
```

## Supabase-Specific Security

1. **RLS en TODAS las tablas** — No hay excepciones
2. **Service role key** — Solo en server-side, nunca en browser
3. **Anon key** — Público, pero RLS restringe acceso
4. **Storage** — Buckets privados por defecto, público solo si es necesario
5. **Auth webhook** — Validar JWT antes de procesar datos
6. **SQL Injection** — Usar Supabase JS client (escapado automático), no raw SQL

## Dependency Security

### Auto-Update Schedule
- `npm audit` en cada CI run
- Dependabot semanal
- Revisión manual de breaking changes mensual

### Pre-commit Check
```bash
# En CI pipeline
npm audit --audit-level=high || exit 1
npx semgrep --config=auto src/
npx tsx scripts/check-secrets.ts
```

## Secret Management

- **NUNCA** hardcodear secrets en código
- Usar `.env.local` para desarrollo
- Variables de entorno en producción (Vercel/Netlify dashboard)
- `SUPABASE_SERVICE_ROLE_KEY` solo en server-side
- Rotar keys si se exponen inmediatamente

## Pre-commit Security Gate

Antes de cada commit:
1. `npm audit` — sin vulnerabilidades HIGH o CRITICAL
2. Revisar que no haya secrets hardcodeados
3. Verificar RLS policies nuevas
4. CSP configurado
5. Rate limiting en nuevos endpoints
