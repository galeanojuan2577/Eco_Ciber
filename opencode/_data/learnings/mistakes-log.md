# Mistakes Log

## [2026-08-14] Asumir estabilidad de la superficie QA sin re-verificación
- **Contexto:** bug bounty Chime. Clasifiqué H1 (falta de rate limit en `register_device`) como hallazgo válido basándome en pruebas de días previos, sin re-verificar el endpoint en la sesión actual.
- **Causa raíz:** no re-testear la superficie antes de clasificar/ranquear hallazgos. El QA (`app-qa.chime.com`) fue endurecido entre sesiones: el root `MutationsEnrollmentUnauthenticatedMutationRoot` quedó vacío y `register_device` ya no existe → H1 quedó INVALIDADO.
- **Fix:** antes de clasificar o reportar CUALQUIER hallazgo, re-ejecutar el PoC en la sesión actual (≥3 veces para consistencia). Si el endpoint ya no responde igual, el hallazgo muere.
- **Gatillo:** "clasificar", "ranquear", "reportar", "payout" sin re-testear primero.

## [2026-08-14] Asumir que el WAF/stack del target no cambia entre sesiones
- **Contexto:** `api.chimebank.com` daba 403 openresty; en la re-verificación dio 403 **Cloudflare** (server header). Los host header de bloqueo cambiaron de stack.
- **Causa raíz:** documentar el "cómo está bloqueado" sin verificar en vivo que sigue igual.
- **Fix:** al verificar replicabilidad, capturar SIEMPRE el header `Server` (y `www-authenticate`, `cf-ray` si aplica) para distinguir stack de bloqueo y detectar cambios.
- **Gatillo:** re-verificación de accesibilidad de un target con 403/429.

## [2026-08-14] Sobrevalorar vectores no accesibles al calcular payout esperado
- **Contexto:** ranqueé 6 vectores con EV alto (IDOR API ~$4.5k) sin verificar primero si eran alcanzables desde la infraestructura disponible (IP de datacenter).
- **Causa raíz:** calcular EV = payout × prob. de aceptación, ignorando que el vector requiere acceso (IP residencial/móvil real) que no tengo.
- **Fix:** el EV debe multiplicarse también por P(acceso disponible). Un vector inaccesible tiene EV 0 hoy, sin importar su payout potencial. Reportar solo lo verificado y accesible.
- **Gatillo:** cálculo de payout esperado antes de validar accesibilidad del target.

## [2026-08-19] Recomendar deep-dive de Klaviyo por scores inflados con falsas alarmas
- **Contexto:** tras el hunting scan, recomendé "Deep-dive Klaviyo" porque `*-eng-stats-dashboard.klaviyo-dev.com` puntuaron 75/65 — la señal más alta. El deep-dive mostró que NO son dashboards expuestos: son sitios **GitHub Pages** que redirigen a `github.com/login` (el prober seguía el redirect y contaba el 200 de la página de login de GitHub como app viva del target).
- **Causa raíz:** el prober no capturaba el `url_effective` final tras `curl -L`; un 2xx tras redirect a un login de terceros (GitHub/Okta) puntuaba como target real.
- **Fix:** el prober ahora detecta y marca `[locked:github-pages|cf-error|sso|shopify-password]`; esos hosts se excluyen de live.txt y puntúan 5. Test de regresión 15/15 (mocks) integrado en ecc-test.sh; revalidado contra los casos reales de Klaviyo (6/6 bloqueados). Antes de recomendar un programa por scan, verificar a dónde redirigen realmente sus hosts top.
- **Gatillo:** recomendación de programa/bounty basada solo en score de scan pasivo sin validar el destino de los redirects.

## Mistake 6: Patch Incompleto — Arreglar Solo la Instancia Inmediata
**Fecha**: 2026-09-06
**Causa raíz**: Al corregir un bug en una función, solo se parcheó la llamada directa sin verificar todas las demás instancias del mismo patrón en el código. El bug reapareció en producción por una ruta de código diferente que usaba la misma función defectuosa.
**Trigger**: Urgencia por cerrar un ticket rápido, sin hacer grep exhaustivo del patrón defectuoso.
**Fix aplicado**: 
1. Siempre hacer `grep -r "nombre_funcion" .` antes de declarar un bug "arreglado"
2. Verificar que TODOS los callers de la función parcheada son compatibles con el nuevo comportamiento
3. Agregar test que cubra TODAS las rutas de código que usan la función
**Regla permanente**: Arreglar un bug = arreglar TODAS sus instancias. Nunca parchear solo la más visible.
