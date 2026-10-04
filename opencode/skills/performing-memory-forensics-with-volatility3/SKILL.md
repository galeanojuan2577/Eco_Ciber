---
name: performing-memory-forensics-with-volatility3
description: Adquiere y analiza volúmenes de memoria con Volatility 3 (vol) para incidentes
  de seguridad: cadena de custodia, plugins de procesos, red, registro, credenciales y
  código inyectado en Windows y Linux, interpretación de artefactos y reporte forense.
  Use cuando una imagen de memoria necesite ser examinada para probar inyección de código,
  dump de credenciales, persistencia o actividad de C2. Requiere instalar volatility3 si
  `vol -h` no está disponible.
domain: cybersecurity
subdomain: digital-forensics
tags:
- volatility3
- memory-forensics
- dfir
- incident-response
- windows-forensics
- linux-forensics
- malware-analysis
- credential-detection
version: '1.0'
author: mahipal
license: Apache-2.0
nist_csf:
- DE.AE-03
- DE.CM-01
- ID.RA-01
- RS.AN-01
mitre_attack:
- T1003
- T1055
- T1547
- T1027
- T1112
---

# Performing Memory Forensics with Volatility 3

> **Aviso legal:** Este skill es solo para pruebas de seguridad autorizadas y fines
> educativos. La adquisición de memoria de sistemas ajenos sin permiso es ilegal; trabaja
> siempre dentro del scope y con cadena de custodia.

## Descripción general

El análisis de memoria permite detectar lo que el disco no muestra: procesos inyectados o
"ghost", credenciales en claro, canales C2 activos, claves de cifrado y persistencia en
runtime. Volatility 3 (`vol`) es el framework estándar: trabaja sobre imágenes crudas
(LiME, winpmem, dump de hipervisor) y, a diferencia de V2, detecta el perfil del SO
automáticamente. Este skill cubre la instalación/verificación, la adquisición con cadena de
custodia, los plugins esenciales y la interpretación de resultados.

## Cuándo usarlo

- Incidente de seguridad en curso: evidenciar inyección, procesos ocultos o C2.
- Verificar si se extrajeron credenciales (LSASS/kallsyms) o se modificó el registro.
- Complementar el análisis de disco y de red en un IR o en un pentest post-explotación.
- Tarea de `forensics-agent` del ecosistema (ver `pentest-flow-detail` fase 6 y reporting).

## Prerrequisitos

- **Instalación de Volatility 3** (si `vol -h` falla, instala y verifica):

```bash
sudo pacman -S volatility3     # paquete de Arch (preferido si existe)
# —o bien—
pipx install volatility3
vol -h                          # verificación: debe mostrar usage y lista de plugins
```

- Python 3.8+, espacio en disco >= tamaño de la imagen, y acceso de lectura a los volúmenes.
- `sha256sum` y `file` para integridad; `tshark` opcional para correlación con PCAP.
- Imagen de memoria ya adquirida (o permiso para adquirirla en el host en scope).

## Gate de autorización (obligatorio)

**Antes de CUALQUIER acción activa** (adquisición en un host vivo, despliegue de agente,
conexión al host para volcado), ejecuta:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo>
bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <tipo>"
```

Regla inflexible:

- **`exit 0`** → target en scope: procede y registra cada acción con `audit-log.sh`.
- **`exit 1`** → target **NO** en scope: **pregunta al usuario** y **no continúes sin
  confirmación explícita** (incluida la cadena de custodia y el método de adquisición).

Usa `<tipo> = recon` para adquisición/lectura en host autorizado y `post-exploit` cuando la
adquisición requiera desplegar herramienta sobre un host comprometido en el engagement.

## Flujo por fases

### Fase 1 — Adquisición y cadena de custodia

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh 10.0.5.50 post-exploit
bash __OPENCODE_ROOT__/tools/audit-log.sh "mem-acquisition 10.0.5.50 post-exploit"

# Linux (LiME, en el host objetivo — lab/autorizado)
sudo insmod lime-*.ko "path=/tmp/memory.lime format=lime"
# Windows: winpmem / DumpIt.exe / FTK Imager (volcado crudo .raw)

# Trabaja SIEMPRE sobre copia; registra hashes en evidence/
cp /tmp/memory.lime __HOME__/BugBounty/<proyecto>/evidence/mem_10.0.5.50.lime
sha256sum __HOME__/BugBounty/<proyecto>/evidence/mem_10.0.5.50.lime | tee __HOME__/BugBounty/<proyecto>/evidence/mem_10.0.5.50.sha256
file __HOME__/BugBounty/<proyecto>/evidence/mem_10.0.5.50.lime
```

