# Definición de Alcance — {{proyecto}}

> Plantilla parametrizable. Copiar a `__HOME__/BugBounty/{{proyecto}}/scope.md` y completarla **antes de cualquier acción ofensiva**.
> La fuente técnica de verdad sigue siendo `__OPENCODE_ROOT__/cyber/projects/{{proyecto}}/scope.json` (`authorize.sh`).

## 1. Programa

| Campo | Valor |
|---|---|
| Nombre del programa | {{nombre_programa}} |
| Plataforma | {{hackerone|bugcrowd|intigriti|otro}} |
| URL del programa | {{url_programa}} |
| Política de recompensas | {{url_rewards}} |
| Proyecto local | `__HOME__/BugBounty/{{proyecto}}/` |

## 2. Dominios In-Scope

| Target | Tipo de test | Notas |
|---|---|---|
| {{ejemplo.com}} | {{recon/scan/enumerate/exploit/post-exploit/dos/phishing}} | {{nota}} |
| `*.{{ejemplo.com}}` | {{tipo}} | wildcard: subdominios |

## 3. Dominios Out-of-Scope

| Target | Motivo |
|---|---|
| {{ayuda.ejemplo.com}} | {{soporte de terceros}} |
| {{*.ejemplo.io}} | {{activo no propiedad del programa}} |
| Cuentas de terceros / usuarios reales | {{solo cuentas propias de prueba}} |

## 4. Tipos de Test Permitidos

- [ ] Recon (pasivo)
- [ ] Recon (activo / escaneo de puertos)
- [ ] Enumeración de directorios y subdominios
- [ ] Explotación (validación de PoC)
- [ ] Post-explotación / movimiento lateral
- [ ] DoS / stress test (**solo lab propio**, ver el skill `dos-testing`)
- [ ] Phishing / simulación (**solo con consentimiento explícito**, ver el skill `phishing-sim`)

## 5. Ventanas Horarias y Límites

| Restricción | Valor |
|---|---|
| Horario permitido | {{ej. L-V 09:00-18:00 TZ}} |
| Rate limit máximo | {{peticiones/segundo}} |
| Duración máxima por prueba | {{duración}} |
| Ventana de autorización registrada | {{desde}} → {{hasta}} (`until` en scope.json) |

## 6. Reglas de Engagement

1. Gate obligatorio antes de cada acción: `scope-validate.sh <target>` → debe devolver `[IN SCOPE]`.
2. Toda acción ofensiva se registra: `audit-log.sh "<tool> <target> <tipo>"`.
3. Prohibido: daño permanente, exfiltración real, denegación de servicio no autorizada, acceso a datos de terceros.
4. Hallazgo sensible → detener, reportar al {{contacto}} antes de profundizar.
5. Evidencias sanitizadas; secretos capturados solo en `creds.env` (chmod 600) y se eliminan en cleanup.
6. Escritura de filesystem solo en `__HOME__/BugBounty/{{proyecto}}/` y `__OPENCODE_ROOT__/` (ver `rules/cyber/agent-write-permissions.md`).

## 7. Contacto

| Rol | Contacto | Canal |
|---|---|---|
| Programa / manager | {{nombre}} | {{email_url_slack}} |
| Responsable técnico | {{nombre}} | {{canal}} |
| Punto de escalamiento | {{nombre}} | {{canal}} |

## 8. Historia de Autorización

| Fecha | Evento | Responsable | Evidencia |
|---|---|---|---|
| {{YYYY-MM-DD}} | SoW / consentimiento firmado o política aceptada | {{quien}} | {{url_pdf}} |
| {{YYYY-MM-DD}} | Scope creado (`authorize.sh init {{url}}`) | {{agente}} | scope.json |
| {{YYYY-MM-DD}} | Targets añadidos (`authorize.sh add ...`) | {{agente}} | audit.log |
| {{YYYY-MM-DD}} | Alcance revisado y confirmado por el usuario | {{usuario}} | transcript de sesión |

**Fecha de autorización:** {{fecha_autorizacion}} · **Vigencia:** {{vigencia}}
