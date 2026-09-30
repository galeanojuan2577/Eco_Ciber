# DoS Stress Testing Policy

Regla para realizar **pruebas de estrés de Denegación de Servicio (DoS)** dentro del Ecosistema de Ciberseguridad. Permite técnicas de validación de resistencia ante DoS **siempre con autorización**.

## 1. Requisitos Previos (obligatorios)

1. Target registrado en `scope.json` con tipo `dos` (`authorize.sh add <target> dos <duración>`).
2. Autorización explícita del usuario (ver `__OPENCODE_ROOT__/rules/cyber/authorization.md`).
3. Confirmación de que el target es infraestructura **propia / laboratorio / contratada**.

## 2. Herramientas Permitidas (con límites)

| Herramienta | Uso | Límites recomendados |
|---|---|---|
| `hping3` | Flooding controlado | `--count` acotado, duración corta, rate limitado |
| `nmap` (scripts dos) | Validación de vulnerabilidades DoS conocidas | Solo en lab |
| `mdk3` / `aireplay-ng` | DoS wireless (client deauth) | Solo en AP propios/lab |
| `tor hammer`, `LOIC/HLIC` | Stress test HTTP | Solo infraestructura propia |

**Parámetros de seguridad:**
- Duraciones cortas (típicamente < 60s por prueba).
- Pausas entre pruebas para permitir recuperación.
- Monitoreo de impacto y registro de resultados.

## 3. PROHIBIDO

- NUNCA contra terceros sin contrato/SoW firmado.
- NUNCA sin autorización explícita.
- NUNCA daño permanente o destrucción de infraestructura.
- NUNCA continuar si el objetivo reporta degradación de servicios a terceros no autorizados.

## 4. Procedimiento

1. Verificar scope (`check-scope.sh <target> dos`).
2. Confirmar con el usuario el alcance y duración.
3. Ejecutar `audit-log.sh "hping3 ... <target>"`.
4. Ejecutar la prueba con límites.
5. Registrar resultados/impacto y esperar pausa de recuperación antes de repetir.

## 5. Post-prueba

- Reportar en el informe final los resultados (nivel de resistencia estimado).
- Confirmar recuperación total del servicio tras la prueba.
- Limpiar herramientas/procesos residuales (ver `__OPENCODE_ROOT__/rules/cyber/cleanup.md`).