Documenta: origen, fecha/hora UTC, SO detectado, quién adquirió, método y hash. Nunca
modifiques el original.

### Fase 2 — Verificación del entorno y símbolos

```bash
vol -h                                     # confirmar instalación y plugins disponibles
vol -f evidence/mem.img windows.info       # Windows: versión, build, arquitectura
vol -f evidence/mem.img linux.info         # Linux: kernel, uptime (si no existe, prueba linux.pslist)
# Volatility 3 descarga símbolos automáticamente; para entornos aislados:
vol -u                                    # forzar actualización de símbolos (o --offline con cache previa)
```

### Fase 3 — Procesos (Windows)

```bash
vol -f evidence/mem.img -o out/ windows.pslist        # lista de procesos activos
vol -f evidence/mem.img windows.pstree                # jerarquía (parent anómalo)
vol -f evidence/mem.img windows.psscan                # procesos desvinculados de la cadena
vol -f evidence/mem.img windows.psxview               # cross-view: discrepancia = ocultamiento
vol -f evidence/mem.img windows.cmdline               # línea de comandos de cada proceso
vol -f evidence/mem.img windows.malfind               # secciones inyectadas / código sospechoso
vol -f evidence/mem.img windows.hollowprocesses       # proceso hollowed
vol -f evidence/mem.img windows.ldrmodules            # módulos sin PE header en memoria
vol -f evidence/mem.img windows.callbacks             # hooks de kernel
vol -f evidence/mem.img windows.svcscan               # servicios anómalos
```

### Fase 4 — Procesos (Linux)

```bash
vol -f evidence/mem.img linux.pslist
vol -f evidence/mem.img linux.pstree
vol -f evidence/mem.img linux.psscan        # procesos unlinked
vol -f evidence/mem.img linux.cmdline
vol -f evidence/mem.img linux.malfind       # mapeos anómalos de memoria
vol -f evidence/mem.img linux.bash          # historial de bash reciente (si hay volcado de tty)
vol -f evidence/mem.img linux.env
vol -f evidence/mem.img linux.check_creds  # credenciales en kernel (raíz comprometida)
```

### Fase 5 — Red, registro y credenciales

```bash
# Red: conexiones y binarios asociados (C2/beaconing)
vol -f evidence/mem.img windows.netscan     # Windows
vol -f evidence/mem.img windows.netstat     # Windows (asociación con PID)
vol -f evidence/mem.img linux.sockstat     # Linux
vol -f evidence/mem.img linux.sockscan

# Persistencia: claves de ejecución, servicios, tareas programadas
vol -f evidence/mem.img windows.registry.hivelist
vol -f evidence/mem.img windows.registry.printkey --key 'Software\Microsoft\Windows\CurrentVersion\Run'
vol -f evidence/mem.img windows.registry.userassist               # ejecuciones de usuario
vol -f evidence/mem.img windows.scheduled_tasks

# Credenciales (solo con autorización tipo post-exploit y necesidad probada)
vol -f evidence/mem.img windows.hashdump
vol -f evidence/mem.img windows.lsadump
```

### Fase 6 — Evidencias de usuario y timeline

```bash
vol -f evidence/mem.img windows.filescan      # ficheros referenciados en memoria
vol -f evidence/mem.img windows.dumpfiles     # volcado de ficheros de interés
vol -f evidence/mem.img windows.consoles      # historial de consola / comandos ejecutados
vol -f evidence/mem.img timeliner.Timeliner   # timeline unificado
vol -f evidence/mem.img -o out/ windows.vadinfo   # VAD de procesos sospechosos
```

## Tabla de herramientas

