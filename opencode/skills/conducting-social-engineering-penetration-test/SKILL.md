---
name: conducting-social-engineering-penetration-test
description: Ejecuta un pentest de ingeniería social autorizado (phishing con GoPhish, vishing
  con guion, pretexting y vectores físicos) con gate de autorización tipo phishing obligatorio,
  OSINT con theHarvester/subfinder/recon-ng, métricas agregadas de riesgo humano, límites
  éticos estrictos (nunca phishing real sin autorización escrita) e informe de concienciación.
  Use en engagements de red team cuando se necesite medir la susceptibilidad humana.
domain: cybersecurity
subdomain: red-teaming
tags:
- social-engineering
- phishing-simulation
- vishing
- pretexting
- security-awareness
- red-team
- gophish
- osint
version: '1.0'
author: mahipal
license: Apache-2.0
nist_csf:
- ID.RA-01
- GV.OV-02
- DE.AE-07
- PR.AT-01
mitre_attack:
- T1566
- T1566.001
- T1566.002
- T1598.001
- T1598.004
- T1204.002
---

# Conducting Social Engineering Penetration Test

> **Aviso legal:** Este skill es solo para pruebas de seguridad autorizadas y fines
> educativos. **Nunca** se ejecuta phishing, vishing ni pretexting real sin autorización
> escrita y consentimiento de los receptores; suplantar a bancos o administraciones sin
> permiso es delito.

## Descripción general

El pentest de ingeniería social mide el eslabón humano de la cadena de ataque: ¿un empleado
abre el correo, entrega credenciales, acepta una llamada de "soporte" o cede un badge? Se
estructura en OSINT (theHarvester, subfinder, recon-ng), construcción de pretextos,
infraestructura de simulación propia (GoPhish, SET), ejecución por ondas y medición de
métricas agregadas. A diferencia de una campaña genérica de concienciación, aquí cada
vector se diseña contra objetivos concretos del alcance, con evidencia trazable.

## Cuándo usarlo

- Fase de acceso inicial del flujo `pentest-flow-detail` (fase 8: phishing sim) en red team.
- Medición de la tasa real de clic/entrega de credenciales antes de un programa de awareness.
- Validación de controles de correo (SPF/DKIM/DMARC, sandbox, bloqueo de adjuntos).
- Simulación combinada correo + vishing + pretexto físico sobre la misma campaña.

## Prerrequisitos

- **Autorización escrita**: alcance con lista de destinatarios aprobada por RRHH/dirección,
  ventana, canales permitidos y contacto de emergencia (ver el skill `phishing-sim`).
- Proyecto activo con target registrado con tipo `phishing`
  (`authorize.sh add <target> phishing <duración>`).
- Infraestructura propia: `gophish` y `setoolkit` instalados, dominio propio en scope,
  SMTP propio o proveedor aprobado con SPF/DKIM/DMARC correctos.
- Listas de destinatarios autorizadas y mecanismo de exclusión (opt-out) inmediato.

## Gate de autorización (obligatorio)

**Antes de CUALQUIER acción activa** (envío de correo, llamada, crawl del sitio a clonar,
prueba de credenciales), ejecuta:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> phishing
bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> phishing"
```

Regla inflexible:

- **`exit 0`** → target en scope: procede y registra cada acción con `audit-log.sh`.
- **`exit 1`** → target **NO** en scope: **pregunta al usuario** y **no continúes sin
  confirmación explícita**. Sin confirmación escrita **no hay envío, ni llamada, ni clonado**.

Tipos usados: `phishing` (campañas, vishing, pretextos) y `recon` (OSINT previo, que sigue
requiriendo registro).

## Flujo por fases

### Fase 1 — Alcance, consentimiento y métricas base

```bash
bash __OPENCODE_ROOT__/tools/project-context.sh
bash __OPENCODE_ROOT__/tools/authorize.sh status
mkdir -p __HOME__/BugBounty/<proyecto>/{recon,testing,evidence,reports}
bash __OPENCODE_ROOT__/tools/audit-log.sh "phishing-campaign inicio <target> phishing"
```

Fija: destinatarios (lista cerrada), canales (correo/vishing/físico), ventana, umbrales de
riesgo (p.ej. parar si >30% de clics), plantillas prohibidas y quién puede abortar.

### Fase 2 — OSINT de los objetivos (solo dentro del alcance)

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh target.com recon

theHarvester -d target.com -b all -l 500 -f __HOME__/BugBounty/<proyecto>/recon/harvest
subfinder -d target.com -o __HOME__/BugBounty/<proyecto>/recon/subs.txt
dnsrecon -d target.com -j __HOME__/BugBounty/<proyecto>/recon/dns.json
recon-ng -w target_osint   # módulos: importar listado autorizado, no descubrir empleados ajenos
whois target.com | grep -Ei 'registrant|org'
```

Patrón de direcciones de correo (para el pretexto): infiere de dominios y nombres públicos ya
incluidos en la lista aprobada; **no** recolectes datos de personas fuera del alcance.

### Fase 3 — Pretextos e infraestructura de simulación

```bash
# Dominio look-alike propio (registrado por ti, en scope) + SPF/DKIM/DMARC verificados
dig target.com TXT +short | grep -i dmarc
# Páginas de destino: SOLO clonar sitios que estén en scope
whatweb https://target.com        # replicar branding/tecnología observada
# Servidor de campaña propio
gophish                                                   # interfaz en https://localhost:3333
setoolkit                                                  # vector Social-Engineering en lab autorizado
```

Pretextos habituales (elige según el rol): aviso de IT con MFA obligatoria, RRHH con
beneficio pendiente, proveedor con factura vencida, directivo con "urgencia" (CEO fraud),
llamada de "mesa de ayuda" verificando VPN.

