---
name: conducting-network-penetration-test
description: Ejecuta un pentest de red completo (externo o interno) siguiendo PTES/OSSTMM
  con gate de autorización obligatorio: reconocimiento, escaneo, enumeración, análisis de
  vulnerabilidades, explotación controlada, post-explotación e informe, usando herramientas
  reales (nmap, masscan, subfinder, amass, httpx, nuclei, nikto, gobuster, ffuf, sqlmap, hydra,
  searchsploit). Use durante engagements autorizados cuando se necesite validar la postura de
  seguridad de la infraestructura de red.
domain: cybersecurity
subdomain: penetration-testing
tags:
- network-pentest
- PTES
- OSSTMM
- nmap
- nuclei
- reconnaissance
- enumeration
- exploitation
- vulnerability-assessment
version: '1.0'
author: mahipal
license: Apache-2.0
nist_csf:
- ID.RA-01
- ID.RA-06
- GV.OV-02
- DE.AE-07
mitre_attack:
- T1046
- T1595.001
- T1190
- T1110
- T1059
- T1078
---

# Conducting Network Penetration Test

> **Aviso legal:** Este skill es solo para pruebas de seguridad autorizadas y fines
> educativos. Atacar sistemas sin permiso escrito es ilegal y viola las leyes de fraude
> informático.

## Descripción general

Un pentest de red simula a un atacante real contra la infraestructura de la organización
(firewalls, servidores web, DNS, correo, VPN, servicios internos) para descubrir
vulnerabilidades explotables antes de que lo haga un tercero. Sigue PTES, OSSTMM y
NIST SP 800-115, con trazabilidad total: cada acción ofensiva pasa por el gate de
autorización y queda registrada en el audit log.

## Cuándo usarlo

- Assessments de seguridad programados con alcance (scope) definido y firmado.
- Validación de controles tras un cambio de infraestructura o parcheo.
- Fases 2 a 6 del flujo `pentest-flow-detail` (recon → scan → enum → exploit → post-exploit).

## Prerrequisitos

- Autorización escrita (SoW / RoE) con targets, exclusiones, ventana y contacto de emergencia.
- Proyecto activo con `scope.json` y herramientas instaladas (`__OPENCODE_ROOT__/rules/cyber/authorization.md`).
- Espacio de trabajo: `__HOME__/BugBounty/<proyecto>/{recon,testing,evidence,reports}/`.
- Coordinación con SOC/NOC para ventanas de testing y avisos de falsos positivos.

## Gate de autorización (obligatorio)

**Antes de CUALQUIER acción activa** (escaneo, enumeración, explotación), ejecuta:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo>
bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <tipo>"
```

Regla inflexible:

- **`exit 0`** → el target está en scope: procede y registra cada herramienta con `audit-log.sh`.
- **`exit 1`** → el target **NO** está en scope: **pregunta al usuario** y **no continúes sin
  confirmación explícita**. Solo con confirmación ("es legal / tengo consentimiento") se
  procede, registrando el override (o añadiendo el target con `authorize.sh add <target> <tipo>`).

Tipos válidos de `<tipo>`: `recon`, `scan`, `enumerate`, `exploit`, `post-exploit`, `dos`, `phishing`.
Ejecuta el gate al inicio de **cada fase** (un `recon` aprobado no autoriza un `exploit`).

## Flujo por fases

### Fase 1 — Preparación y alcance

```bash
bash __OPENCODE_ROOT__/tools/project-context.sh          # proyecto activo
bash __OPENCODE_ROOT__/tools/authorize.sh status         # targets autorizados
mkdir -p __HOME__/BugBounty/<proyecto>/{recon,testing,evidence,reports}
```

Define targets, exclusiones, ventana horaria y nivel de intrusión permitido antes de tocar nada.

### Fase 2 — Reconocimiento pasivo (sin tocar el target)

```bash
# Subdominios
subfinder -d target.com -o __HOME__/BugBounty/<proyecto>/recon/subfinder.txt
amass enum -passive -d target.com -o __HOME__/BugBounty/<proyecto>/recon/amass.txt
cat __HOME__/BugBounty/<proyecto>/recon/{subfinder,amass}.txt | sort -u > all_subs.txt
# DNS, historial de URLs, emails y certificados
dnsrecon -d target.com -j __HOME__/BugBounty/<proyecto>/recon/dnsrecon.json
gau target.com --threads 5 > __HOME__/BugBounty/<proyecto>/recon/gau.txt
theHarvester -d target.com -b all -l 500 -f __HOME__/BugBounty/<proyecto>/recon/harvest
curl -s "https://crt.sh/?q=%.target.com&output=json" | jq -r '.[].name_value' | sort -u >> all_subs.txt
dig target.com MX +short; dig target.com TXT +short; whois target.com
```

### Fase 3 — Descubrimiento y escaneo

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh 203.0.113.0/24 scan
bash __OPENCODE_ROOT__/tools/audit-log.sh "nmap 203.0.113.0/24 scan"
# Descubrimiento de hosts
nmap -sn 203.0.113.0/24 -oG ping_sweep.gnmap
# Barrido de puertos amplio con rate acotado (evita DoS accidental)
masscan -p1-65535 203.0.113.0/24 --rate=1000 -oL masscan.lst
# Servicios y versiones
nmap -sS -sV -sC -T4 -p- --min-rate 1000 -oA __HOME__/BugBounty/<proyecto>/testing/tcp_full 203.0.113.0/24
nmap -sU --top-ports 100 -T4 -oA __HOME__/BugBounty/<proyecto>/testing/udp_top 203.0.113.0/24
# Probing web sobre hosts vivos
cat all_subs.txt | httpx -status-code -title -tech-detect -o live_webs.txt
```

