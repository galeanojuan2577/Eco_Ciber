> Esta regla complementa `rules/web/security.md` y `rules/web/patterns.md` con patrones específicos de Supabase.

# Supabase Rules

## Conexión y Pooling

### Puerto Correcto

| Modo | Puerto | Uso | Pool |
|------|--------|-----|------|
| Transaction | **6543** | API routes, serverless, browser | Compartido (recomendado) |
| Session | **5432** | Workers, migrations, bg jobs | Directo (sin pool) |

### Configuración del Pool

```toml
# supabase/config.toml
[db.pooler]
enabled = true
pool_mode = "transaction"
default_pool_size = 20  # CPU_cores × 2 (máx 45 en Supabase)
max_client_conn = 1000
```

### Prepared Statements

Cuando se usa Prisma con transaction mode (port 6543), añadir `?pgbouncer=true` a la URL de conexión o configurar `connectionString` con `connection_limit=1`. Sin esto, las prepared statements fallan silenciosamente en modo transaction.

## RLS (Row Level Security)

### Reglas Obligatorias

1. **TODA tabla con datos de usuario DEBE tener RLS habilitado**
2. **NUNCA** confiar solo en JWT del cliente para autorización
3. **Usar `auth.uid()`** no `auth.jwt()` para user_id (más seguro)
4. **Evitar subqueries en policies de tablas grandes** (< 10K filas está bien, más usar JWT claims)

### Patrón: JWT claims para tablas grandes

```sql
-- En lugar de subquery:
USING (org_id IN (SELECT org_id FROM org_members WHERE user_id = auth.uid()))

-- Usar JWT claim (el server setea org_id en el token):
USING (org_id = (auth.jwt() ->> 'org_id')::bigint)
```

### Políticas por Defecto

```sql
-- 1. Deshabilitar RLS (default)
ALTER TABLE mi_tabla ENABLE ROW LEVEL SECURITY;

-- 2. Denegar todo por defecto (default deny)
CREATE POLICY "deny_all" ON mi_tabla AS RESTRICTIVE FOR ALL USING (false);

-- 3. Permitir solo lo necesario
CREATE POLICY "user_select_own" ON mi_tabla
  FOR SELECT USING (user_id = auth.uid());
```

## Auth

- Usar `supabase.auth.getUser()` en server-side (verifica token real)
- Usar `supabase.auth.getSession()` solo en client-side
- Middleware de Next.js: `createMiddlewareClient` hace refresh automático
- **NUNCA** almacenar service_role_key en el cliente

## Storage

- Buckets públicos: solo lectura pública, escritura requiere auth
- Buckets privados: RLS con `auth.uid() = owner_id`
- Archivos de usuario: siempre dentro de `{userId}/` path
- Validar tipo MIME y tamaño máximo antes de upload

## Migrations

- Usar `supabase migration new` para generar migraciones
- **NUNCA** modificar migraciones ya aplicadas en producción
- Seed data en `supabase/seed.sql` con datos de prueba
- Antes de deploy: `supabase db push --dry-run` para verificar cambios
