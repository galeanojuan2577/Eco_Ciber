# Patterns Log

## [2026-08-14] Re-verificación de consistencia antes de reportar (3+ runs)
- **Contexto:** bug bounty Chime. Para no reportar hallazgos muertos, re-ejecuté cada PoC ≥3 veces en la sesión actual.
- **Solución:** loop de 3 runs por vector + captura del header `Server` en cada 403/429 para detectar cambios de WAF. Resultado: separó claramente lo replicable (H3 userProgress, 200/200/200) de lo no verificable (403 CF idéntico en 6/6).
- **Regla:** un hallazgo solo se reporta si se replica 3/3 en la sesión actual y el stack de bloqueo es consistente.

## [2026-08-14] Ranking de vectores por valor esperado accesible (EV real)
- **Contexto:** el usuario pidió ranquear vulnerabilidades por payout. El ranking naive (payout × prob. aceptación) sobrevaloraba vectores inalcanzables.
- **Solución:** EV_real = payout × P(aceptación) × P(acceso disponible). Solo los vectores con acceso presente tienen EV > 0 hoy. Produjo un ranking honesto: el único reportable era H3 (~$15 EV), el resto EV 0 por bloqueo Cloudflare / requerir móvil real.
- **Regla:** al priorizar trabajo ofensivo, calcular EV con el factor de accesibilidad; nunca clasificar por severidad teórica.

## [2026-08-14] Mapear esquema GraphQL sin introspección vía errores verbosos
- **Contexto:** `__schema` bloqueado (401) en el GraphQL de Chime, pero los errores son verbosos.
- **Solución:** enumerar raíces/tipos/campos probando campos inexistentes → error `undefinedField` revela el typeName real del root (ej. `MutationsEnrollmentUnauthenticatedMutationRoot`); campos de input → "InputObject X doesn't accept argument Y" mapea el input object completo. Permitió confirmar qué campos NO existen (documentación negativa) sin introspección.
- **Regla:** con errores verbosos, la enumeración negativa (probar campos y leer el error) mapea el esquema igual que introspección.