### Fase 4 — Enumeración profunda

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh target.com enumerate
whatweb https://target.com -v > __HOME__/BugBounty/<proyecto>/testing/whatweb.txt
testssl --full https://target.com > __HOME__/BugBounty/<proyecto>/testing/testssl.txt
# Directorios, archivos y parámetros
ffuf -u https://target.com/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -mc 200,204,301,302,403 -o __HOME__/BugBounty/<proyecto>/testing/ffuf.json -of json
gobuster dir -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/big.txt \
  -x php,html,txt,bak -o __HOME__/BugBounty/<proyecto>/testing/gobuster.txt
feroxbuster -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories-lowercase.txt \
  --depth 3 -o __HOME__/BugBounty/<proyecto>/testing/ferox.txt
arjun -u https://target.com/page?id=1 -oJ __HOME__/BugBounty/<proyecto>/testing/arjun.json
# Servicios específicos (solo si aplica)
wpscan --url https://target.com --enumerate vp,vt -o __HOME__/BugBounty/<proyecto>/testing/wpscan.txt   # WordPress
enum4linux -a 203.0.113.15 > __HOME__/BugBounty/<proyecto>/testing/smb.txt                              # 139/445
nmap --script vuln -sV -oA __HOME__/BugBounty/<proyecto>/testing/nmap_vuln 203.0.113.0/24
```

### Fase 5 — Análisis de vulnerabilidades

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh target.com scan
bash __OPENCODE_ROOT__/tools/audit-log.sh "nuclei target.com scan"
nuclei -l live_webs.txt -severity critical,high -o __HOME__/BugBounty/<proyecto>/testing/nuclei.txt
nikto -h https://target.com -output __HOME__/BugBounty/<proyecto>/testing/nikto.html -Format htm
# Correspondencia con exploits conocidos
searchsploit apache 2.4.49
searchsploit openssh 9.2
```

### Fase 6 — Explotación controlada

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh target.com exploit
bash __OPENCODE_ROOT__/tools/audit-log.sh "sqlmap target.com exploit"
# SQLi solo con autorización tipo exploit explícita
sqlmap -u "https://target.com/page?id=1" --batch --level 3 --risk 2 --dbs \
  --output-dir=__HOME__/BugBounty/<proyecto>/testing/sqlmap
# Credenciales débiles — tasa baja y -f (para no bloquear cuentas)
hydra -L /usr/share/seclists/Usernames/top-usernames-shortlist.txt \
  -P /usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt \
  -t 4 -f ssh://203.0.113.10 -o __HOME__/BugBounty/<proyecto>/testing/hydra.txt
```

### Fase 7 — Post-explotación y validación de impacto

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh 203.0.113.15 post-exploit
# Prueba de acceso SIN exfiltrar datos reales
echo "PENTEST-PROOF-$(date +%Y%m%d)" > /tmp/pentest_proof.txt
# Escalada en Linux (ver skill performing-privilege-escalation-on-linux)
sudo -l; find / -perm -4000 -type f 2>/dev/null
```

### Fase 8 — Cierre, limpieza e informe

