---
name: cyber-offensive
description: Metodología completa de pentesting y hacking ético (recon → scan → enumeración → explotación → post-explotación → DoS testing → phishing sim → reporting). ALWAYS requires explicit authorization (autorización + consentimiento del usuario). Mapea las herramientas reales de Kali Linux.
---

# Skill: Cyber Offensive — Metodología de Pentesting Ético

## 0. REGLA CRÍTICA: Autorización obligatoria
**Antes de TODA acción ofensiva activa:**
1. Verificar el target contra el alcance autorizado:
   ```bash
   bash __OPENCODE_ROOT__/tools/check-scope.sh "<target>" "<tipo>"
   ```
2. Si el target NO está en `scope.json`, el gate es **FLEXIBLE**: **pregunta al usuario** si la acción es legal y con consentimiento. Si el usuario confirma, procede con `--force` (queda registrado en audit log).
3. Registrar cada herramienta ejecutada:
   ```bash
   bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <fase>"
   ```

## 1. Fases del Pentest (PTES / OWASP)

### Fase 1 — Reconocimiento (OSINT + pasivo)
| Herramienta | Uso |
|---|---|
| `nmap -sV -sC <target>` | Detección de servicios y versiones |
| `nmap -p- <target>` | Escaneo de todos los puertos |
| `theHarvester -d <dominio> -b all` | Recolección de emails/subdominios |
| `recon-ng` | Framework OSINT |
| `dnsrecon -d <dominio>` | Enumeración DNS |
| `whatweb <url>` | Fingerprinting de tecnologías web |
| `enum4linux <ip>` | Enumeración SMB/Windows (si abre 139/445) |
| `crt.sh` / `amass enum` | Certificados/subdominios |

*Regla: guardar resultados en `reports/recon_<target>.txt`.*

### Fase 2 — Escaneo de vulnerabilidades
| Herramienta | Uso |
|---|---|
| `nmap --script=vuln <target>` | Scripts NSE de vulnerabilidades |
| `nuclei -u <url> -severity critical,high` | Templates de vulnerabilidades web |
| `nikto -h <url>` | Escáner de servidores web |
| `searchsploit <servicio> <versión>` | Buscar exploits para versiones |
| `testssl.sh <url>` | Auditoría SSL/TLS |

### Fase 3 — Enumeración profunda
| Herramienta | Uso |
|---|---|
| `gobuster dir -u <url> -w /usr/share/wordlists/dirb/common.txt` | Directorios |
| `ffuf -u <url>/FUZZ -w <wordlist>` | Fuzzing de contenido |
| `wfuzz` | Fuzzing de parámetros |
| `enum4linux -a <ip>` | Enumeración completa SMB |
| `sqlmap -u "<url>?id=1" --batch --risk=3 --level=5` | Detección de inyección SQL |

### Fase 4 — Explotación
| Herramienta | Uso |
|---|---|
| `searchsploit` + `msfconsole` | Metasploit (exploit/multi/handler, etc.) |
| `hydra -L users.txt -P /usr/share/wordlists/rockyou.txt <proto>://<target>` | Brute force de credenciales |
| `medusa` | Brute force alternativo |
| `responder -I eth0` | Captura de hashes (SMB/NTLM) en red local |
| `john <hashfile>` / `hashcat -m <mode> <hash>` | Cracking de hashes (rockyou descomprimido) |
| `crackmapexec` | Validación de credenciales SMB/winrm |

### Fase 5 — Post-explotación (solo lab/red team autorizado)
- Persistencia, movimiento lateral, escalada de privilegios en el lab propio.
- `meterpreter` sesiones, `mimikatz`, extracción de credenciales del lab.
- Documentar vías de compromiso (solo en entorno autorizado).

### Fase 6 — DoS stress testing (SOLO con autorización) — ver el skill `dos-testing`
| Herramienta | Uso | Límites |
|---|---|---|
| `hping3 -S --flood -p 80 <target>` | Flooding controlado | solo en scope, duración corta |
| `nmap --script dos <target>` | Validar DoS conocidos | solo lab |
- Confirmar con `check-scope.sh <target> dos` y con el usuario. NUNCA contra terceros.

### Fase 7 — Phishing simulation (SOLO con autorización) — ver el skill `phishing-sim`
| Herramienta | Uso |
|---|---|
| `GoPhish` | Campañas de concienciación con tracking |
| `setoolkit` (SET) | Vectores de phishing en lab |
- Confirmar consentimiento de receptores. Plataforma propia. NUNCA terceros.

### Fase 8 — Reporting y Cleanup
- Consolidar con `pentest-report-agent` siguiendo `__OPENCODE_ROOT__/rules/cyber/reporting.md`.
- Limpiar artefactos y procesos según `__OPENCODE_ROOT__/rules/cyber/cleanup.md`.

## 2. Checklist de Autorización por Fase

| Fase | check-scope tipo | Requiere confirmación usuario si fuera de scope |
|---|---|---|
| Recon (activo) | `recon` | Sí (gate flexible) |
| Scan | `scan` | Sí |
| Enumerate | `enum` | Sí |
| Exploit | `exploit` | Sí |
| Post-exploit | `post-exploit` | Sí |
| DoS | `dos` | Sí (siempre) |
| Phishing | `phishing` | Sí (siempre) |
| Reporting/Cleanup | — | No necesaria |

## 3. Reglas de Oro
1. **Autorización** → `check-scope.sh` antes de cada acción activa; gate flexible si está fuera de scope.
2. **Consentimiento** → si el usuario declara "legal / con consentimiento / autorizado", se procede y se registra en `audit.log`. Nunca inventar autorización.
3. **Transparencia** → explicar cada herramienta y su flag ("Explain Before Acting").
4. **Limitar** → DoS con límites de duración/rate; phishing solo a receptores consentidos.
5. **Registrar** → `audit-log.sh` por cada acción ofensiva.
6. **No daño** → prohibido daño permanente a terceros, exfiltración de datos reales de terceros.
7. **Limpiar** → cleanup y reporte al finalizar.

## 4. Wordlists disponibles en este sistema
- `/usr/share/wordlists/rockyou.txt.gz` → descomprimir con `gunzip -k` para rockyou.txt
- `/usr/share/wordlists/dirb/common.txt`
- `/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt`
- `/usr/share/wordlists/nmap.lst`, `fasttrack.txt`, `john.lst`

## 5. Laboratorios de práctica recomendados (targets autorizados)
- **DVWA** (docker local, `~/dvwa-compose.yml`)
- **Metasploitable2** (VM local)
- **WackoPicko / BWAPP / OWASP Juice Shop** (locales)

## 6. Learning Loop
Si una técnica falla: documentar en `/tmp/opencode/skills/learning-logs/cyber-offensive/YYYY-MM-DD_nombre.md`, ajustar el enfoque (nueva herramienta/flag) y continuar. Actualizar este playbook si el patrón se repite.

---
**Generado por:** Ecosistema de Ciberseguridad (skill `cyber-offensive`)