| Herramienta | Fase | Uso |
|---|---|---|
| `volatility3` (`vol`) | Análisis | Framework de análisis de memoria (plugins win/linux) |
| `pacman -S volatility3` / `pipx install volatility3` | Prerrequisito | Instalación verificada con `vol -h` |
| LiME (Linux) / winpmem (Windows) | Adquisición | Volcado crudo de memoria en host autorizado |
| `sha256sum` / `file` | Custodia | Integridad y tipología de la imagen |
| `tshark` / `tcpdump` | Correlación | Cruzar C2 visto en memoria con PCAP del incidente |
| `strings` / `grep` | Búsqueda | Búsqueda de IOC (URL, rutas, mutex) en volcados |

## Interpretación de resultados

- **Discrepancias entre plugins**: proceso en `psscan`/`psxview` pero no en `pslist`, o
  `ldrmodules` con alguna sección ausente, indica ocultamiento (rootkit/unlinking).
- **`malfind`**: secciones `PAGE_EXECUTE_WRITECOPY` con `VadTag` anómalo = inyección típica;
  valida el dump (`--dump`) antes de reportar: JIT (dotNet, antivirus) genera falsos positivos.
- **Proceso sin firma o path raro**: correlaciona con `cmdline` y `filescan`; svchost.exe fuera
  de `System32`, powershell con `-enc`, rundll32 con DLL en Temp.
- **Red**: un PID con conexión saliente a IP sin resolución DNS inversa + `malfind` en el mismo
  proceso = sospecha fuerte de C2. Comprueba contra el PCAP (SNI/IP) y la tabla de IOCs.
- **Registro**: claves Run/RunOnce con rutas a usuarios, tareas programadas recientes, servicios
  apuntando a binarios temporales.
- **`hashdump`/`lsadump`**: su presencia confirma extracción; reporta como impacto de acceso a
  credenciales (T1003) sin incluir hashes reales en el informe.
- **Falsos positivos conocidos**: `malfind` en procesos JIT/AV, `filescan` con paths borrados
  legítimos, `lsass` con handle abierto por herramientas de monitoreo.
- **Descarta con contexto**: fecha/hora (UTC vs local), uptime, software instalado conocido.

## Límites legales y éticos

- **Solo targets en scope** verificados con `check-scope.sh`; fuera de scope → parar y preguntar.
- **Sin destrucción ni alteración**: la imagen original es evidencia; siempre trabaja sobre copia.
- **Sin DoS**: la adquisición de memoria satura RAM/CPU; consiente ventana y recursos con el
  responsable antes de ejecutarla en producción.
- **Credenciales sensibles**: los hashes volcados se guardan cifrados/seudonimizados y no se
  usan fuera del engagement; nunca fuerces esos hashes contra sistemas reales sin autorización.
- **Cadena de custodia**: documenta adquisición, transporte y análisis; sin ella la evidencia
  no vale en el informe.
- **Trazabilidad**: toda acción registrada con `audit-log.sh`.

## Entregable / Informe

Ruta: `__HOME__/BugBounty/<proyecto>/reports/<fecha>_<target>_memory-forensics-report.md`:

1. **Resumen** — host, SO, fecha de adquisición, hashes SHA-256, conclusión (comprometido/no).
2. **Metodología** — versión de `vol`, plugins ejecutados, comandos exactos.
3. **Hallazgos** — proceso/ruta/IP afectada, plugin que lo evidencia, salida relevante (anexo),
   técnica ATT&CK, CVSS/impacto, remediación.
4. **Timeline** — eventos clave de `timeliner.Timeliner` y `consoles`.
5. **Evidencias** — imagen original + hashes en `evidence/`, salidas `-o out/` en bruto.
6. **Limitaciones** — qué no pudo determinarse (p.ej. símbolos ausentes, imagen parcial).

## Referencias

- Volatility 3: https://volatility3.readthedocs.io/ · https://github.com/volatilityfoundation/volatility3
- Volatility Foundation: https://volatilityfoundation.org/
- LiME (Linux Memory Extractor): https://github.com/504ensicsLabs/LiME
- MITRE ATT&CK — T1003 OS Credential Dumping: https://attack.mitre.org/techniques/T1003/
- NIST SP 800-86 — Guide to Integrating Forensic Techniques: https://csrc.nist.gov/publications/detail/sp/800-86/final
