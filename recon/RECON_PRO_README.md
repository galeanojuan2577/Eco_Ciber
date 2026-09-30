# RECON_PRO v3.0

Framework profesional de reconocimiento de dominios con menú interactivo, 3 niveles de profundidad, informes HTML/MD/JSON e integración ECC.

---

## Instalación

El script ya está instalado y listo para usar:

- **Archivo:** `/root/Escritorio/recon_pro.sh`
- **Comando:** `recon` (disponible en cualquier terminal)

---

## Modos de Uso

### Menú Interactivo
```bash
recon
```
Abre el menú principal con todas las opciones disponibles.

### Modo CLI (Rápido)
```bash
# Rápido (nivel 1)
recon ejemplo.com 1

# Normal (nivel 2 - default)
recon ejemplo.com

# Profundo (nivel 3)
recon ejemplo.com 3

# Con integración ECC
recon ejemplo.com 3 --ecc

# Con opciones personalizadas
recon ejemplo.com 2 --threads 100 --timeout 600 --wordlist /ruta/wordlist.txt
```

### Multi-Target
```bash
recon
# Seleccionar opción [4] Escaneo Multi-Target
# Proporcionar archivo .txt con un dominio por línea
```

---

## Niveles de Escaneo

| Nivel | Nombre | Duración | Herramientas |
|-------|--------|----------|--------------|
| 1 | Rápido | 5-10 min | whois, dig, nmap -F, whatweb, nikto |
| 2 | Normal | 15-30 min | + subfinder, amass, nmap -p-, gobuster, nuclei |
| 3 | Profundo | 1-2 horas | + ffuf, feroxbuster, wfuzz, sqlmap, katana, gau |

---

## Fases del Escaneo

### Fase 1: Reconocimiento Pasivo
- WHOIS
- DNS (A, AAAA, MX, NS, TXT, CNAME, SOA, SRV)
- Transferencia de zona (AXFR)
- Subdominios (Subfinder, Amass, theHarvester, crt.sh, dnsrecon)
- URLs (katana, gau)

### Fase 2: Escaneo Activo
- nmap (rápido, completo, servicios, vulns NSE, UDP)
- httpx (validación de hosts web)
- WhatWeb (tecnologías)
- SSL/TLS (openssl, sslscan, testssl)

### Fase 3: Enumeración
- Directorios (gobuster, feroxbuster, ffuf)
- Virtual hosts
- Subdomain fuzzing
- Parámetros (arjun, wfuzz)

### Fase 4: Vulnerabilidades
- Nikto
- Nuclei (critical, high, medium, low)
- WPScan (auto-detect WordPress)
- SQLMap (auto-detect parámetros)
- Correlación nmap vulns

### Fase 5: Exploits
- searchsploit por servicio+versión
- Correlación CVE
- CVSS scoring

### Fase 6: Informe
- Markdown (resumen.md)
- HTML con gráficos Chart.js (resumen.html)
- JSON para procesamiento (hallazgos.json)

---

## Flags Disponibles

| Flag | Descripción |
|------|-------------|
| `--ecc` | Activar integración ECC (check-scope, audit-log) |
| `--quiet` | Modo silencioso (solo output a archivo) |
| `--resume` | Continuar escaneo interrumpido |
| `--report-only` | Solo generar informe (sin escanear) |
| `--threads N` | Hilos para herramientas (default: 50) |
| `--timeout N` | Timeout por herramienta en segundos (default: 300) |
| `--wordlist PATH` | Wordlist personalizada |

---

## Integración ECC

Con el flag `--ecc`, el script:
- Verifica el scope antes de escanear
- Registra cada herramienta en audit.log
- Gestiona autorización de targets

Requiere: `/root/.config/opencode/tools/`

---

## Estructura de Directorios

```
recon_<target>/
├── 01_pasivo/
│   ├── dns/
│   ├── subdominios/
│   └── osint/
├── 02_activo/
│   ├── nmap/
│   └── ssl/
├── 03_enumeracion/
│   ├── directorios/
│   ├── subdomain_fuzz/
│   └── parametros/
├── 04_vulnerabilidades/
│   └── nuclei/
├── 05_exploits/
│   └── searchsploit/
├── 06_informe/
│   ├── resumen.md
│   ├── resumen.html
│   └── hallazgos.json
└── 07_ecosistema/
```

---

## Herramientas Requeridas

### Core (obligatorio)
- nmap

### Recomendadas
- whois, dig, openssl, curl
- whatweb, nikto, gobuster, httpx
- subfinder, amass
- theHarvester

### Para nivel 3
- ffuf, feroxbuster, wfuzz, arjun
- nuclei, sslscan, wpscan, sqlmap
- katana, gau, dnsrecon

### Instalación rápida
```bash
recon  # Opción [7] Instalar Herramientas
```

---

## Ejemplos

```bash
# Escaneo rápido de un dominio
recon ejemplo.com 1

# Escaneo completo con ECC
recon ejemplo.com 3 --ecc

# Multi-target desde archivo
# Crear targets.txt con:
#   ejemplo1.com
#   ejemplo2.com
#   ejemplo3.com
recon  # Opción [4] → targets.txt → nivel 2

# Ver informes anteriores
recon  # Opción [6]
```

---

## Notas

- Los escaneos nivel 3 pueden tardar hasta 2 horas
- Algunas herramientas pueden no estar instaladas (el script funcionará con las disponibles)
- Los informes HTML incluyen gráficos interactivos con Chart.js
- La integración ECC es opcional pero recomendada para trazabilidad

---

**Autor:** Parable  
**Versión:** 3.0  
**Fecha:** 2025
