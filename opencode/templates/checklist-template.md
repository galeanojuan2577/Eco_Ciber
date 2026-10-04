# Checklist de Fases — {{proyecto}}

> Plantilla parametrizable. Copiar a `__HOME__/BugBounty/{{proyecto}}/checklist.md` y marcar cada casilla con `[x]` a medida que avanza.
> Gate global: NO pasar de fase sin `[IN SCOPE]` en `scope-validate.sh <target>` y traza en `audit.log`.

## 0. Autorización (previa a todo)

- [ ] Proyecto activo confirmado: `project-context.sh get` → `{{proyecto}}`
- [ ] `scope.json` creado/reviado: `authorize.sh status`
- [ ] Consentimiento explícito del usuario registrado (SoW / política del programa)
- [ ] Alcance volcado en `__HOME__/BugBounty/{{proyecto}}/scope.md`
- [ ] `SESSION-STATE.md` inicializado (ver `session-state-template.md`)

## 1. Recon

- [ ] Pasivo: DNS, WHOIS, certificados, OSINT, subdominios → `recon/01_pasivo/`
- [ ] Activo: nmap, cabecera TLS/SSL → `recon/02_activo/`
- [ ] Salidas agregadas y deduplicadas: `recon-triage.sh recon` → `triage/`
- [ ] Hosts/URLs ordenados por severidad (si hay resultados de nuclei)
- [ ] Estado guardado en `SESSION-STATE.md` (target actual + hallazgos abiertos)

## 2. Scan

- [ ] Gate de alcance por cada target nuevo: `scope-validate.sh <target>`
- [ ] nuclei / nikto / nmap --script=vuln / testssl → `testing/`
- [ ] Auditoría registrada: `audit-log.sh "<tool> <target> scan"`
- [ ] Timeouts aplicados (`timeout N`) y exit codes capturados
- [ ] Falsos positivos descartados y recuentos por severidad anotados

## 3. Enumerate

- [ ] Directorios/rutas: gobuster, ffuf, wfuzz → `testing/`
- [ ] Subdominios y parámetros completados
- [ ] Enumeración autenticada solo con cuentas propias de prueba
- [ ] Resultados limpios guardados (ficheros de `triage/` actualizados)

## 4. Exploit

- [ ] Reconfirmar alcance del target exacto (`scope-validate.sh`)
- [ ] PoC mínimo, no destructivo, con evidencia en `evidence/{{H-XXX}}/`
- [ ] Acción auditada: `audit-log.sh "<tool> <target> exploit"`
- [ ] Confirmación del usuario antes de cualquier técnica de alto impacto
- [ ] Output capturado a fichero (sin stdin heredado, con timeout)

## 5. Post-Exploit

- [ ] Movimiento lateral / escalada solo dentro del alcance autorizado
- [ ] Sin persistencia real en sistemas de terceros (lab propio únicamente)
- [ ] Evidencia recogida y sanitizada (sin datos personales reales)
- [ ] Credenciales halladas → `creds.env` (chmod 600), nunca en claro en el estado

## 6. Report

- [ ] Informe generado desde `__OPENCODE_ROOT__/templates/report-template.md` → `reports/`
- [ ] Cada hallazgo con severidad, PoC paso a paso, impacto y remediación
- [ ] Historia de autorización completada (scope + audit.log)
- [ ] Revisión cruzada con `red-team-lead` / `pentest-report-agent`
- [ ] Resumen de alta entregado (`onboarding-summary-template.md`)

## 7. Cierre

- [ ] Cleanup ejecutado (`cleanup.sh {{proyecto}}`) y artefactos residuales borrados
- [ ] `SESSION-STATE.md` actualizado con estado FINAL
- [ ] Audit log cerrado con nota "engagement finalizado + cleanup OK"
- [ ] Scope archivado: `authorize.sh archive {{proyecto}}`