### Fase 4 — Ejecución controlada por ondas

```bash
# 1) Test interno: envía a la lista de prueba y verifica entrega/renderizado
# 2) Onda piloto (5-10% de destinatarios) → revisar métricas y falsos positivos
# 3) Onda principal respetando rate (nunca envío masivo de golpe)
# GoPhish: Campaign → Email template (tracking: Open/Clicked/Submitted data) + Landing page
# Vishing: guion aprobado, llamadas grabadas SOLO con consentimiento, números propios
```

Reglas de ejecución:

- Activa el **opt-out** y la exclusión inmediata de quien llame al "botón de pánico".
- No ataques reales al seguir el clic: la landing solo registra el evento; si hay payload,
  debe ser inocuo (fichero de prueba sin ejecución destructiva).
- Si el SOC reporta la campaña, no la niegues: confirma al equipo de respuesta.

### Fase 5 — Métricas, análisis y formación

```bash
# Exporta resultados de GoPhish (CSV/API) y consolida métricas agregadas
# tasa_entrega, tasa_apertura, tasa_clic, tasa_envío_credenciales, tasa_reporte_al_SOC
```

- Segmenta por departamento/rol (no por persona en el informe general).
- Compara con la línea base y con la campaña anterior.
- Identifica qué control falló: filtro de correo, sandbox, DLP, verificación en origen.

## Tabla de herramientas

| Herramienta | Fase | Uso |
|---|---|---|
| `theHarvester` | OSINT | Emails, subdominios y huella pública del alcance |
| `subfinder` / `dnsrecon` | OSINT | Subdominios y registros para pretextos creíbles |
| `recon-ng` | OSINT | Framework de recolección modular |
| `whatweb` | Pretext | Fingerprinting para replicar branding (solo en scope) |
| `gophish` | Ejecución | Campañas con tracking (aperturas, clics, envíos) y exclusiones |
| `setoolkit` | Ejecución | Vectores de ingeniería social en lab autorizado |
| `tcpdump` / `wireshark` | Validación | Comprobar que la landing solo registra, sin callback malicioso |
| `jq` / `awk` | Métricas | Consolidación de resultados agregados |

## Interpretación de resultados

- **Clic ≠ compromiso**: separa apertura, clic, envío de credenciales y ejecución de payload;
  cada uno tiene severidad distinta (T1566 vs T1204.002).
- **Tasa de reporte al SOC** es la métrica más valiosa: alto reporte + bajo clic = controles
  humanos funcionando.
- **Falsos positivos**: escáner de correo que "abre" los links (prefetch), filtros que
  descargan adjuntos, usuarios que avisan tarde. Cruza con logs del gateway.
- **Filtrado por onda**: caída brusca de entrega tras la onda piloto = el filtro aprendió;
  reporta la evasión inicial y la detección posterior por separado.
- **Riesgo por rol**: un 10% de clic en finanzas con payload de credenciales tiene más
  impacto que 40% de clic en un boletín informativo.
- **Valida cada hallazgo** antes de reportarlo (reproduce el clic con la URL y revisa el
  evento en GoPhish) para evitar falsos positivos en el informe.

## Límites legales y éticos

- **Solo targets en scope** verificados con `check-scope.sh`; fuera de scope → parar y preguntar.
- **Prohibido el phishing real sin autorización escrita**: sin SoW/RoE firmado y lista de
  destinatarios aprobada, no se envía nada (ni siquiera "una prueba a un amigo").
- **Sin DoS ni saturación**: envíos por ondas con rate limitado; sin flood de SMTP ni llamadas
  masivas.
- **Sin suplantación prohibida**: bancos, administraciones o servicios públicos solo con
  permiso expreso; sin amenazas, chantaje ni presión real sobre los empleados.
- **Datos**: no almacenes credenciales reales de usuarios (configura GoPhish para no persistir
  `submitted_data` con valores, o bórralas tras registrar el evento); no compartas la lista de
  destinatarios fuera del proyecto.
- **Consentimiento**: opt-out efectivo, canal de queja a RRHH, y aborto inmediato si alguien
  sufre consecuencias reales (pago, despido, pánico).
- **Trazabilidad**: cada acción registrada con `audit-log.sh`; al terminar, cleanup de
  infraestructura (`__OPENCODE_ROOT__/rules/cyber/cleanup.md`).

## Entregable / Informe

Ruta: `__HOME__/BugBounty/<proyecto>/reports/<fecha>_<target>_social-engineering-report.md`:

1. **Resumen ejecutivo** — alcance autorizado, ventanas, riesgo humano global.
2. **Métricas agregadas** — entrega/apertura/clic/credenciales/reportes por onda y segmento.
3. **Vectores utilizados** — pretextos, plantillas, canales; qué control los detuvo.
4. **Hallazgos** — bypass del gateway, falta de MFA en el landing, roles críticos afectados,
   con evidencia (capturas, eventos GoPhish) y mapeo ATT&CK.
5. **Recomendaciones** — formación dirigida, simulación periódica, cambios técnicos
   (DMARC `p=reject`, bloqueo de macros, MFA resistente a phishing).
6. **Cumplimiento** — gate `check-scope` ejecutado, entradas de `audit.log`, confirmación de
   cleanup y de borrado de datos de destinatarios.

## Referencias

- GoPhish: https://getgophish.com/
- Social-Engineer Toolkit (SET): https://github.com/trustedsec/social-engineer-toolkit
- OWASP Cheat Sheet — Phishing: https://cheatsheetseries.owasp.org/
- NIST SP 800-50 — Building an IT Security Awareness Program: https://csrc.nist.gov/publications/detail/sp/800-50/final
- MITRE ATT&CK — Phishing (T1566): https://attack.mitre.org/techniques/T1566/
