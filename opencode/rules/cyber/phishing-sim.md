# Phishing Simulation Policy

Regla para realizar **simulaciones de phishing (social engineering)** como parte de pruebas de seguridad autorizadas (campañas de concienciación, red team, testing de phishing simulaciones). **Siempre con autorización y consentimiento.**

## 1. Requisitos Previos (obligatorios)

1. Target/infraestructura registrada en `scope.json` con tipo `phishing` (`authorize.sh add <target> phishing <duración>`).
2. Autorización explícita del usuario (ver `__OPENCODE_ROOT__/rules/cyber/authorization.md`).
3. Consentimiento informado de los receptores O campaña corporativa aprobada (seguridad de la empresa).
4. Uso de plataforma de simulación **propia** (GoPhish, SET en modo lab) — no reenviar a servicios de terceros.

## 2. Herramientas Permitidas

| Herramienta | Uso |
|---|---|
| `GoPhish` | Campañas controladas con tracking (aperturas, clics) |
| `SET (Social Engineering Toolkit)` | Vectores de phishing en lab autorizado |
| `swaks` | Envío de emails de prueba (SMTP propio) |
| Plantillas propias | Clonado de páginas SOLO para sitios autorizados en scope |

## 3. PROHIBIDO

- NUNCA dirigirse a personas sin consentimiento previo.
- NUNCA usar dominio/servidor de terceros.
- NUNCA exfiltrar credenciales reales de usuarios fuera del lab.
- NUNCA suplantar bancos, gobierno u organizaciones sin autorización por escrito para la simulación.

## 4. Procedimiento

1. Verificar scope (`check-scope.sh <target> phishing`).
2. Confirmar con el usuario la campaña: destinatarios, tipo (awareness), plataforma.
3. Ejecutar `audit-log.sh "<plataforma> phishing <target>"`.
4. Configurar campaña con plantillas seguras (sin daño).
5. Ejecutar la simulación y recopilar métricas agregadas (tasa de clics), sin datos personales fuera del informe.

## 5. Post-campaña

- Informe de concienciación (resultados agregados, unidades de formación recomendadas).
- Borrado de datos de campaña y archivos temporales (ver `__OPENCODE_ROOT__/rules/cyber/cleanup.md`).