```bash
bash __OPENCODE_ROOT__/tools/audit-log.sh "cleanup <target> post-exploit"
bash __OPENCODE_ROOT__/tools/cleanup.sh <proyecto>
```

Ver `__OPENCODE_ROOT__/rules/cyber/cleanup.md` y `__OPENCODE_ROOT__/rules/cyber/reporting.md`.

## Tabla de herramientas

| Herramienta | Fase | Uso |
|---|---|---|
| `subfinder` / `amass` | Recon pasivo | Enumeración de subdominios |
| `gau` / `katana` / `theHarvester` / `dnsrecon` | Recon pasivo | URLs históricas, crawling, emails, DNS |
| `masscan` / `nmap` | Escaneo | Puertos (`--rate` acotado), servicios, NSE `vuln` |
| `httpx` | Escaneo | Probing web (código, título, tecnologías) |
| `testssl` / `whatweb` | Enumeración | TLS y fingerprinting web |
| `ffuf` / `gobuster` / `feroxbuster` / `arjun` | Enumeración | Directorios, archivos, vhosts y parámetros |
| `wpscan` / `enum4linux` | Enumeración | WordPress y SMB/Windows |
| `nuclei` / `nikto` | Análisis | Vulnerabilidades conocidas y misconfigs |
| `searchsploit` | Análisis | Exploits locales (Exploit-DB) |
| `sqlmap` | Explotación | Inyección SQL confirmada |
| `hydra` | Explotación | Fuerza bruta/spray de credenciales (rate bajo) |
| `wireshark` / `tcpdump` | Evidencia | Captura de tráfico durante pruebas activas |

## Interpretación de resultados

- **Prioriza por explotabilidad, no por severidad cruda**: un `critical` de nuclei solo vale si
  el asset está en alcance y el PoC es verificable; clasifica con CVSS v3.1 y mapea ATT&CK.
- **Diferencia hallazgo de ruido**: `nikto` acumula falsos positivos — valida con `curl` antes
  de reportar; un banner viejo de `whatweb` no es vulnerabilidad por sí solo.
- **`nmap --script vuln`**: confirma cada match leyendo la salida del script (versiones mal
  parseadas generan falsos positivos).
- **`hydra`/`sqlmap`**: un fallo puede ser bloqueo de cuenta o WAF, no ausencia de
  vulnerabilidad. Correlaciona con respuestas HTTP (403/429 vs 200/500).
- **Cadena de ataque**: encadena hallazgos (subdominio → servicio desactualizado → credencial
  débil → escalada) y puntúalos como un hallazgo con impacto agregado.

## Límites legales y éticos

- **Solo targets en scope** verificados con `check-scope.sh`; fuera de scope → parar y preguntar.
- **Sin DoS destructivo**: sin floods ni `--min-rate` masivo contra servicios frágiles, sin
  `sqlmap --os-shell`/`--sql-file` destructivos, sin borrar o modificar datos reales.
- **Sin persistencia** más allá de la prueba y sin exfiltración real: solo ficheros de prueba.
- **Credenciales**: no fuerza bruta masiva (bloqueo de cuentas) sin aprobación y con `-t` bajo;
  no usar cuentas reales capturadas fuera del engagement.
- **Privacidad y trazabilidad**: no recoger datos personales sin ofuscar; toda acción ofensiva
  registrada en `audit-log.sh` (sin registro, no debe repetirse).

## Entregable / Informe

Ruta: `__HOME__/BugBounty/<proyecto>/reports/<fecha>_<target>_pentest-report.md`
(según `__OPENCODE_ROOT__/rules/cyber/reporting.md`):

1. **Resumen ejecutivo** — alcance, ventana, riesgo global, hallazgos clave.
2. **Hallazgos técnicos** — título, CVSS, asset, pasos de reproducción, evidencia
   (`testing/`, `evidence/`), remediación, CVE/CWE, ATT&CK.
3. **Metodología** — fases, gate `check-scope` ejecutado, herramientas y versiones.
4. **Cadena de ataque** — narrativa de acceso → movimiento → impacto.
5. **Anexos y cierre** — salidas crudas, timeline, `audit.log`, cleanup completado.

## Referencias

- PTES: http://www.pentest-standard.org/
- OSSTMM v3: https://www.isecom.org/OSSTMM.3.pdf
- NIST SP 800-115: https://csrc.nist.gov/publications/detail/sp/800-115/final
- MITRE ATT&CK: https://attack.mitre.org/
