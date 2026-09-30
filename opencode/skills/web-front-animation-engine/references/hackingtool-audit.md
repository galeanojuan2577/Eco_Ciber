# HackingTool — Auditoría de Seguridad Web

Repositorio: https://github.com/Z4nzu/hackingtool
Estrellas: 78.3k ⭐
Licencia: MIT
185+ herramientas en 20 categorías.

## Instalación

### Opción 1: One-liner (recomendada)
```bash
curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash
```

### Opción 2: Docker
```bash
docker build -t hackingtool .
docker run -it --rm hackingtool
```

## Auditoría Web con HackingTool

### 1. Information Gathering
```bash
# Dentro de hackingtool menú: Information Gathering
nmap -sV -sC target.com
amass enum -d target.com
theHarvester -d target.com -b google
```

### 2. Web Attack Scanning
```bash
# Web Attack → OWASP ZAP / Nuclei / Nikto
nuclei -u https://target.com -severity critical,high
nikto -h https://target.com
```

### 3. Directory Busting
```bash
# Web Attack → ffuf / Gobuster / Dirsearch
ffuf -u https://target.com/FUZZ -w /usr/share/wordlists/dirb/common.txt
gobuster dir -u https://target.com -w /usr/share/wordlists/dirb/common.txt
```

### 4. SQL Injection Testing
```bash
# SQL Injection Tools → SQLMap
sqlmap -u "https://target.com/page?id=1" --batch --risk=3 --level=5
```

### 5. XSS Testing
```bash
# XSS Attack Tools → DalFox / XSStrike
dalfox url https://target.com
xsstrike -u "https://target.com/search?q=test"
```

### 6. SSL/TLS Audit
```bash
# Web Attack → testssl.sh
testssl.sh https://target.com
```

### 7. Cloud Security
```bash
# Cloud Security → Trivy
trivy fs --severity CRITICAL,HIGH /path/to/project
```

## Flujo de Auditoría Recomendado

```
1. RECON → amass + theHarvester + nmap
2. SCAN → nuclei + nikto
3. DIR-BUST → ffuf + gobuster
4. WEB-TEST → SQLMap + DalFox + testssl.sh
5. REPORT → consolidar hallazgos
```

## Integración con ECC

- Complementa `security-audit-noir` (SAST) con DAST activo
- Usar en etapa 4 del flujo de desarrollo web (después de tests E2E)
- Reportar hallazgos críticos en el format `mistakes-log.md`

## Política de Uso (Hacking Ético autorizado)

- **Autorización previa**: Registrar el alcance con `__OPENCODE_ROOT__/tools/authorize.sh` ANTES de cualquier acción ofensiva. Verificar el target con `check-scope.sh` antes de actuar.
- **Entornos autorizados**: Laboratorio propio (DVWA, Metasploitable2), targets contratados o con SoW firmado, infraestructura propia.
- **DoS stress testing**: Permitido SOLO con autorización documentada (own infra / lab). Usar `hping3`/LOIC con límites de duración y rate. NUNCA contra terceros.
- **Phishing simulation**: Permitido SOLO con infraestructura propia (GoPhish/SET) y receptores con consentimiento explícito o campaña corporativa autorizada.
- Preferir Docker para evitar contaminar el sistema base.
- **Prohibido**: Daño permanente a terceros, exfiltración de datos reales de terceros, acciones ilegales.
- Enfocar en: Information Gathering, Web Attack, SQLi, XSS, Cloud Security, DoS testing autorizado, phishing sim autorizado.
