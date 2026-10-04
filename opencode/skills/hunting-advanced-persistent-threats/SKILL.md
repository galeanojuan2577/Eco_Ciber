---
name: hunting-advanced-persistent-threats
description: Caza proactiva de amenazas persistentes avanzadas (APT) con hipótesis basadas
  en MITRE ATT&CK: recolección de telemetría (logs, DNS, proxy, PCAP), detección de beaconing
  C2 y exfiltración con tshark/tcpdump/awk, validación de indicadores en scope con nmap/httpx/nuclei,
  y entrega de detecciones y hallazgos priorizados. Use en equipos defensivos o en engagements
  autorizados cuando se sospeche de intrusión persistente.
domain: cybersecurity
subdomain: threat-hunting
tags:
- threat-hunting
- apt
- mitre-attack
- ioc
- c2-detection
- beaconing
- network-forensics
- detection-engineering
- dfir
version: '1.0'
author: mahipal
license: Apache-2.0
nist_csf:
- DE.CM-01
- DE.AE-03
- DE.AE-07
- ID.RA-01
mitre_attack:
- T1071
- T1071.004
- T1573
- T1090
- T1048
- T1547
---

# Hunting Advanced Persistent Threats

> **Aviso legal:** Este skill es solo para pruebas de seguridad autorizadas y fines
> educativos. La caza de amenazas se ejecuta únicamente sobre la infraestructura del
> cliente/laboratorio con consentimiento; atacar sistemas ajenos es ilegal.

## Descripción general

La caza de APT (threat hunting) es una actividad proactiva y dirigida por hipótesis: en lugar
de esperar alertas, se buscan evidencias de TTPs de actores persistentes (beaconing C2,
tunelizado DNS, exfiltración sobre protocolos legítimos, persistencia, movimiento lateral)
correlacionando telemetría de red, logs y artefactos del endpoint. Este skill combina análisis
pasivo de telemetría (tshark/tcpdump/grep/awk/jq) con validación activa de indicadores
dentro del scope (nmap, httpx, gau, nuclei) y termina en detecciones reutilizables e informe.

## Cuándo usarlo

- Alerta de SOC sin explicación, tráfico anómalo recurrente o sospecha de compromiso persistente.
- Búsqueda de IOCs/TTPs de un APT reciente (campañas del sector, notify del CSIRT).
- Caza dirigida tras un incidente para descartar persistencia no detectada.
- Validación defensiva de la red propia tras un pentest o red team.

## Prerrequisitos

- Acceso (solo lectura) a logs de firewall/proxy/DNS/EDR y capacidad de capturar tráfico.
- `wireshark`/`tshark`/`tcpdump`, `jq`, y las herramientas de red instaladas (ver tabla).
- Lista de fuentes de inteligencia de amenazas (feeds de IOC del sector) y baseline normal.
- Proyecto activo y scope definido (`__OPENCODE_ROOT__/rules/cyber/authorization.md`).

## Gate de autorización (obligatorio)

**Antes de CUALQUIER acción activa** (barrido, sonda, crawl, captura sobre enlace que no sea
propio), ejecuta:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo>
bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <tipo>"
```

Regla inflexible:

- **`exit 0`** → target en scope: procede y registra cada herramienta con `audit-log.sh`.
- **`exit 1`** → target **NO** en scope: **pregunta al usuario** y **no continúes sin
  confirmación explícita**. La caza sobre hosts de terceros (CDN, proveedor SaaS) solo se
  hace con su consentimiento o de forma puramente pasiva.

Tipos: `recon` (lectura/análisis), `scan` (barridos y sondas), `enumerate`, `exploit`,
`post-exploit`, `dos`, `phishing`. En threat hunting usarás casi siempre `recon` y `scan`.

## Flujo por fases

### Fase 1 — Hipótesis y preparación

1. Define la hipótesis antes de mirar datos (ej.: "un host del área financiera mantiene
   beaconing HTTPS cada 60 s a un dominio registrado hace <30 días").
2. Mapea cada hipótesis a técnicas ATT&CK (T1071.004 DNS C2, T1573 canal cifrado,
   T1048 exfiltración, T1547 persistencia).
3. Levanta el baseline normal: volúmenes DNS, destinos proxy, horarios de trabajo.
4. Inventaría fuentes disponibles: `firewall.log`, `proxy.log`, `dns.log`, EDR, NetFlow, PCAP.

```bash
mkdir -p __HOME__/BugBounty/<proyecto>/{recon,evidence,reports}
bash __OPENCODE_ROOT__/tools/audit-log.sh "threat-hunt inicio <target> recon"
```

### Fase 2 — Recolección de telemetría (pasiva)

```bash
# Tráfico en vivo desde el sensor propio (interface de monitoreo)
sudo tcpdump -i any -nn -s0 -w __HOME__/BugBounty/<proyecto>/evidence/hunt_$(date +%s).pcap 'not port 22'

