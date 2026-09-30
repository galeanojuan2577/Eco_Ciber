#!/bin/bash

# ============================================================
#  BBRecon - Bug Bounty Recon Automation Tool
#  Autor: Parable (AI Agent)
#  Versión: 2.0
#  Descripción: Reconocimiento completo para Bug Bounty
# ============================================================

set -e  # Salir si hay error crítico

# --- COLORES ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # Sin color

# --- CONFIGURACIÓN ---
THREADS=100
TIMEOUT=10
RESOLVERS="1.1.1.1,8.8.8.8"
RATE_LIMIT=20

# --- VARIABLES GLOBALES ---
DOMAINS_FILE=""
URLS_FILE=""
IPS_FILE=""
OUTPUT_DIR=""
TARGET_NAME=""

# --- FUNCIONES ---

usage() {
    echo -e "${WHITE}BBRecon - Bug Bounty Recon Automation${NC}"
    echo ""
    echo -e "${CYAN}Uso:${NC} $0 [opciones]"
    echo ""
    echo -e "${YELLOW}Opciones:${NC}"
    echo "  -d, --domain <dominio>     Dominio principal (ej: example.com)"
    echo "  -f, --file <archivo>       Archivo con lista de dominios (uno por línea)"
    echo "  -u, --urls <archivo>       Archivo con URLs adicionales (uno por línea)"
    echo "  -i, --ips <archivo>        Archivo con IPs adicionales (uno por línea)"
    echo "  -o, --output <directorio>  Directorio de salida (por defecto: Recon_<dominio>_fecha)"
    echo "  -t, --threads <num>        Número de hilos (por defecto: 100)"
    echo "  -h, --help                 Mostrar esta ayuda"
    echo ""
    echo -e "${YELLOW}Ejemplos:${NC}"
    echo "  $0 -d example.com"
    echo "  $0 -d example.com -u urls.txt -i ips.txt"
    echo "  $0 -f dominios.txt -o Recon_multi"
    echo ""
    exit 0
}

# --- FUNCIONES DE LOGGING ---
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

# --- FUNCIONES DE VERIFICACIÓN ---
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        log_error "La herramienta '$1' no está instalada."
        return 1
    fi
    return 0
}

check_go_path() {
    if ! echo "$PATH" | grep -q "$(go env GOPATH)/bin"; then
        export PATH=$PATH:$(go env GOPATH)/bin
        log_info "Añadido $(go env GOPATH)/bin al PATH"
    fi
}

# --- FUNCIONES PRINCIPALES ---

