> Esta regla complementa `rules/web/performance.md` con patrones de rendimiento para aplicaciones escalables.

# Production Performance Rules

## Diagnóstico Rápido: Test vs Producción

| Síntoma | Causa #1 | Fix Inmediato |
|---------|----------|---------------|
| Lento con 10 usuarios | Sin connection pooling | Usar Supavisor port 6543 |
| Query simple tarda >100ms | Falta índice | `CREATE INDEX CONCURRENTLY` |
| Dashboard lento | N+1 queries | Revisar RLS policies + joins |
| API timeout | Consulta sin límite | Añadir `.limit()` + paginación |
| Picos de latencia | Sin caché | Implementar cache-aside |
| Caídas en hora pico | Sin rate limiting | Añadir token bucket |

## Connection Pooling (Supavisor)

**Regla de oro del sizing:**
- `pool_size = (CPU_cores × 2) + effective_concurrent_disk_ops`
- Proyectos pequeños (< 10 conexiones): `10`
- Proyectos medianos (10-100 conexiones): `20`
- Proyectos grandes (100+ conexiones): `45` (máximo Supabase)

### Bulkheads (Separar pools por trabajo)

```typescript
// NO mezclar requests de usuario con reportes pesados
const webPool = createPool(10)     // API routes
const workerPool = createPool(5)   // Background jobs
const reportPool = createPool(3)   // Analytics pesados
```

## Index Strategy

### Índices Obligatorios

```sql
-- Siempre indexar foreign keys
CREATE INDEX CONCURRENTLY idx_table_fk ON table (foreign_key_id);

-- Siempre indexar columnas de ordenamiento
CREATE INDEX CONCURRENTLY idx_table_created_at ON table (created_at DESC);

-- Índices compuestos para queries frecuentes
CREATE INDEX CONCURRENTLY idx_table_user_status ON table (user_id, status);

-- Text search (requiere extensión pg_trgm)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX CONCURRENTLY idx_table_search ON table
  USING GIN (column gin_trgm_ops);
```

### Cuándo NO indexar
- Tablas con < 1000 filas
- Columnas con baja cardinalidad (boolean, status con 2-3 valores)
- Columnas que se actualizan frecuentemente pero nunca se buscan

## Cache Strategy

### Cache-Aside Pattern

```typescript
async function getCachedOrFetch<T>(
  key: string,
  fetch: () => Promise<T>,
  ttlMs = 60_000
): Promise<T> {
  const cached = cache.get(key)
  if (cached && cached.expiry > Date.now()) return cached.data as T

  const data = await fetch()
  cache.set(key, { data, expiry: Date.now() + ttlMs })
  return data
}
```

### ¿Qué cachear?
| Data | TTL | Estrategia |
|------|-----|------------|
| Perfiles de usuario | 5 min | Cache-aside |
| Listas de referencia | 30 min | Cache-aside |
| Configuración | 10 min | Stale-while-revalidate |
| Sesiones/auth | 0 | NO cachear |
| Datos en tiempo real | 0 | Usar Realtime de Supabase |

## N+1 Prevention

**Síntoma:** Dashboard con lista de 100 items tarda 10+ segundos.
**Causa:** 1 query para la lista + 100 queries individuales para detalles.
**Fix:** Usar JOINs o batch queries.

```sql
-- MAL: 1 + N queries
SELECT * FROM posts;                    -- 1
SELECT * FROM profiles WHERE id = $1;   -- N veces

-- BIEN: 1 query con JOIN
SELECT posts.*, profiles.name
FROM posts
JOIN profiles ON posts.author_id = profiles.id;
```

## Prevención de Caídas

1. **Rate limiting** en todos los endpoints autenticados
2. **Timeout** en todas las queries externas (por defecto 5s, max 30s)
3. **Circuit breaker** para servicios externos (fallar rápido > esperar)
4. **Graceful degradation** (si Supabase cae, mostrar datos cacheados)
5. **Alertas** cuando p95 latency > 500ms o error rate > 1%