# Filtros de análisis sobre PCAP ya capturado
tshark -r evidence/capture.pcap -q -z io,phs                      # protocolos y jerarquía
tshark -r evidence/capture.pcap -Y 'tls.handshake.extensions_server_name' -T fields -e tls.handshake.extensions_server_name | sort | uniq -c | sort -rn > sni_frecuentes.txt
tshark -r evidence/capture.pcap -Y 'dns.flags.response == 1 && dns.flags.rcode != 0' -T fields -e ip.dst -e dns.qry.name > nxdomains.txt
tshark -r evidence/capture.pcap -q -z conv,ip                      # conversaciones por volumen

# Logs estructurados
jq -c 'select(.action=="allowed")' logs/firewall.json > allowed.json
grep -Ei 'outbound|egress' logs/proxy.log | awk '{print $7}' | sort | uniq -c | sort -rn | head -30
```

### Fase 3 — Detección de beaconing, DNS anómalo y exfiltración

```bash
# Intervalos regulares (beaconing) entre un host y cada destino: delta en segundos
tshark -r evidence/capture.pcap -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' \
  -T fields -e frame.time_epoch -e ip.dst | awk '
  { k=$2; d=$1-p[k]; if (k in p) { n[k]++; s[k]+=d; ss[k]+=d*d }
    p[k]=$1; if (!(k in min) || d<min[k]) min[k]=d; if (d>max[k]) max[k]=d }
  END { for (k in n) { m=s[k]/n[k];
    v=(ss[k]/n[k])-m*m; if (m>0 && (v<1 || (max[k]-min[k])<3)) print k, "media="m, "jitter="sqrt(v) } }' \
  | sort -k2 -n | head -20

# Dominios largos / many-NXDOMAIN posiblemente tunelizados
awk 'length($NF)>50' sni_frecuentes.txt
sort nxdomains.txt | uniq -c | sort -rn | head -20       # ráfagas NXDOMAIN = DGA/sandbox

# Volúmenes salientes que sugieren exfiltración
tshark -r evidence/capture.pcap -q -z conv,ip | sort -k5 -rn | head -15

# Contexto de dominios sospechosos
dnsrecon -d sospechoso.com
gau sospechoso.com | head -50                            # historial de URLs del dominio
```

### Fase 4 — Validación activa de indicadores (solo en scope)

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh 10.0.5.50 scan
bash __OPENCODE_ROOT__/tools/audit-log.sh "nmap 10.0.5.50 scan"

nmap -sV -sC -Pn -T3 --top-ports 100 10.0.5.50 -oA __HOME__/BugBounty/<proyecto>/recon/host_sospechoso
printf '10.0.5.50\n' | httpx -status-code -title -tech-detect -o recon/host_web.txt
testssl --full https://host-sospechoso.target.com > recon/tls_sospechoso.txt    # cert autofirmado/emitido reciente = señal
nuclei -u https://host-sospechoso.target.com -severity critical,high -o testing/nuclei_hunt.txt

# Subdominios "shadow" creados por el atacante
subfinder -d target.com -o recon/subfinder_hunt.txt
comm -13 <(sort recon/subfinder_previo.txt) <(sort recon/subfinder_hunt.txt)   # nuevos desde la última revisión
```

### Fase 5 — Correlación, descarte y scoring

- Correlaciona host → IOC → técnica ATT&CK → fuente de telemetría (mínimo 2 fuentes por hallazgo).
- Descarta ruido legítimo: CDNs, actualizaciones, VPN corporativa, backup nocturno, CDNs de
  seguridad (sandbox del correo), keepalivos de balanceadores.
- Asigna confianza: `Confirmado` (2+ fuentes o ejecución verificada), `Probable`, `Descartado`.
- Registra cada decisión (incluidos descartes) en el audit log y en el informe.

### Fase 6 — Escalado y contención (solo recomendación)

