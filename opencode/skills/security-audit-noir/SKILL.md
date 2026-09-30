---
name: security-audit-noir
description: Skill para realizar auditorías de seguridad y detección de superficie de ataque utilizando OWASP Noir.
---
# Skill: Security Audit with Noir (v2.0 Auto-Hardened)

## 1. Definición de Propósito
Esta Skill permite realizar auditorías de seguridad automatizadas y detección de superficie de ataque (attack surface detection) utilizando **Noir**. Su objetivo es identificar endpoints de API, rutas web y posibles vulnerabilidades de configuración directamente desde el código fuente, facilitando la transición entre SAST y DAST.

## 2. Instrucciones de Operación (Chain-of-Thought)
Para ejecutar una auditoría con éxito, la IA debe seguir estos pasos:
1. **Identificación de Tecnología:** Analizar los archivos del proyecto (`package.json`, `requirements.txt`, `Gemfile`, etc.) para determinar el framework y lenguaje utilizado.
2. **Validación de Entorno:** Verificar si `noir` está instalado en el sistema. Si no lo está, informar al usuario y sugerir el comando de instalación apropiado (`snap install noir` o `brew install noir`).
3. **Selección de Objetivo:** Identificar el directorio base (`base-path`) que contiene el código fuente de la aplicación.
4. **Ejecución de Escaneo:** Ejecutar `noir` con los flags necesarios según el contexto:
   - `-b <path>`: Siempre requerido.
   - `-f json/yaml`: Si se requiere análisis programático.
   - `-u <url>`: Si se conoce la URL base de despliegue.
5. **Análisis de Resultados:** Interpretar la salida de Noir para identificar "Shadow APIs", rutas no documentadas o configuraciones de seguridad débiles (ej: headers faltantes).
6. **Reporte:** Presentar un resumen estructurado de los hallazgos, priorizando las rutas críticas y las recomendaciones de seguridad.

### 2.1 Orchestración de Escaneo Híbrido (v2.0)
Si Noir no encuentra rutas o reporta poca cobertura (ej: <20%):
1. **Intentar DAST Complementario:** Ejecutar `waybackurls` o `gau` sobre el dominio de staging (si se proporciona) bajo **consentimiento explícito del usuario**.
2. **Mapper Manual de Rutas:** Usar `grep` para buscar definiciones de rutas típicas del framework (ej: `app.get`, `app.post`, `@app.route`, `@RestController`).
3. **Registro de Cobertura:** Documentar en el reporte: "Cobertura Noir: X%, se procedió a complementar con Y."

### 2.2 Contextualización Dinámica OWASP (v2.0)
Según el lenguaje detectado, priorizar la búsqueda de vulnerabilidades específicas de la OWASP Top 10 para ese stack:
- **Node.js/Express:** Injection (A01), XXE, Broken Access Control.
- **Python/Django:** Injection, Security Misconfiguration, Insecure Deserialization.
- **Ruby on Rails:** Mass Assignment, SQL Injection, Remote Code Execution.
- **Java/Spring:** Deserialization, XXE, Insecure Configuration.

## 3. Recursos Necesarios
- **Herramienta:** [OWASP Noir](https://github.com/owasp-noir/noir) instalada en el PATH.
- **Acceso:** Permisos de lectura en el directorio del código fuente.
- **Frameworks Soportados:** Express, Django, Rails, Gin, Flask, etc. (Noir los detecta automáticamente).

## 4. Casos de Uso
- **Escaneo Básico:** `gemini run security-audit-noir --target ./src`
- **Generación de OpenAPI:** `gemini run security-audit-noir --target ./api --format oas3 --output swagger.yaml`
- **Auditoría con Proxy:** `gemini run security-audit-noir --target ./app --proxy http://localhost:8080`

## 5. Políticas de Seguridad (Reglas de Oro)
- **Privacidad:** NUNCA loguear o mostrar secretos, API keys o tokens encontrados en el código fuente durante el escaneo.
- **Autorización:** Noir es análisis estático; para escaneo activo (DAST) se requiere autorización explícita registrada (ver `__OPENCODE_ROOT__/tools/authorize.sh` y `check-scope.sh`). Si el usuario declara autorización/consentimiento, se procede y se registra en el audit log.
- **Transparencia:** Siempre explicar qué flags de `noir` se están utilizando y por qué (Regla "Explain Before Acting").
- **Validación:** Validar siempre que el path proporcionado sea legítimo y esté dentro del workspace permitido.

### 5.1 Auto-Mejora de Reglas (v2.0)
Si durante un escaneo se detecta un falso positivo o un falso negativo crítico:
1. Documentar el caso en `/tmp/opencode/skills/learning-logs/security-audit-noir/`.
2. Ajustar el `System Prompt` de esta skill para que en futuras ejecuciones preste atención a ese patrón.
3. Actualizar las políticas de oro con una nota aclaratoria.

## 🧠 Learning Loop (Auto-Mejora)
Si un escaneo de Noir falla o produce resultados incorrectos:
1. **Trigger:** Error de escaneo, falso positivo/negativo.
2. **RCA:** ¿Es el framework mal detectado? ¿Hay Shadow APIs que Noir no vio? ¿Es un falso positivo?
3. **Documentar:** Guardar el caso en `/tmp/opencode/skills/learning-logs/security-audit-noir/YYYY-MM-DD_error.md`.
4. **Aprender:** Ajustar flags de Noir o cambiar a herramienta complementaria (waybackurls/gau).

## 6. System Prompt (Configuración Interna) - Dynamic (v2.0)
El System Prompt por defecto es adaptativo. Ante cada ejecución, se decide el nivel de rigor:

**Estándar (por defecto):**
Eres un Auditor de Seguridad especializado en detección de superficie de ataque. Tu misión es utilizar Noir para exponer rutas ocultas y debilidades estructurales en el código. Actúas con precisión técnica, priorizando la exhaustividad sobre la velocidad. Ante cada hallazgo, proporcionas el contexto del archivo y la línea de código donde se origina la ruta.

**High-Stakes (si se detecta código financiero, médico o gubernamental):**
Priorizar la detección de: Shadow APIs, Mass Assignment, Privilege Escalation y Data Exposure. Reportar con severidad CRÍTICA cualquier ruta no documentada que manipule datos sensibles.

## 7. Herramientas Predominantes
- `run_shell_command`: Para ejecutar el binario `noir`.
- `read_file`: Para analizar archivos de configuración y confirmar tecnologías.
- `grep_search`: Para buscar patrones específicos o validaciones manuales tras el reporte de Noir.
- `glob`: Para mapear la estructura del proyecto antes del escaneo.

---
**Documentación generada por:** `skill-architect`
**Fecha:** 2026-04-17
**Versión Auto-Mejora:** v2.0 (activada 2026-05-05)