## [2026-08-14] Extraer spec OpenAPI de una SPA ReadMe sin llamar a la API
- **Contexto:** la spec de `developer.chime.com` no era pública (privacy=admin, 429/403 al intentar /openapi).
- **Solución:** usar eval del browser sobre la SPA ReadMe → `ReferenceStore.getState().operation.oas` expone la spec OpenAPI completa del endpoint actual (server, security, paths, schemas) sin tocar la API backend. Capturado endpoint por endpoint navegando las rutas /reference/*.
- **Regla:** en SPAs de documentación (ReadMe, Mintlify, Stoplight), buscar en el estado del store de React/Vue la spec antes de intentar rutas /openapi o /llms.

## [2026-08-13] Alinear rutas de referencias para eliminar ambigüedad
- **Contexto:** auditoría del stack de ciberseguridad detectó que agentes/skills/commands referenciaban `rules/cyber/*.md` como ruta relativa ambigua (no existía en el repo ECC).
- **Solución:** usar `__OPENCODE_ROOT__/rules/cyber/*.md` (placeholder portable) en el repo ECC y plantilla `opencode/`; usar ruta absoluta `/root/.config/opencode/rules/cyber/*.md` en los archivos locales reales.
- **Regla:** toda referencia a reglas/scripts del ecosistema debe incluir la ruta completa (placeholder o absoluta), nunca relativa.

## [2026-08-15] OIDC discovery idéntico entre orgs engagement
- **Contexto:** Comparación de `/.well-known/openid-configuration` entre org 5453 y 5454 del mismo bug bounty. Ambos issuer `https://bugcrowd-pam-54XX.oktapreview.com`, mismos grant_types (password/mfa-otp/otp/oob/device_code/ciba), token_endpoint_auth_methods incluye `none`, scopes openid/email/profile/address/phone/offline_access/groups. Descubrimiento idéntico por diseño Okta.
- **Patrón:** en engagements Okta con múltiples orgs, el OIDC discovery es idéntico entre orgs del mismo engagement. Verificar siempre ambos antes de asumir diferencias de configuración.
- **Gatillo:** al evaluar superficie OIDC en orgs multiples, comparar discovery first.

## [2026-08-15] Aislamiento cross-tenant SSO Okta confirmado
- **Contexto:** Sesión SSO org 5453 (`bugbounty.okta@gmail.com`, admin console `/admin/oauth2/as`) NO autentica en org 5454 admin console (`bugcrowd-pam-5454-admin.oktapreview.com`). El 5454 redirige a Sign In PKCE code_challenge S256, client_id `okta.b58d5b75-...`. Comportamiento esperado, no hallazgo.
- **Patrón:** las sesiones SSO Okta son org-aisladas por diseño. Un login/enrollado en un org no concede acceso al otro. Probar cross-tenant session transfer siempre que se evalúe aislamiento de tenant.
- **Gatillo:** cualquier evaluación de "mismo usuario en distinto org" debe verificar SSO isolation primero.

## [2026-08-15] DCR anónimo y POST apps requieren auth/DPoP en Okta
- **Contexto:** `POST /oauth2/v1/clients` anónimo → **E0000005 Invalid session** (Okta DCR exige token SSWS/bearer; no es open registration). `POST /api/v1/apps` vía API admin → **403 body vacío** (requiere DPoP proof; sin SSWS disponible en scope manual).
- **Patrón:** en Okta engagements, el Dynamic Client Registration (DCR) `/oauth2/v1/clients` no está abierto para registro anónimo; todo client registration requiere auth (SSWS o bearer token). Las mutations de apps vía `/api/v1/apps` requieren DPoP proof — no usar eventos JS sintéticos ni curl anónimo.
- **Gatillo:** al intentar registrar clients o crear apps en Okta, considerar que se requiere auth previo.

## [2026-08-15] Characterización endpoint file upload AtSpoke (IDOR)
- **Contexto:** `GET /file/a/view/{attachment_id}` en AtSpoke 5453: 200 text/plain propio (23 bytes), 404 id inexistente/malformado, 401 anónimo. **Attachment id = ObjectId Mongo secuencial/adivinable** (patrón `6a80a80f125adf9e23b435xx`). El path `/file/a/view/{id}` no lleva referencia de request/usuario → control solo por attachment id. Vector IDOR por enumeración potencial.
- **Patrón:** en AtSpoke 5453, los attachment ids son ObjectId Mongo secuenciales, el endpoint de descarga no valida pertenencia de request/usuario, solo el id de attachment. Cualquier sesión válida puede intentar enumerar ids.
- **Gatillo:** al auditar upload/descarga de archivos en AtSpoke, verificar siempre el pattern del attachment id y si el path carrying ownership info.

## [2026-08-15] Password policy AtSpoke 5453 y fallback de test user
- **Contexto:** Policy: ≥8 chars, lowercase, uppercase, number, **no parts of your username**, no repetir últimas 4 passwords. 1er intento `AtspokeTest!2026` falló por contener "Atspoke". Test user `atspoke-test@bugcrowdninja.com` creado con `BugHunter99Qq!` (éxito 2.º intento). Añadido al team IT como TEAM_ADMIN (Mongo id `6a80aa71a5ced6e11b69ed58`).
- **Patrón:** en AtSpoke 5453, la policy de password rechaza passwords que contengan el username (parcial o total). El 1er intento debe evitar cualquier substring del username. Test user creación exitosa requiere password satisfactorio + UI Add member → búsqueda por email → selección.
- **Gatillo:** al crear usuarios test en AtSpoke con policy password, test el primer password antes de asumir válido; usar combobox de búsqueda por email en UI para agregar equipos.

## [2026-08-17] IDOR file upload AtSpoke DESCARTADO — control valida pertenencia
- **Contexto:** PoC cross-team limpio en AtSpoke 5453. Attachment real subido por admin (POST /file/upload JSON base64 {file:"data:...",fileName} + X-XSRF-TOKEN → {gcsFile,...}) en request filed bajo team Privileged Access (PAM). Resultado: admin=200, test user (TEAM_ADMIN solo de IT)=404/11003. El acceso al attachment IT era legítimo por rol.
- **Patrón:** un id secuencial/adivinable en la URL NO implica IDOR — hay que probar siempre el control de pertenencia con PoC cross-team (attachment en team donde el atacante NO es miembro). Un 200 cross-user dentro del MISMO team puede ser acceso legítimo por rol.
- **Gatillo:** antes de reportar IDOR por id secuencial, crear PoC en contexto donde el usuario atacante NO tenga acceso legítimo.

## [2026-08-17] Sesiones browser AtSpoke/Okta: tab_new pierde sesión; usar fetch en la misma pestaña
- **Contexto:** el daemon agent-browser comparte el perfil de cookies entre sesiones nombradas, pero abrir tab_new a otra URL pierde la sesión SPA (redirige a authorize Okta) y el wait_for_text da timeout con éxito real. La técnica fiable: navegar al SPA (inbox), confirmar sesión por botón de usuario (@), y hacer fetch relativo en la MISMA pestaña con credentials:include.
- **Patrón:** en AtSpoke, (1) login Okta requiere usuario → MFA Okta Verify (código usuario) → password (2 factores en orden); (2) nunca salir del SPA con tab_new para pruebas API — hacer fetch() desde la pestaña autenticada; (3) los POST requieren cookie XSRF-TOKEN + header X-XSRF-TOKEN.
- **Gatillo:** al testear API autenticada en AtSpoke, mantener la sesión en una sola pestaña y usar fetch relativo.

## [2026-08-19] /usr/bin/httpx NO es ProjectDiscovery httpx — usar prober curl en recon-triage
- **Contexto:** al implementar `recon-triage.sh`, F2 fallaba con "No such option: -l". El `/usr/bin/httpx` de este sistema es el cliente simple del paquete `python3-httpx` ("HTTPX 🦋 — next generation HTTP client", sin `-l`/`-status-code`/`-tech-detect`). No existe el httpx de ProjectDiscovery instalado.
- **Solución:** F2 usa un prober propio con `curl -sL -m 8 -r 0-200000 -D hdrs -o body -w '%{http_code}'` + extracción de título (`<title>`), header `Server`, CDN (cf-ray/akamai/cloudfront/via/x-cache) y keywords tech (react/wordpress/next.js/swagger/graphql...), en paralelo con `xargs -P 10`. Emite el mismo formato parseable `URL [status] [title] [server] [tech]` que el httpx de PD, sin dependencias nuevas. Si algún día se instala el httpx PD, se puede reemplazar.
- **Regla:** antes de asumir que una tool del stack (nuclei/nikto/subfinder/httpx) es la oficial, verificar `which` + `--help`; en este sistema httpx NO es el de ProjectDiscovery. Validar siempre el formato de output real con un smoke test local (python http.server) antes de confiar en el parser.
- **Gatillo:** cualquier script que invoque `httpx -l` o `-tech-detect`.

## [2026-08-19] pkill -f con patrón del propio comando mata su propio shell (trap de self-match)
- **Contexto:** en la sesión de recon-triage, `pkill -f recon-triage` y `pkill -f "http.server 899"` colgaron el shell del tool bash: el patrón coincide con la línea de comando del propio shell que invoca pkill (que contiene el string literal), así que se SIGTERM a sí mismo → la tool termina por timeout sin output.
- **Solución:** usar patrones que no coincidan con el propio comando (p.ej. `pkill -f 'recon-triage\.sh'` con la barra escapada) o matar por PID/`fuser -k <puerto>/tcp`, y verificar con un comando posterior simple (`echo alive`). Para limpieza de puertos concretos: `fuser -k 8997/tcp`.
- **Regla:** si un comando de limpieza termina por timeout sin output, sospechar self-match de pkill antes de reintentar; validar con `ps -eo pid,args | grep -v grep`.
- **Gatillo:** pkill -f con el nombre del script/herramienta que se está limpiando dentro de la propia invocación.

## [2026-08-19] Capturar status de curl sin duplicar fallos (000000) ni romper fallbacks
- **Contexto:** en el prober de recon-triage, `status="$(curl ... -w '%{http_code}' "$try" 2>/dev/null || echo 000)"` producía `000000`: curl en error imprime "000" vía -w Y ademas `|| echo 000` imprimía otro "000" concatenado. El check `[ "$status" = "000" ]` no detectaba "000000", se emitía una línea basura y se rompía el fallback https→http.
- **Solución:** `status="$(curl ... -w '%{http_code}' 2>/dev/null)"` + `[ -z "$status" ] && status="000"`. Y el fallback de esquema: solo reintentar con `http://` cuando el dominio entró sin esquema (`case "$url" in http://*|https://*) ;; *) line=$(do_probe "http://$url") ;; esac`) — nunca comparar `$try` contra cadenas derivadas del propio `$try`.
- **Regla:** jamás usar `|| echo` para llenar un valor que el comando ya puede emitir vía -w; normalizar con `[ -z ... ]`. Verificar el fallback con un smoke test real (server http plano) porque el bug solo aparece cuando el primer esquema falla.
- **Gatillo:** curl -w '%{http_code}' con `|| echo` fallback, o lógica de fallback de esquema con comparaciones derivadas de `$try`.

## [2026-08-19] nikto con -Format txt añade su propia extensión .txt al nombre -o
- **Contexto:** `nikto -o "$OUTDIR/nikto_$host.txt" -Format txt` generó `nikto_127.0.0.1.txt.txt`; el parser python (glob `nikto_*.txt` + basename[6:-4]) obtenía host `127.0.0.1.txt` que no matcheaba ninguna URL → hallazgos nikto siempre en 0.
- **Solución:** pasar `-o "$OUTDIR/nikto_$host"` sin extensión; nikto añade `.txt`. Verificado con artefacto real.
- **Regla:** validar el nombre real de artefactos generados por tools (nikto/ZAP/subfinder) con `ls` después del primer run antes de fiar el parser.
- **Gatillo:** nikto -o con extensión + -Format txt.

## [2026-08-19] Falsas alarmas del prober: "200" puede ser GitHub Pages auth / SSO / CF error / Shopify
- **Contexto:** recon-triage puntuó `*-eng-stats-dashboard.klaviyo-dev.com` con 75/65 (top candidatos), pero el deep-dive mostró que NO son dashboards expuestos: son **sitios GitHub Pages** que redirigen a `github.com/login?return_to=...pages%2Fauth...` (requieren login de GitHub). Otros casos reales de la misma sesión: `kiosk.klaviyo-dev.com` → Okta SSO, `argo-webhook-*.control.klaviyo-dev.com` → Cloudflare 530 error 1016 (origin muerto), `nathan.klaviyo-dev.com` → tienda Shopify tras password.
- **Solución:** el prober ahora sigue redirects (`%{url_effective}`) y marca `[locked:<tipo>]` (github-pages/cf-error/sso/shopify-password). Esos hosts se excluyen de live.txt (no van a nuclei/ZAP/nikto) y puntúan 5 fijo. Test de regresión con mocks (`tools/tests/test_false_alarms.sh`, 15 asserts, integrado en ecc-test.sh sección 13) + revalidación contra los casos reales de Klaviyo.
- **Regla:** un status 2xx en el prober NO implica app viva del target. Siempre capturar el `url_effective` final y verificar a qué dominio/plataforma redirige; los hosts tras login de terceros (GitHub Pages, Okta/AzureAD/Auth0, tiendas SaaS) no son superficie del bug bounty.
- **Gatillo:** cualquier host que redirija a un dominio de login de terceros o devuelva códigos de error de CDN (530/523/524, "error code: 10XX").
- 2026-08-19 | Cloudflare aggressive rate-limit en exchanges: desde IP datacenter, ~2-3 req → error 1015 con retry-after ESCALADO (305s→143s→3434s). Regla: en targets tras Cloudflare, probar 1 req cada 60s+, NUNCA nuclei/whatweb batch; esperar retry-after completo antes de reintentar o se prolonga el ban.

## PATRÓN 19: Búsqueda Exhaustiva de Patrones Antes de Parchear
**Fecha**: 2026-09-06
**Descripción**: Antes de corregir un bug o vulnerabilidad, hacer búsqueda exhaustiva (`grep -r`) de TODAS las instancias del patrón defectuoso en el código. No asumir que la instancia encontrada es la única. Un parche incompleto crea falsa sensación de seguridad y el bug reaparece por otra ruta.
**Ejemplo**: Una función con SQL injection se parchea en el endpoint `/api/users`, pero existe otro endpoint `/api/admin` que usa la misma función vulnerable. El atacante usa el segundo endpoint.
**Regla**: Antes de cerrar un fix → grep exhaustivo del patrón → parchear todas las instancias → test que cubra todas las rutas.
**Frecuencia**: Alta — ocurre cuando hay prisa por cerrar tickets.
**Categoría**: Patch management, code review, security.