- Propón la contención al equipo del cliente (aislamiento EDR, bloqueo de dominio en DNS/proxy).
- **No desconectes ni aísles hosts por tu cuenta**: la contención es decisión del dueño del activo.
- Si hay indicio de compromiso activo, detén la caza ofensiva y activa el playbook de respuesta
  (`__OPENCODE_ROOT__/rules/cyber/authorization.md` §5 — registrar la suspensión).

## Tabla de herramientas

| Herramienta | Fase | Uso |
|---|---|---|
| `tcpdump` / `tshark` / `wireshark` | Recolección | Captura y filtrado de tráfico (SNI, DNS, flujos) |
| `jq` / `grep` / `awk` | Análisis | Telemetría estructurada, cálculo de beaconing |
| `dnsrecon` | Análisis DNS | Contexto de dominios y registros sospechosos |
| `subfinder` / `amass` | Validación | Detección de subdominios shadow nuevos |
| `gau` / `katana` | Validación | Histórico de URLs y crawling de hosts en scope |
| `nmap` | Validación | Postura de servicios del host sospechoso |
| `httpx` | Validación | Probing web de hosts/URLs candidatos |
| `testssl` | Validación | Certificados TLS recientes o cadenas anómalas |
| `nuclei` | Validación | Vulnerabilidades que explique el atacante (webshell, exposición) |
| `theHarvester` | OSINT | Relación de infraestructura (email/host) del atacante |

## Interpretación de resultados

- **Señal vs ruido**: un solo IOC (hash, dominio) es débil; un patrón de comportamiento
  (intervalo regular + dominio joven + volumen saliente alto) es fuerte.
- **Beaconing**: delta con varianza casi nula indica automatización; compara contra keepalivos
  legítimos (NTP, monitoreo) que son simétricos pero de baja frecuencia y a destinos conocidos.
- **DNS**: ráfagas NXDOMAIN de nombres aleatorios largos sugieren DGA o sandbox; nombres
  excesivamente largos con respuestas TXT/NULL crecientes sugieren tunelizado.
- **TLS**: certificados autofirmados, con validez muy corta o emisor desconocido en un host
  corporativo son sospechosos; correlaciona con fecha de registro del dominio.
- **Falsos positivos habituales**: CDNs multi-IP (varía el destino con intervalo regular),
  balanceadores, software de backup, extensiones de navegador, sandbox de correo.
- **Priorización**: impacto × confianza × exposición; documenta la hipótesis original como
  cumplida/incumplida para afinar la siguiente caza.

## Límites legales y éticos

- **Solo targets en scope** verificados con `check-scope.sh`; fuera de scope → parar y preguntar.
- **Sin DoS destructivo**: sin floods ni barridos saturadores; `nmap` con `-T3` y top-ports
  en hosts productivos.
- **Sin modificación de evidencia**: trabaja sobre copias de logs/PCAP; conserva integridad
  (guarda hashes con `sha256sum`).
- **Privacidad**: los logs pueden contener datos personales; no los copies fuera del proyecto
  ni los incluyas sin anonimizar.
- **Sin bloqueos ni aislamientos** por cuenta propia; solo recomendaciones al responsable.
- **Trazabilidad**: toda acción activa registrada en `audit-log.sh`.

## Entregable / Informe

Ruta: `__HOME__/BugBounty/<proyecto>/reports/<fecha>_<target>_threat-hunt-report.md`:

1. **Hipótesis de caza** y su estado (cumplida / incumplida / parcial).
2. **Alcance de datos**: fuentes, ventana temporal, hosts analizados, limitaciones.
3. **Hallazgos** con confianza, evidencia (extractos de PCAP/log), técnica ATT&CK y recomendación.
4. **Detecciones reutilizables**: filtros/pseudoreglas (tshark, grep/awk, sigma-like) para el SOC.
5. **Descartes justificados** — qué se evaluó y por qué se descartó.
6. **Recomendaciones** de contención, hardening y seguimiento; entrada de `audit.log`.

## Referencias

- MITRE ATT&CK: https://attack.mitre.org/
- MITRE D3FEND: https://d3fend.mitre.org/
- The DFIR Report — casos APT: https://thedfirreport.com/
- NIST SP 800-137 — Information Continuous Monitoring: https://csrc.nist.gov/publications/detail/sp/800-137/final
- Volatility documentation (artefactos de memoria): https://volatility3.readthedocs.io/