# 1. ENUMERACIÓN DE SUBDOMINIOS
enumerate_subdomains() {
    local domain="$1"
    local outdir="$2"
    
    log_section "ENUMERACIÓN DE SUBDOMINIOS para $domain"
    
    # Herramientas pasivas
    log_info "Subfinder (pasivo)..."
    subfinder -d "$domain" -all -silent -o "$outdir/subfinder.txt" 2>/dev/null || true
    
    log_info "Amass (pasivo)..."
    amass enum -passive -d "$domain" -o "$outdir/amass_passive.txt" 2>/dev/null || true
    
    log_info "Assetfinder..."
    assetfinder --subs-only "$domain" > "$outdir/assetfinder.txt" 2>/dev/null || true
    
    # Herramientas activas (si el usuario permite)
    log_info "Chaos (ProjectDiscovery) - requiere API key..."
    # chaos -d "$domain" -silent -o "$outdir/chaos.txt" 2>/dev/null || true
    
    # Unir y deduplicar
    cat "$outdir"/*.txt 2>/dev/null | sort -u | grep -v '^$' > "$outdir/all_subs.txt"
    local count=$(wc -l < "$outdir/all_subs.txt")
    log_success "Subdominios encontrados: $count"
    
    # Resolver DNS y filtrar subdominios vivos (opcional, se hará después)
}

# 2. PROBING HTTP/HTTPS
probe_http() {
    local subs_file="$1"
    local outfile="$2"
    
    log_section "PROBANDO SUBDOMINIOS VIVOS"
    
    if [ ! -s "$subs_file" ]; then
        log_warn "No hay subdominios para probar."
        return 1
    fi
    
    log_info "Usando httpx con $THREADS hilos..."
    cat "$subs_file" | httpx -silent -status-code -title -tech-detect -web-server -follow-redirects -threads "$THREADS" -timeout "$TIMEOUT" -o "$outfile" 2>/dev/null || true
    
    local count=$(wc -l < "$outfile")
    log_success "Hosts vivos encontrados: $count"
}

# 3. ESCANEO DE PUERTOS (Naabu + Nmap)
scan_ports() {
    local hosts_file="$1"
    local outdir="$2"
    
    log_section "ESCANEO DE PUERTOS"
    
    # Limpiar hosts para naabu
    sed -E 's#https?://##' "$hosts_file" | sort -u > "$outdir/hosts_clean.txt"
    
    log_info "Naabu (top 100 puertos)..."
    naabu -list "$outdir/hosts_clean.txt" -top-ports 100 -silent -verify -rate "$RATE_LIMIT" -o "$outdir/naabu_open.txt" 2>/dev/null || true
    
    # Extraer puertos abiertos para Nmap
    local open_ports=$(awk -F':' '{print $2}' "$outdir/naabu_open.txt" | sort -u | paste -sd, -)
    if [ -n "$open_ports" ]; then
        log_info "Nmap (detección de servicios)..."
        while IFS= read -r host; do
            nmap -p "$open_ports" -sV -sC -T4 -Pn "$host" -oN "$outdir/nmap_${host}.txt" 2>/dev/null || true
        done < "$outdir/hosts_clean.txt"
        log_success "Escaneo Nmap completado."
    else
        log_warn "No se encontraron puertos abiertos."
    fi
}

# 4. CRAWLING Y RECOPILACIÓN DE URLs
crawl_urls() {
    local domain="$1"
    local hosts_file="$2"
    local outdir="$3"
    
    log_section "CRAWLING Y RECOPILACIÓN DE URLs"
    
    # Pasivo
    log_info "Gau (Wayback, AlienVault, Common Crawl)..."
    echo "$domain" | gau --threads 10 -o "$outdir/gau_urls.txt" 2>/dev/null || true
    
    log_info "Waybackurls..."
    echo "$domain" | waybackurls > "$outdir/wayback_urls.txt" 2>/dev/null || true
    
    # Activo (solo primeros 5 hosts vivos)
    if [ -s "$hosts_file" ]; then
        log_info "Katana (crawling activo)..."
        head -n 5 "$hosts_file" | while read -r url; do
            katana -u "$url" -silent -d 3 -jc -kf all -o "$outdir/katana_$(echo "$url" | sed 's#https\?://##' | tr '/' '_').txt" 2>/dev/null || true
        done
    fi
    
    # Unir y filtrar
    cat "$outdir"/*.txt 2>/dev/null | sort -u > "$outdir/all_urls.txt"
    log_info "URLs totales: $(wc -l < "$outdir/all_urls.txt")"
    
    # Filtrar por extensiones valiosas
    grep -E '\.js$|\.json$|\.xml$|\.yaml$|\.yml$|\.env$|\.config$|\.sql$|\.bak$|/api/|/v[0-9]/|/graphql|/swagger|/docs|/admin|/login|/upload' "$outdir/all_urls.txt" > "$outdir/interesting_urls.txt"
    log_success "URLs interesantes: $(wc -l < "$outdir/interesting_urls.txt")"
}

# 5. TECNOLOGÍAS Y CAPTURAS
tech_and_screenshots() {
    local hosts_file="$1"
    local outdir="$2"
    
    log_section "TECNOLOGÍAS Y CAPTURAS"
    
    # Extraer tecnologías del httpx
    if [ -s "$hosts_file" ]; then
        log_info "Extrayendo tecnologías detectadas..."
        awk -F'\t' '{print $1 "\t" $NF}' "$hosts_file" | grep -i "tech" | sed 's/.*tech-detect://' > "$outdir/technologies.txt" 2>/dev/null || true
    fi
    
    # Aquatone (si está instalado)
    if command -v aquatone &> /dev/null && [ -s "$hosts_file" ]; then
        log_info "Aquatone (capturas de pantalla)..."
        cat "$hosts_file" | aquatone -out "$outdir/screenshots" -silent 2>/dev/null || true
    else
        log_warn "Aquatone no instalado o sin hosts vivos."
    fi
}

# 6. GENERACIÓN DE INFORME
generate_report() {
    local outdir="$1"
    local domain="$2"
    
    log_section "GENERANDO INFORME"
    
    local total_subs=$(wc -l < "$outdir/subdomains/all_subs.txt" 2>/dev/null || echo 0)
    local total_live=$(wc -l < "$outdir/subdomains/live_hosts.txt" 2>/dev/null || echo 0)
    local total_urls=$(wc -l < "$outdir/urls/all_urls.txt" 2>/dev/null || echo 0)
    local total_interesting=$(wc -l < "$outdir/urls/interesting_urls.txt" 2>/dev/null || echo 0)
    local total_ports=$(wc -l < "$outdir/ports/naabu_open.txt" 2>/dev/null || echo 0)
    
    cat > "$outdir/README.txt" <<EOF
========================================
  INFORME DE RECONOCIMIENTO
========================================
Dominio/Objetivo: $domain
Fecha: $(date)

RESULTADOS:
- Subdominios encontrados: $total_subs
- Hosts vivos (HTTP/HTTPS): $total_live
- Puertos abiertos detectados: $total_ports
- URLs totales recopiladas: $total_urls
- URLs interesantes (JS, API, etc.): $total_interesting

ARCHIVOS GENERADOS:
- Subdominios: subdomains/
- URLs: urls/
- Puertos: ports/
- Tecnologías: technologies.txt
- Screenshots: screenshots/

PRÓXIMOS PASOS:
1. Revisa hosts vivos: subdomains/live_hosts.txt
2. Analiza URLs interesantes: urls/interesting_urls.txt
3. Escanea con Nuclei:
   nuclei -l subdomains/live_hosts.txt -severity critical,high -rl 20 -c 10 -bs 20 -timeout 5 -retries 0 -silent -no-color -update-templates -o nuclei_results.txt
4. Busca parámetros con Arjun o ParamSpider
5. Revisa puertos abiertos para servicios no estándar

COMANDOS ÚTILES:
- Extraer dominios únicos: cat subdomains/all_subs.txt | cut -d'.' -f1 | sort -u
- Buscar archivos .env: cat urls/all_urls.txt | grep '.env'
- Buscar palabras clave: cat urls/all_urls.txt | grep -E 'admin|api|auth|login'

EOF
    
    log_success "Informe generado en: $outdir/README.txt"
}

# --- FUNCIÓN PRINCIPAL ---

main() {
    # --- PROCESAR ARGUMENTOS ---
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -f|--file)
                DOMAINS_FILE="$2"
                shift 2
                ;;
            -u|--urls)
                URLS_FILE="$2"
                shift 2
                ;;
            -i|--ips)
                IPS_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Opción desconocida: $1"
                usage
                ;;
        esac
    done

    # --- VALIDAR ARGUMENTOS ---
    if [[ -z "$DOMAIN" && -z "$DOMAINS_FILE" ]]; then
        log_error "Debes proporcionar un dominio con -d o un archivo con -f."
        usage
    fi

    # --- VERIFICAR HERRAMIENTAS ---
    check_go_path
    
    local missing_tools=()
    for tool in subfinder amass assetfinder httpx naabu katana gau waybackurls; do
        if ! check_tool "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Las siguientes herramientas no están instaladas: ${missing_tools[*]}"
        log_info "Instálalas con:"
        echo "  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        echo "  go install -v github.com/owasp-amass/amass/v4/...@master"
        echo "  go install -v github.com/tomnomnom/assetfinder@latest"
        echo "  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
        echo "  go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        echo "  go install -v github.com/projectdiscovery/katana/cmd/katana@latest"
        echo "  go install -v github.com/lc/gau/v2/cmd/gau@latest"
        echo "  go install -v github.com/tomnomnom/waybackurls@latest"
        exit 1
    fi

    # --- CONFIGURAR DIRECTORIO DE SALIDA ---
    if [[ -z "$OUTPUT_DIR" ]]; then
        if [[ -n "$DOMAIN" ]]; then
            OUTPUT_DIR="Recon_${DOMAIN}_$(date +%Y-%m-%d_%H-%M)"
        else
            OUTPUT_DIR="Recon_multi_$(date +%Y-%m-%d_%H-%M)"
        fi
    fi

    mkdir -p "$OUTPUT_DIR"

    # --- CREAR ESTRUCTURA DE CARPETAS ---
    mkdir -p "$OUTPUT_DIR/subdomains"
    mkdir -p "$OUTPUT_DIR/urls"
    mkdir -p "$OUTPUT_DIR/ports"
    mkdir -p "$OUTPUT_DIR/screenshots"

    # --- PROCESAR DOMINIOS ---
    local all_domains_file="$OUTPUT_DIR/all_domains.txt"
    if [[ -n "$DOMAINS_FILE" ]]; then
        cp "$DOMAINS_FILE" "$all_domains_file"
    else
        echo "$DOMAIN" > "$all_domains_file"
    fi

    # --- RECONOCIMIENTO PARA CADA DOMINIO ---
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        
        log_section "RECONOCIMIENTO PARA: $domain"
        
        # 1. Subdominios
        enumerate_subdomains "$domain" "$OUTPUT_DIR/subdomains"
        
        # 2. Probar subdominios vivos
        probe_http "$OUTPUT_DIR/subdomains/all_subs.txt" "$OUTPUT_DIR/subdomains/live_hosts.txt"
        
        # 3. Escanear puertos (si hay hosts vivos)
        if [ -s "$OUTPUT_DIR/subdomains/live_hosts.txt" ]; then
            scan_ports "$OUTPUT_DIR/subdomains/live_hosts.txt" "$OUTPUT_DIR/ports"
        fi
        
        # 4. Crawling y URLs
        crawl_urls "$domain" "$OUTPUT_DIR/subdomains/live_hosts.txt" "$OUTPUT_DIR/urls"
        
        # 5. Tecnologías y capturas
        tech_and_screenshots "$OUTPUT_DIR/subdomains/live_hosts.txt" "$OUTPUT_DIR"
        
    done < "$all_domains_file"

    # --- PROCESAR URLs ADICIONALES ---
    if [[ -n "$URLS_FILE" ]]; then
        log_section "PROCESANDO URLs ADICIONALES"
        mkdir -p "$OUTPUT_DIR/urls_extra"
        cp "$URLS_FILE" "$OUTPUT_DIR/urls_extra/urls_extra.txt"
        
        # Probar las URLs con httpx
        log_info "Probando URLs adicionales..."
        cat "$URLS_FILE" | httpx -silent -status-code -title -tech-detect -web-server -follow-redirects -threads "$THREADS" -timeout "$TIMEOUT" -o "$OUTPUT_DIR/urls_extra/live_extra.txt" 2>/dev/null || true
    fi

    # --- PROCESAR IPs ADICIONALES ---
    if [[ -n "$IPS_FILE" ]]; then
        log_section "PROCESANDO IPs ADICIONALES"
        mkdir -p "$OUTPUT_DIR/ips_extra"
        cp "$IPS_FILE" "$OUTPUT_DIR/ips_extra/ips_extra.txt"
        
        # Escaneo de puertos con Naabu para IPs
        log_info "Escaneando puertos en IPs adicionales..."
        naabu -list "$IPS_FILE" -top-ports 100 -silent -verify -rate "$RATE_LIMIT" -o "$OUTPUT_DIR/ips_extra/naabu_ips.txt" 2>/dev/null || true
        
        # Nmap sobre IPs con puertos abiertos
        local open_ports_ips=$(awk -F':' '{print $2}' "$OUTPUT_DIR/ips_extra/naabu_ips.txt" | sort -u | paste -sd, -)
        if [ -n "$open_ports_ips" ]; then
            log_info "Nmap para IPs..."
            while IFS= read -r ip; do
                nmap -p "$open_ports_ips" -sV -sC -T4 -Pn "$ip" -oN "$OUTPUT_DIR/ips_extra/nmap_${ip}.txt" 2>/dev/null || true
            done < "$IPS_FILE"
        fi
    fi

    # --- GENERAR INFORME FINAL ---
    if [[ -n "$DOMAIN" ]]; then
        generate_report "$OUTPUT_DIR" "$DOMAIN"
    else
        generate_report "$OUTPUT_DIR" "Múltiples dominios desde $DOMAINS_FILE"
    fi

    # --- RESUMEN FINAL ---
    log_section "RESUMEN FINAL"
    log_success "Reconocimiento completado."
    log_info "Resultados guardados en: $OUTPUT_DIR"
    log_info "Informe detallado: $OUTPUT_DIR/README.txt"
    
    # Mostrar estadísticas rápidas
    echo ""
    echo -e "${YELLOW}Estadísticas:${NC}"
    echo -e "  Subdominios totales: $(wc -l < "$OUTPUT_DIR/subdomains/all_subs.txt" 2>/dev/null || echo 0)"
    echo -e "  Hosts vivos: $(wc -l < "$OUTPUT_DIR/subdomains/live_hosts.txt" 2>/dev/null || echo 0)"
    echo -e "  URLs recopiladas: $(wc -l < "$OUTPUT_DIR/urls/all_urls.txt" 2>/dev/null || echo 0)"
    echo -e "  URLs interesantes: $(wc -l < "$OUTPUT_DIR/urls/interesting_urls.txt" 2>/dev/null || echo 0)"
    echo -e "  Puertos abiertos: $(wc -l < "$OUTPUT_DIR/ports/naabu_open.txt" 2>/dev/null || echo 0)"
    echo ""
    echo -e "${GREEN}¡Listo para la Fase 2!${NC}"
}

# --- EJECUCIÓN ---
main "$@"
