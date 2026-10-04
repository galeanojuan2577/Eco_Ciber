#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║                    RECON_PRO v5.0                               ║
# ║         Framework Profesional de Reconocimiento                ║
# ║         45 Herramientas · 3 Niveles · Bug Bounty Ready        ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════
# COLORES
# ═══════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════
# CONFIGURACION POR DEFECTO
# ═══════════════════════════════════════════════════════════════════
VERSION="5.0"
THREADS=100
TIMEOUT=10
LEVEL=1
OUTPUT_DIR=""
WORDLIST=""
QUIET=false
RESOLVERS="1.1.1.1,8.8.8.8,8.8.4.4"
RATE_LIMIT=1000
MASSCAN_RATE=5000
NMAP_TIMING="-T4"
# Puertos web que httpx debe sondear ademas de 80/443 (sin esto, un
# servicio en 8080/3000/8000 pasaba desapercibido en targets IP)
HTTPX_PORTS="80,443,8080,8443,8000,3000,5000,8888"
FORCE=false

# Integracion ECC: gate de autorizacion (check-scope.sh) + audit.log
ECC_MODE=false
ECC_TOOLS="${OPENCODE_ROOT:-$HOME/.config/opencode}/tools"

# Nuevas herramientas config
KATANA_DEPTH=3
KATANA_TIMEOUT=30
WAYBACK_TIMEOUT=20
NUCLEI_SEVERITY="critical,high,medium,low"
NUCLEI_RATE=150
WAF_TIMEOUT=10

# Wordlist por defecto (seclists)
WORDLIST_DEFAULT="/usr/share/seclists/Discovery/Web-Content/common.txt"
WORDLIST_MEDIUM="/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
WORDLIST_LARGE="/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt"

# Variables globales
TARGET=""
TARGET_TYPE=""
BASE_DOMAIN=""
START_TIME=$(date +%s)
LOG_FILE=""
REPORT_FILE=""

# ═══════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════
show_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'

  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗██╗   ██╗██╗  ████████╗███████╗
  ██╔══██╗██╔════╝██╔═══██╗██╔══██╗████╗ ████║██║   ██║██║  ╚══██╔══╝██╔════╝
  ██████╔╝█████╗  ██║   ██║██████╔╝██╔████╔██║██║   ██║██║     ██║   ███████╗
  ██╔══██╗██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║██║   ██║██║     ██║   ╚════██║
  ██║  ██║███████╗╚██████╔╝██║  ██║██║ ╚═╝ ██║╚██████╔╝███████╗██║   ███████║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚══════╝

BANNER
    echo -e "${WHITE}  v${VERSION} · 45 Herramientas · 3 Niveles · Bug Bounty Ready${NC}"
    echo -e "${DIM}  ECS · Ecosistema de Ciberseguridad${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
# FUNCIONES DE LOGGING
# ═══════════════════════════════════════════════════════════════════
log() {
    echo -e "${GREEN}[+]${NC} $1"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] [+] $1" >> "$LOG_FILE" 2>/dev/null || true
}
warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] [!] $1" >> "$LOG_FILE" 2>/dev/null || true
}
error() {
    echo -e "${RED}[✗]${NC} $1"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] [✗] $1" >> "$LOG_FILE" 2>/dev/null || true
}
success() {
    echo -e "${MAGENTA}[✓]${NC} $1"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] [✓] $1" >> "$LOG_FILE" 2>/dev/null || true
}
info() {
    echo -e "${CYAN}[i]${NC} $1"
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] [i] $1" >> "$LOG_FILE" 2>/dev/null || true
}

section() {
    local msg="$1"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}$msg${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    [[ -n "$LOG_FILE" ]] && echo "[$(date +%H:%M:%S)] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

subsection() {
    echo -e "${BLUE}  ├─${NC} $1"
}

# ═══════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════
check_tool() {
    command -v "$1" &>/dev/null
}

detect_target_type() {
    local t="$1"
    if [[ "$t" == "*" ]] || [[ "$t" == "*."* ]]; then
        TARGET_TYPE="wildcard"
        BASE_DOMAIN=$(echo "$t" | sed 's/^\*\.//')
    elif [[ "$t" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        TARGET_TYPE="ipv4"
        BASE_DOMAIN="$t"
    elif [[ "$t" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$t" == *":"* ]]; then
        TARGET_TYPE="ipv6"
        BASE_DOMAIN="$t"
    elif [[ "$t" =~ ^https?:// ]]; then
        TARGET_TYPE="url"
        TARGET=$(echo "$t" | sed -E 's|^https?://||;s|/.*||')
        BASE_DOMAIN="$TARGET"
    else
        TARGET_TYPE="domain"
        BASE_DOMAIN="$t"
    fi
}

count_lines() {
    local f="$1"
    if [[ -f "$f" ]]; then
        wc -l < "$f" | tr -d ' '
    else
        echo "0"
    fi
}

elapsed() {
    local now=$(date +%s)
    echo $(( now - START_TIME ))
}

human_time() {
    local secs=$1
    local mins=$(( secs / 60 ))
    local secs=$(( secs % 60 ))
    if [[ $mins -gt 0 ]]; then
        echo "${mins}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# USO
# ═══════════════════════════════════════════════════════════════════
usage() {
    cat << EOF
${WHITE}RECON_PRO v${VERSION} - Framework de Reconocimiento Profesional${NC}

${CYAN}Uso:${NC}
  \$0 <target> [opciones]

${CYAN}Targets:${NC}
  <target>          Dominio, IP, URL, o * (wildcard bug bounty)
  <target>          "example.com"   -> dominio
  <target>          "203.0.113.5"   -> IP
  <target>          "http://url"    -> URL
  <target>          "*"             -> todos los dominios en scope

${CYAN}Opciones:${NC}
  -l, --level <1-3>     Nivel de profundidad (default: 1)
                          1 = Rapido (5-15 min)
                          2 = Normal (15-45 min)
                          3 = Profundo (1-3 horas)
  -t, --threads <num>   Hilos concurrentes (default: 100)
  -o, --output <dir>    Directorio de salida
  -w, --wordlist <file>  Wordlist para fuzzing/direccion
  -q, --quiet           Modo silencioso (solo output)
  -e, --ecc             Integracion ECC: gate check-scope + registro en audit.log
  -f, --force           Sobreescribir directorio existente (con --ecc, fuerza la
                        autorizacion fuera de scope tras confirmarla)
  -h, --help            Mostrar esta ayuda

${CYAN}Ejemplos:${NC}
  \$0 example.com                           # Recon rapido
  \$0 example.com -l 2                      # Nivel normal
  \$0 203.0.113.5 -l 3 -t 50               # IP, nivel profundo
  \$0 "*" -l 2                              # Bug bounty, todos los targets
  \$0 example.com -w /usr/share/wordlists/dirb/common.txt

EOF
    exit 0
}

# ═══════════════════════════════════════════════════════════════════
# INTERFAZ INTERACTIVA
# ═══════════════════════════════════════════════════════════════════
clear_screen() {
    clear
}

print_header() {
    echo -e "${CYAN}"
    echo "  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗██╗   ██╗██╗  ████████╗███████╗"
    echo "  ██╔══██╗██╔════╝██╔═══██╗██╔══██╗████╗ ████║██║   ██║██║  ╚══██╔══╝██╔════╝"
    echo "  ██████╔╝█████╗  ██║   ██║██████╔╝██╔████╔██║██║   ██║██║     ██║   ███████╗"
    echo "  ██╔══██╗██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║██║   ██║██║     ██║   ╚════██║"
    echo "  ██║  ██║███████╗╚██████╔╝██║  ██║██║ ╚═╝ ██║╚██████╔╝███████╗██║   ███████║"
    echo "  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚══════╝"
    echo -e "${NC}"
    echo -e "  ${WHITE}v${VERSION} · 45 Herramientas · 3 Niveles · Bug Bounty Ready${NC}"
    echo -e "${DIM}  ECS · Ecosistema de Ciberseguridad${NC}"
    echo ""
}

print_menu() {
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}                    ${WHITE}PANEL DE CONTROL${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}  ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}  ║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}[1]${NC} ${WHITE}Target${NC}           ${DIM}URL, IP, Dominio o *${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}[2]${NC} ${WHITE}Nivel${NC}            ${DIM}1= Rapido | 2= Normal | 3= Profundo${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}[3]${NC} ${WHITE}Hilos${NC}            ${DIM}Concurrentes (default: 100)${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}[4]${NC} ${WHITE}Wordlist${NC}         ${DIM}Ruta para fuzzing/direcciones${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}[5]${NC} ${WHITE}Output${NC}           ${DIM}Directorio de salida${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${YELLOW}[A]${NC} ${WHITE}RECON RAPIDO${NC}     ${DIM}Nivel 1, defaults automaticos${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${YELLOW}[B]${NC} ${WHITE}RECON NORMAL${NC}     ${DIM}Nivel 2, todo habilitado${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${YELLOW}[C]${NC} ${WHITE}RECON PROFUNDO${NC}   ${DIM}Nivel 3, todas las herramientas${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${MAGENTA}[*]${NC} ${WHITE}BUG BOUNTY${NC}       ${DIM}Wildcard, todos los targets en scope${NC}   ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${RED}[X]${NC} ${WHITE}Salir${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_config() {
    echo -e "  ${CYAN}── Configuracion Actual ──────────────────────────────────────${NC}"
    echo -e "  ${CYAN}│${NC}  Target:    ${WHITE}${TARGET:-${DIM}(no definido)${NC}${WHITE}}${NC}"
    echo -e "  ${CYAN}│${NC}  Nivel:     ${WHITE}${LEVEL}${NC} ${DIM}($([ $LEVEL -eq 1 ] && echo 'Rapido' || ([ $LEVEL -eq 2 ] && echo 'Normal' || echo 'Profundo')))${NC}"
    echo -e "  ${CYAN}│${NC}  Hilos:     ${WHITE}${THREADS}${NC}"
    echo -e "  ${CYAN}│${NC}  Wordlist:  ${WHITE}${WORDLIST:-${DIM}(auto)${NC}${WHITE}}${NC}"
    echo -e "  ${CYAN}│${NC}  Output:    ${WHITE}${OUTPUT_DIR:-${DIM}(auto)${NC}${WHITE}}${NC}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────${NC}"
    echo ""
}

interactive_menu() {
    local INPUT_TARGET=""
    local INPUT_LEVEL=1
    local INPUT_THREADS=100
    local INPUT_WORDLIST=""
    local INPUT_OUTPUT=""

    while true; do
        clear_screen
        print_header
        print_menu
        
        # Mostrar configuracion actual
        TARGET="$INPUT_TARGET"
        LEVEL="$INPUT_LEVEL"
        THREADS="$INPUT_THREADS"
        WORDLIST="$INPUT_WORDLIST"
        OUTPUT_DIR="$INPUT_OUTPUT"
        print_config

        echo -ne "  ${GREEN}Selecciona una opcion: ${NC}"
        read -r choice

        case "${choice^^}" in
            1)
                echo ""
                echo -ne "  ${CYAN}Ingresa el target (URL/IP/Dominio): ${NC}"
                read -r INPUT_TARGET
                ;;
            2)
                echo ""
                echo -e "  ${CYAN}Selecciona el nivel:${NC}"
                echo -e "  ${GREEN}[1]${NC} Rapido (5-15 min) - whois, dig, subfinder, httpx, whatweb, masscan"
                echo -e "  ${GREEN}[2]${NC} Normal (15-45 min) - + amass, nmap, gobuster, nikto, nuclei"
                echo -e "  ${GREEN}[3]${NC} Profundo (1-3h) - + ffuf, wfuzz, arjun, sqlmap, theHarvester"
                echo -ne "  ${GREEN}Nivel [1-3]: ${NC}"
                read -r input
                if [[ "$input" =~ ^[123]$ ]]; then
                    INPUT_LEVEL="$input"
                fi
                ;;
            3)
                echo ""
                echo -ne "  ${CYAN}Numero de hilos (default 100): ${NC}"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -gt 0 ]]; then
                    INPUT_THREADS="$input"
                fi
                ;;
            4)
                echo ""
                echo -e "  ${CYAN}Wordlists disponibles:${NC}"
                local wl_idx=1
                local wl_list=()
                for wl in \
                    "$WORDLIST_DEFAULT" \
                    "$WORDLIST_MEDIUM" \
                    "$WORDLIST_LARGE" \
                    "/usr/share/wordlists/dirb/common.txt" \
                    "/usr/share/dirbuster/wordlists/directory-list-2.3-small.txt" \
                    "/usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt"; do
                    if [[ -f "$wl" ]]; then
                        local size
                        size=$(wc -l < "$wl" | tr -d ' ')
                        echo -e "  ${GREEN}[$wl_idx]${NC} $wl ${DIM}($size lineas)${NC}"
                        wl_list+=("$wl")
                        ((wl_idx++)) || true
                    fi
                done
                echo -e "  ${GREEN}[0]${NC} Auto (segun nivel)"
                echo -ne "  ${GREEN}Selecciona [0-$((wl_idx-1))]: ${NC}"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 0 ]] && [[ "$input" -lt "$wl_idx" ]]; then
                    if [[ "$input" -eq 0 ]]; then
                        INPUT_WORDLIST=""
                    else
                        INPUT_WORDLIST="${wl_list[$((input-1))]}"
                    fi
                fi
                ;;
            5)
                echo ""
                echo -ne "  ${CYAN}Directorio de salida (vacio=auto): ${NC}"
                read -r INPUT_OUTPUT
                ;;
            A)
                if [[ -z "$INPUT_TARGET" ]]; then
                    echo -ne "  ${RED}Primero define un target (opcion 1): ${NC}"
                    read -r
                    continue
                fi
                LEVEL=1
                THREADS="$INPUT_THREADS"
                OUTPUT_DIR="$INPUT_OUTPUT"
                TARGET="$INPUT_TARGET"
                WORDLIST="$INPUT_WORDLIST"
                return 0
                ;;
            B)
                if [[ -z "$INPUT_TARGET" ]]; then
                    echo -ne "  ${RED}Primero define un target (opcion 1): ${NC}"
                    read -r
                    continue
                fi
                LEVEL=2
                THREADS="$INPUT_THREADS"
                OUTPUT_DIR="$INPUT_OUTPUT"
                TARGET="$INPUT_TARGET"
                WORDLIST="$INPUT_WORDLIST"
                return 0
                ;;
            C)
                if [[ -z "$INPUT_TARGET" ]]; then
                    echo -ne "  ${RED}Primero define un target (opcion 1): ${NC}"
                    read -r
                    continue
                fi
                LEVEL=3
                THREADS="$INPUT_THREADS"
                OUTPUT_DIR="$INPUT_OUTPUT"
                TARGET="$INPUT_TARGET"
                WORDLIST="$INPUT_WORDLIST"
                return 0
                ;;
            "*")
                TARGET="*"
                LEVEL="${INPUT_LEVEL}"
                THREADS="$INPUT_THREADS"
                OUTPUT_DIR="$INPUT_OUTPUT"
                WORDLIST="$INPUT_WORDLIST"
                return 0
                ;;
            X|Q)
                echo -e "\n  ${YELLOW}Saliendo...${NC}"
                exit 0
                ;;
            "")
                # Enter sin nada = ejecutar con config actual
                if [[ -n "$INPUT_TARGET" ]]; then
                    LEVEL="$INPUT_LEVEL"
                    THREADS="$INPUT_THREADS"
                    OUTPUT_DIR="$INPUT_OUTPUT"
                    TARGET="$INPUT_TARGET"
                    WORDLIST="$INPUT_WORDLIST"
                    return 0
                fi
                ;;
            *)
                echo -e "  ${RED}Opcion no valida.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════
# PARSEO DE ARGUMENTOS
# ═══════════════════════════════════════════════════════════════════
parse_args() {
    if [[ $# -eq 0 ]]; then
        interactive_menu
        return
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--level)
                LEVEL="$2"
                if [[ ! "$LEVEL" =~ ^[123]$ ]]; then
                    error "Nivel invalido. Usa 1, 2 o 3."
                    exit 1
                fi
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -w|--wordlist)
                WORDLIST="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -e|--ecc)
                ECC_MODE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                error "Opcion desconocida: $1"
                usage
                ;;
            *)
                if [[ -z "$TARGET" ]]; then
                    TARGET="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$TARGET" ]]; then
        error "Debes especificar un target."
        usage
    fi
}

# ═══════════════════════════════════════════════════════════════════
# INTEGRACION ECC (--ecc): gate de autorizacion + audit.log
# ═══════════════════════════════════════════════════════════════════
# Contrato de check-scope.sh:
#   0 = IN SCOPE      -> procede
#   1 = NEEDS CONFIRM -> preguntar al usuario (o -f tras confirmar)
#   2 = HARD DENY     -> target de OTRO proyecto, rechazo duro (no se fuerza)
#   3 = USAGE ERROR   -> falta registrar autorizacion
# ═══════════════════════════════════════════════════════════════════
ecc_audit() {
    local al="$ECC_TOOLS/audit-log.sh"
    [[ -f "$al" ]] || return 0
    bash "$al" "$@" >/dev/null 2>&1 || true
}

ecc_gate() {
    local target="$1" tipo="recon" rc=0
    local cs="$ECC_TOOLS/check-scope.sh"

    [[ -f "$cs" ]] || {
        error "check-scope.sh no encontrado: $cs"
        exit 1
    }

    info "Gate de autorizacion: check-scope.sh $target $tipo"
    if bash "$cs" "$target" "$tipo"; then
        rc=0
    else
        rc=$?
    fi

    case "$rc" in
        0)
            success "Scope verificado (exit=0)"
            ;;
        1)
            if [[ "$FORCE" == "true" ]]; then
                warn "Autorizacion fuera de scope / tipo no autorizado: se fuerza con -f (queda registrado)."
                bash "$cs" "$target" "$tipo" --force >/dev/null 2>&1 || true
                ecc_audit "recon FORCE-override target=$target nivel=$LEVEL (confirmado por usuario con -f)"
            elif [[ -t 0 ]]; then
                printf "%b" "${YELLOW}  ¿Confirmas por escrito que '$target' es legal, en scope y consentida? [s/N]: ${NC}"
                read -r ans || ans=""
                if [[ "$ans" =~ ^[sS] ]]; then
                    bash "$cs" "$target" "$tipo" --force >/dev/null 2>&1 || true
                    ecc_audit "recon FORCE-override target=$target nivel=$LEVEL (confirmado en terminal)"
                else
                    error "Autorizacion NO confirmada. Abortando sin ejecutar recon."
                    exit 1
                fi
            else
                error "check-scope exit=1: fuera de scope, autorizacion vencida o tipo no autorizado."
                error "Registra el target con:"
                error "  bash $ECC_TOOLS/authorize.sh init <programa_url>"
                error "  bash $ECC_TOOLS/authorize.sh add $target recon 7d"
                error "O reintroduce con -f DESPUES de confirmarlo explicitamente con el usuario."
                exit 1
            fi
            ;;
        2)
            error "check-scope exit=2: '$target' pertenece al scope de OTRO proyecto."
            error "Rechazo duro (aislamiento por proyecto). Cambia de proyecto con:"
            error "  bash $ECC_TOOLS/project-context.sh set <proyecto>"
            exit 1
            ;;
        *)
            error "check-scope exit=$rc: no se pudo validar la autorizacion."
            exit 1
            ;;
    esac

    ecc_audit "recon start target=$target tipo=$tipo nivel=$LEVEL"
}

# ═══════════════════════════════════════════════════════════════════
# VERIFICACION DE HERRAMIENTAS
# ═══════════════════════════════════════════════════════════════════
declare -A TOOL_STATUS

check_all_tools() {
    section "VERIFICACION DE HERRAMIENTAS"

    local tools=(
        whois dig dnsrecon fierce dnsenum enum4linux dnsx
        subfinder amass theHarvester
        httpx whatweb sslscan testssl wafw00f
        masscan nmap
        gobuster ffuf wfuzz arjun katana waybackurls gau
        nikto nuclei sqlmap
        shodan recon-ng
        curl wget hydra
    )

    local available=0
    local missing=0
    local missing_list=""

    for tool in "${tools[@]}"; do
        if check_tool "$tool"; then
            TOOL_STATUS["$tool"]="ok"
            ((available++)) || true
        else
            TOOL_STATUS["$tool"]="missing"
            ((missing++)) || true
            missing_list="$missing_list $tool"
        fi
    done

    info "Herramientas disponibles: $available/${#tools[@]}"

    if [[ $missing -gt 0 ]]; then
        warn "Herramientas faltantes:$missing_list"
        info "Algunas funcionalidades estaran limitadas."
    fi

    if [[ -z "$WORDLIST" ]]; then
        # Seleccionar wordlist segun nivel
        if [[ $LEVEL -eq 1 && -f "$WORDLIST_DEFAULT" ]]; then
            WORDLIST="$WORDLIST_DEFAULT"
        elif [[ $LEVEL -eq 2 && -f "$WORDLIST_MEDIUM" ]]; then
            WORDLIST="$WORDLIST_MEDIUM"
        elif [[ $LEVEL -eq 3 && -f "$WORDLIST_LARGE" ]]; then
            WORDLIST="$WORDLIST_LARGE"
        elif [[ -f "$WORDLIST_DEFAULT" ]]; then
            WORDLIST="$WORDLIST_DEFAULT"
        else
            local wl_candidates=(
                "/usr/share/seclists/Discovery/Web-Content/common.txt"
                "/usr/share/wordlists/dirb/common.txt"
                "/usr/share/dirbuster/wordlists/directory-list-2.3-small.txt"
                "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
            )
            for wl in "${wl_candidates[@]}"; do
                if [[ -f "$wl" ]]; then
                    WORDLIST="$wl"
                    break
                fi
            done
        fi
        info "Wordlist: $WORDLIST"
    fi

    if [[ -z "$WORDLIST" ]]; then
        warn "No se encontro wordlist. Instala seclists o dirb."
    fi
}

# ═══════════════════════════════════════════════════════════════════
# FASE 0: WHOIS / DNS BASICO
# ═══════════════════════════════════════════════════════════════════
phase_0_whois_dns() {
    local target="$1"
    local dns_target="$BASE_DOMAIN"
    local outdir="$OUTPUT_DIR/00-whois"
    mkdir -p "$outdir"

    section "FASE 0: WHOIS / DNS BASICO — $target"

    # WHOIS
    if [[ "${TOOL_STATUS[whois]:-missing}" == "ok" ]]; then
        subsection "WHOIS"
        whois "$dns_target" > "$outdir/whois.txt" 2>/dev/null || true
        grep -iE "^(Domain Name|Registry Expiry|Registrar|Name Server|Creation Date|Updated Date|Registrant)" \
            "$outdir/whois.txt" > "$outdir/whois_summary.txt" 2>/dev/null || true
        success "WHOIS completado"
    fi

    # DIG
    if [[ "${TOOL_STATUS[dig]:-missing}" == "ok" ]]; then
        subsection "Registros DNS (dig)"
        for record in A AAAA MX NS TXT SOA CNAME SRV CAA TLSA HTTPS SVCB; do
            dig +short "$dns_target" "$record" >> "$outdir/dns_${record}.txt" 2>/dev/null || true
            dig +short "$dns_target" "$record" >> "$outdir/dns_all.txt" 2>/dev/null || true
        done
        local ns
        ns=$(dig +short NS "$dns_target" 2>/dev/null | head -1 | tr -d '[:space:]')
        if [[ -n "$ns" ]]; then
            dig @"$ns" AXFR "$dns_target" > "$outdir/zone_transfer.txt" 2>/dev/null || true
            if grep -q "XFR size" "$outdir/zone_transfer.txt" 2>/dev/null; then
                warn "ZONE TRANSFER EXITOSO contra $ns"
                echo "ZONE_TRANSFER_SUCCESS: $ns" >> "$outdir/../../ALERTS.txt" 2>/dev/null || true
            fi
        fi
        # DNS over HTTPS como fallback
        subsection "DNS over HTTPS (DoH)"
        for record in A AAAA MX NS TXT; do
            curl -s "https://cloudflare-dns.com/dns-query?name=$dns_target&type=$record" \
                -H "accept: application/dns-json" 2>/dev/null | \
                python3 -c "import sys,json; d=json.load(sys.stdin); [print(a['data']) for a in d.get('Answer',[])]" \
                >> "$outdir/dns_doh_${record}.txt" 2>/dev/null || true
        done
        success "DNS dig completado"
    fi

    # DNSX (resolucion masiva)
    if [[ "${TOOL_STATUS[dnsx]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "dnsx (resolucion DNS masiva)"
        echo "$dns_target" | dnsx -silent -a -aaaa -ns -cname -mx -txt \
            -o "$outdir/dnsx_results.txt" 2>/dev/null || true
        info "dnsx completado"
    fi

    # DNSRECON
    if [[ "${TOOL_STATUS[dnsrecon]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "dnsrecon (bruteforce + zone transfer)"
        timeout 120 dnsrecon -d "$dns_target" -a -b > "$outdir/dnsrecon_full.txt" 2>/dev/null || true
        timeout 120 dnsrecon -d "$dns_target" --xml "$outdir/dnsrecon.xml" 2>/dev/null || true
        success "dnsrecon completado"
    fi

    # FIERCE
    if [[ "${TOOL_STATUS[fierce]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "fierce (DNS enumeration)"
        fierce --domain "$dns_target" 2>/dev/null | tee "$outdir/fierce_raw.txt" | \
            grep -oE "[a-zA-Z0-9._-]+\.$dns_target" | sort -u > "$outdir/fierce_subs.txt" 2>/dev/null || true
        success "fierce completado"
    fi

    # DNSENUM
    if [[ "${TOOL_STATUS[dnsenum]:-missing}" == "ok" ]]; then
        subsection "dnsenum"
        timeout 60 dnsenum --noreverse --enum "$dns_target" > "$outdir/dnsenum.txt" 2>/dev/null || true
        success "dnsenum completado"
    fi

    # ENUM4Linux
    if [[ "${TOOL_STATUS[enum4linux]:-missing}" == "ok" && "$TARGET_TYPE" == "domain" && $LEVEL -ge 2 ]]; then
        subsection "enum4linux (SMB/Domain)"
        enum4linux -a "$dns_target" > "$outdir/enum4linux.txt" 2>/dev/null || true
        success "enum4linux completado"
    fi

    # DNS inverso
    if [[ "$TARGET_TYPE" == "ipv4" || "$TARGET_TYPE" == "ipv6" ]]; then
        subsection "DNS inverso"
        dig +short -x "$target" > "$outdir/reverse_dns.txt" 2>/dev/null || true
        success "DNS inverso completado"
    fi

    # Guardar IPs resueltas del dominio base para uso en fases posteriores
    dig +short A "$dns_target" 2>/dev/null | grep -E '^[0-9]+\.' | sort -u > "$outdir/resolved_ips.txt" 2>/dev/null || true
    if [[ -s "$outdir/resolved_ips.txt" ]]; then
        local ip_count
        ip_count=$(count_lines "$outdir/resolved_ips.txt")
        info "IPs resueltas para $dns_target: $ip_count"
    fi

    success "Fase 0 completada"
}

# ═══════════════════════════════════════════════════════════════════
# FASE 1: ENUMERACION DE SUBDOMINIOS
# ═══════════════════════════════════════════════════════════════════
phase_1_subdomains() {
    local target="$1"
    local scan_domain="$BASE_DOMAIN"
    local outdir="$OUTPUT_DIR/01-subdomains"
    mkdir -p "$outdir"

    if [[ "$TARGET_TYPE" == "ipv4" || "$TARGET_TYPE" == "ipv6" ]]; then
        info "Target es IP, saltando enumeracion de subdominios."
        echo "$target" > "$outdir/all_subdomains.txt"
        return 0
    fi

    section "FASE 1: ENUMERACION DE SUBDOMINIOS — $target"

    # SUBFINDER
    if [[ "${TOOL_STATUS[subfinder]:-missing}" == "ok" ]]; then
        subsection "subfinder (pasivo)"
        subfinder -d "$scan_domain" -all -silent -o "$outdir/subfinder.txt" 2>/dev/null || true
        local count
        count=$(count_lines "$outdir/subfinder.txt")
        info "subfinder: $count subdominios"
    fi

    # AMASS pasivo
    if [[ "${TOOL_STATUS[amass]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "amass (pasivo)"
        timeout 300 amass enum -passive -d "$scan_domain" -o "$outdir/amass_passive.txt" 2>/dev/null || true
        local count
        count=$(count_lines "$outdir/amass_passive.txt")
        info "amass pasivo: $count subdominios"
    fi

    # AMASS activo nivel 3
    if [[ "${TOOL_STATUS[amass]:-missing}" == "ok" && $LEVEL -ge 3 ]]; then
        subsection "amass (activo -brute)"
        timeout 600 amass enum -active -brute -d "$scan_domain" -o "$outdir/amass_active.txt" 2>/dev/null || true
        local count
        count=$(count_lines "$outdir/amass_active.txt")
        info "amass activo: $count subdominios"
    fi

    # THEHARVESTER
    if [[ "${TOOL_STATUS[theHarvester]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "theHarvester (OSINT)"
        timeout 120 theHarvester -d "$scan_domain" -b all -f "$outdir/theharvester.html" 2>/dev/null || true
        grep -oE "[a-zA-Z0-9._-]+\.$scan_domain" "$outdir/theharvester.html" 2>/dev/null | sort -u > "$outdir/theharvester_subs.txt" || true
        info "theHarvester completado"
    fi

    # FIERCE
    if [[ "${TOOL_STATUS[fierce]:-missing}" == "ok" ]]; then
        subsection "fierce (brute DNS)"
        fierce --domain "$scan_domain" 2>/dev/null | grep -oE "[a-zA-Z0-9._-]+\.$scan_domain" | sort -u > "$outdir/fierce_subs.txt" 2>/dev/null || true
        info "fierce completado"
    fi

    # FUENTES WEB (level >= 2)
    if [[ $LEVEL -ge 2 ]]; then
        subsection "Fuentes web (hackertarget, anubis, leakix)"
        # hackertarget
        curl -s "https://api.hackertarget.com/hostsearch/?q=$scan_domain" 2>/dev/null | \
            cut -d',' -f1 | sort -u > "$outdir/hackertarget.txt" 2>/dev/null || true
        # anubis
        curl -s "https://jldc.me/anubis/subdomains/$scan_domain" 2>/dev/null | \
            python3 -c "import sys,json; [print(x) for x in json.load(sys.stdin)]" 2>/dev/null | \
            sort -u > "$outdir/anubis.txt" 2>/dev/null || true
        # leakix
        curl -s "https://leakix.net/api/subdomains/$scan_domain" 2>/dev/null | \
            python3 -c "import sys,json; [print(x.get('subdomain','')) for x in json.load(sys.stdin)]" 2>/dev/null | \
            sort -u > "$outdir/leakix.txt" 2>/dev/null || true
    fi

    # DNSENUM brute
    if [[ "${TOOL_STATUS[dnsenum]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "dnsenum (brute)"
        timeout 120 dnsenum --noreverse "$scan_domain" > "$outdir/dnsenum_subs.txt" 2>/dev/null || true
        grep -oE "[a-zA-Z0-9._-]+\.$scan_domain" "$outdir/dnsenum_subs.txt" 2>/dev/null | sort -u > "$outdir/dnsenum_extracted.txt" || true
        info "dnsenum completado"
    fi

    # CERTIFICATE TRANSPARENCY
    subsection "Certificate Transparency (crt.sh)"
    curl -s "https://crt.sh/?q=%25.${scan_domain}&output=json" 2>/dev/null | \
        python3 -c "import sys,json; [print(e['name_value']) for e in json.load(sys.stdin)]" 2>/dev/null | \
        sort -u > "$outdir/crtsh.txt" 2>/dev/null || true
    local crt_count
    crt_count=$(count_lines "$outdir/crtsh.txt")
    info "crt.sh: $crt_count subdominios"

    # UNION Y DEDUPLICACION
    subsection "Consolidando subdominios"
    cat "$outdir/subfinder.txt" \
        "$outdir/amass_passive.txt" \
        "$outdir/amass_active.txt" \
        "$outdir/theharvester_subs.txt" \
        "$outdir/fierce_subs.txt" \
        "$outdir/dnsenum_extracted.txt" \
        "$outdir/crtsh.txt" \
        "$outdir/hackertarget.txt" \
        "$outdir/anubis.txt" \
        "$outdir/leakix.txt" \
        2>/dev/null | sed 's/^\*\.//g' | sort -u | grep -v '^$' > "$outdir/all_subdomains.txt" || true

    local total
    total=$(count_lines "$outdir/all_subdomains.txt")
    success "Total subdominios unicos: $total"

    # Cap for fast levels so probing does not explode on large domains
    local cap=0
    if [[ $LEVEL -eq 1 ]]; then
        cap=400
    elif [[ $LEVEL -eq 2 ]]; then
        cap=1500
    fi
    if [[ $cap -gt 0 ]] && [[ $total -gt $cap ]]; then
        head -n "$cap" "$outdir/all_subdomains.txt" > "$outdir/all_subdomains.capped"
        mv "$outdir/all_subdomains.capped" "$outdir/all_subdomains.txt"
        info "Cap nivel $LEVEL: usando $cap de $total subdominios para probing"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# FASE 2: PROBING / TECNOLOGIA
# ═══════════════════════════════════════════════════════════════════
phase_2_probing() {
    local target="$1"
    local outdir="$OUTPUT_DIR/02-probing"
    mkdir -p "$outdir"

    section "FASE 2: PROBING / TECNOLOGIA — $target"

    local subs_file="$OUTPUT_DIR/01-subdomains/all_subdomains.txt"

    # HTTPX
    if [[ "${TOOL_STATUS[httpx]:-missing}" == "ok" && -s "$subs_file" ]]; then
        subsection "httpx (probing HTTP/HTTPS)"
        cat "$subs_file" | httpx \
            -silent \
            -p "$HTTPX_PORTS" \
            -sc \
            -title \
            -td \
            -server \
            -cl \
            -fr \
            -cdn \
            -ip \
            -t "$THREADS" \
            -timeout "$TIMEOUT" \
            -o "$outdir/httpx_live.txt" 2>/dev/null || true

        awk '{print $1}' "$outdir/httpx_live.txt" | grep -E '^https?://' > "$outdir/live_urls.txt" 2>/dev/null || true
        sed -E 's|https?://||;s|/.*||' "$outdir/live_urls.txt" | sort -u > "$outdir/live_hosts.txt" 2>/dev/null || true

        # Extraer IPs de httpx si están disponibles (formato [IP])
        grep -oE '\[[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\]' "$outdir/httpx_live.txt" | \
            tr -d '[]' | sort -u > "$outdir/live_ips.txt" 2>/dev/null || true

        local live
        live=$(count_lines "$outdir/live_urls.txt")
        info "Hosts vivos: $live"
    fi

    # WAFW00F
    if [[ "${TOOL_STATUS[wafw00f]:-missing}" == "ok" ]]; then
        subsection "wafw00f (deteccion WAF/CDN)"
        if [[ -s "$outdir/live_urls.txt" ]]; then
            : > "$outdir/waf_detection.txt"
            head -20 "$outdir/live_urls.txt" | while IFS= read -r url; do
                [[ -z "$url" ]] && continue
                local waf_result
                waf_result=$(wafw00f -s -t "$WAF_TIMEOUT" "$url" 2>/dev/null | grep -i "behind" || echo "No WAF")
                echo "$url -> $waf_result" >> "$outdir/waf_detection.txt"
            done
            info "wafw00f completado"
        fi
    fi

    # WHATWEB
    if [[ "${TOOL_STATUS[whatweb]:-missing}" == "ok" ]]; then
        subsection "whatweb (fingerprinting)"
        : > "$outdir/whatweb_raw.txt"
        # Fingerprintar cada URL viva: con -p httpx ya ha descubierto los
        # puertos web reales (8080, 3000...), mientras que -s sobre
        # $BASE_DOMAIN solo miraba el puerto 80 y devolvia vacio.
        if [[ -s "$outdir/live_urls.txt" ]]; then
            head -30 "$outdir/live_urls.txt" | while IFS= read -r url; do
                [[ -z "$url" ]] && continue
                whatweb --color=never -v -a 3 "$url" >> "$outdir/whatweb_raw.txt" 2>/dev/null || true
            done
        else
            whatweb --color=never -v -a 3 "$BASE_DOMAIN" > "$outdir/whatweb_raw.txt" 2>/dev/null || true
        fi
        grep -oE '\[.*?\]' "$outdir/whatweb_raw.txt" 2>/dev/null | sort -u > "$outdir/technologies.txt" || true
        info "whatweb completado: $(count_lines "$outdir/technologies.txt") tecnologias"
    fi

    # SSLSCAN
    if [[ "${TOOL_STATUS[sslscan]:-missing}" == "ok" ]]; then
        subsection "sslscan (analisis SSL/TLS)"
        sslscan "$BASE_DOMAIN" > "$outdir/sslscan.txt" 2>/dev/null || true
        grep -E "^(  SSL|  TLS|  Certificate|  Subject|  Issuer|  Expiry)" \
            "$outdir/sslscan.txt" > "$outdir/sslscan_summary.txt" 2>/dev/null || true
        info "sslscan completado"
    fi

    # TESTSSL nivel >= 2
    if [[ "${TOOL_STATUS[testssl]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "testssl (analisis SSL/TLS profundo)"
        timeout 120 testssl.sh --fast \
            -o "$outdir/testssl.json" \
            -S -p -U \
            "$BASE_DOMAIN" 2>/dev/null || true
        info "testssl completado"
    fi

    # TLS NEGOTIATION CHECK
    subsection "Verificacion HTTPS/TLS"
    for proto in tlsv1 tlsv1.1 tlsv1.2 tlsv1.3; do
        local result=""
        result=$(curl -s -o /dev/null -w "%{http_code}" --"${proto}" --max-time 5 "https://$BASE_DOMAIN" 2>/dev/null) || true
        if [[ -z "$result" || "$result" == "000" ]]; then
            result="FAIL"
        fi
        echo "$proto: $result" >> "$outdir/tls_protocols.txt"
    done
    info "TLS protocols verificados"

    success "Fase 2 completada"
}

# ═══════════════════════════════════════════════════════════════════
# FASE 3: ESCANEO DE PUERTOS
# ═══════════════════════════════════════════════════════════════════
# Ejecuta nmap tolerando la falta de privilegios.
# -sS (SYN scan) exige root: sin el, nmap aborta con "requires root
# privileges". El codigo original hacia `2>/dev/null || true`, asi que el
# fallo era invisible y TODO el escaneo de puertos salia vacio.
# -sT (connect scan) produce el mismo resultado sin privilegios.
nmap_run() {
    local errfile="$1"; shift
    local rc=0
    nmap "$@" 2>"$errfile" || rc=$?
    if [[ $rc -ne 0 ]]; then
        warn "nmap fallo (exit=$rc): $(head -2 "$errfile" 2>/dev/null | tr '\n' ' ')"
    fi
    return 0
}

phase_3_ports() {
    local target="$1"
    local outdir="$OUTPUT_DIR/03-ports"
    mkdir -p "$outdir"

    section "FASE 3: ESCANEO DE PUERTOS — $target"

    local hosts_file="$OUTPUT_DIR/02-probing/live_hosts.txt"
    local ips_file="$OUTPUT_DIR/02-probing/live_ips.txt"
    local resolved_ips="$OUTPUT_DIR/00-whois/resolved_ips.txt"

    # Construir lista de IPs para escanear
    local scan_targets_file="$outdir/scan_targets.txt"
    : > "$scan_targets_file"

    # Si el propio target es una IP, escanearla directamente. Sin este caso
    # la cadena DNS (live_ips > resolved_ips > dig) quedaba vacia y la fase 3
    # no escaneaba nada, reportando siempre "0 puertos".
    if [[ "$target" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "$target" >> "$scan_targets_file"
        info "Target IP: escaneo directo, sin resolucion DNS ($target)"
    fi

    # Prioridad: live_ips (confirmadas por httpx) > resolved_ips > dig hosts > dig dominio
    if [[ -s "$ips_file" ]]; then
        cat "$ips_file" >> "$scan_targets_file"
        info "Usando IPs confirmadas por httpx: $(count_lines "$ips_file")"
    fi
    if [[ ! -s "$scan_targets_file" && -s "$resolved_ips" ]]; then
        cat "$resolved_ips" >> "$scan_targets_file"
    fi
    if [[ ! -s "$scan_targets_file" && -s "$hosts_file" ]]; then
        while IFS= read -r host; do
            [[ -z "$host" ]] && continue
            local ip
            ip=$(dig +short A "$host" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
            [[ -n "$ip" ]] && echo "$ip" >> "$scan_targets_file"
        done < "$hosts_file"
    fi
    if [[ ! -s "$scan_targets_file" ]]; then
        dig +short A "$BASE_DOMAIN" 2>/dev/null | grep -E '^[0-9]+\.' >> "$scan_targets_file" || true
    fi

    sort -u "$scan_targets_file" -o "$scan_targets_file" 2>/dev/null || true
    local ip_count
    ip_count=$(count_lines "$scan_targets_file")
    info "IPs objetivo para escaneo: $ip_count"

    # MASSCAN
    if [[ "${TOOL_STATUS[masscan]:-missing}" == "ok" && -s "$scan_targets_file" ]]; then
        subsection "masscan (escaneo rapido masivo)"
        masscan -p1-10000 --rate="$MASSCAN_RATE" --wait 0 \
            -iL "$scan_targets_file" \
            --open -oJ "$outdir/masscan.json" \
            -oL "$outdir/masscan.list" 2>/dev/null || true
        if [[ -f "$outdir/masscan.list" ]]; then
            grep -v '^#' "$outdir/masscan.list" | awk '{print $3}' | sort -un > "$outdir/open_ports.txt" 2>/dev/null || true
            info "masscan completado"
        fi
    fi

    # NMAP
    if [[ "${TOOL_STATUS[nmap]:-missing}" == "ok" ]]; then
        subsection "nmap (deteccion de servicios y versiones)"
        local ports=""
        if [[ -s "$outdir/open_ports.txt" ]]; then
            ports=$(paste -sd, "$outdir/open_ports.txt")
        fi
        local nmap_targets=""
        if [[ -s "$scan_targets_file" ]]; then
            nmap_targets="-iL $scan_targets_file"
        else
            nmap_targets="$BASE_DOMAIN"
        fi

        local scan_type="-sT"
        if [[ "$(id -u)" -eq 0 ]]; then
            scan_type="-sS"
        else
            info "Sin privilegios de root: se usa -sT (connect) en vez de -sS (SYN)"
        fi

        if [[ $LEVEL -eq 1 ]]; then
            nmap_run "$outdir/nmap.err" $NMAP_TIMING -Pn $scan_type --top-ports 1000 \
                $nmap_targets \
                -oN "$outdir/nmap_service.txt" \
                -oX "$outdir/nmap_service.xml"
        elif [[ $LEVEL -eq 2 ]]; then
            if [[ -n "$ports" ]]; then
                nmap_run "$outdir/nmap.err" $NMAP_TIMING -Pn -sV -sC -p "$ports" \
                    $nmap_targets \
                    -oN "$outdir/nmap_service.txt" \
                    -oX "$outdir/nmap_service.xml"
            else
                nmap_run "$outdir/nmap.err" $NMAP_TIMING -Pn $scan_type --top-ports 1000 \
                    $nmap_targets \
                    -oN "$outdir/nmap_service.txt" \
                    -oX "$outdir/nmap_service.xml"
            fi
        else
            if [[ -n "$ports" ]]; then
                nmap_run "$outdir/nmap.err" $NMAP_TIMING -Pn -sV -sC -p "$ports" --script "vuln,exploit,auth,default" \
                    $nmap_targets \
                    -oN "$outdir/nmap_vuln.txt" \
                    -oX "$outdir/nmap_vuln.xml"
            fi
            nmap_run "$outdir/nmap.err" $NMAP_TIMING -Pn -sV -sC -p- --script "vuln,auth,default" \
                $nmap_targets \
                -oN "$outdir/nmap_full.txt" \
                -oX "$outdir/nmap_full.xml"
        fi
        # Contar puertos abiertos desde nmap
        grep -E "^[0-9]+/(tcp|udp).+open" "$outdir/nmap_service.txt" "$outdir/nmap_full.txt" "$outdir/nmap_vuln.txt" 2>/dev/null | \
            awk -F'/' '{print $1}' | sort -un > "$outdir/open_ports_nmap.txt" 2>/dev/null || true
        if [[ -s "$outdir/open_ports_nmap.txt" ]]; then
            cp "$outdir/open_ports_nmap.txt" "$outdir/open_ports.txt"
        fi
        info "nmap completado"
    fi

    success "Fase 3 completada"
}

# ═══════════════════════════════════════════════════════════════════
# FASE 4: ENUMERACION WEB
# ═══════════════════════════════════════════════════════════════════
phase_4_web_enum() {
    local target="$1"
    local outdir="$OUTPUT_DIR/04-web"
    mkdir -p "$outdir"

    if [[ $LEVEL -lt 2 ]]; then
        info "Enumeracion web requiere nivel >= 2. Saltando..."
        return 0
    fi

    section "FASE 4: ENUMERACION WEB — $target"

    local live_urls="$OUTPUT_DIR/02-probing/live_urls.txt"
    local base_url="https://$BASE_DOMAIN"
    if [[ -s "$live_urls" ]]; then
        base_url=$(head -1 "$live_urls")
    fi

    # GOBUSTER directorios
    if [[ "${TOOL_STATUS[gobuster]:-missing}" == "ok" && -n "$WORDLIST" ]]; then
        subsection "gobuster dir (directorios)"
        timeout 300 gobuster dir \
            -u "$base_url" \
            -w "$WORDLIST" \
            -t "$THREADS" \
            --no-error \
            -b "" \
            -o "$outdir/gobuster_dirs.txt" 2>/dev/null || true
        local count
        count=$(count_lines "$outdir/gobuster_dirs.txt")
        info "gobuster: $count rutas encontradas"
    fi

    # GOBUSTER dns nivel 3
    if [[ "${TOOL_STATUS[gobuster]:-missing}" == "ok" && $LEVEL -ge 3 && -n "$WORDLIST" ]]; then
        subsection "gobuster dns"
        gobuster dns \
            -d "$BASE_DOMAIN" \
            -w "$WORDLIST" \
            -t "$THREADS" \
            --no-error \
            -o "$outdir/gobuster_dns.txt" 2>/dev/null || true
        info "gobuster dns completado"
    fi

    # FFUF
    if [[ "${TOOL_STATUS[ffuf]:-missing}" == "ok" && -n "$WORDLIST" ]]; then
        subsection "ffuf (fuzzing directorios)"
        timeout 300 ffuf \
            -u "${base_url}/FUZZ" \
            -w "$WORDLIST" \
            -t "$THREADS" \
            -timeout "$TIMEOUT" \
            -mc 200,204,301,302,307,401,403,405 \
            -s \
            -o "$outdir/ffuf_dirs.json" \
            -of json 2>/dev/null || true
        if [[ -f "$outdir/ffuf_dirs.json" ]]; then
            python3 -c "
import json
try:
    d = json.load(open('$outdir/ffuf_dirs.json'))
    for r in d.get('results', []):
        print(f\"{r.get('status',0)}\t{r.get('length',0)}\t{r.get('url','')}\")
except: pass
" > "$outdir/ffuf_dirs.txt" 2>/dev/null || true
        fi
        info "ffuf completado"
    fi

    # WFUZ nivel 3
    if [[ "${TOOL_STATUS[wfuzz]:-missing}" == "ok" && $LEVEL -ge 3 && -n "$WORDLIST" ]]; then
        subsection "wfuzz (fuzzing profundo)"
        timeout 600 wfuzz \
            -c -z file,"$WORDLIST" \
            --hc 404 \
            -t "$THREADS" \
            "${base_url}/FUZZ" > "$outdir/wfuzz_dirs.txt" 2>/dev/null || true
        info "wfuzz completado"
    fi

    # ARJUN
    if [[ "${TOOL_STATUS[arjun]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "arjun (descubrimiento de parametros)"
        timeout 120 arjun \
            -u "$base_url" \
            -t "$THREADS" \
            -o "$outdir/arjun_params.json" \
            --format json 2>/dev/null || true
        info "arjun completado"
    fi

    # WAYBACKURLS (URLs historicas)
    if [[ "${TOOL_STATUS[waybackurls]:-missing}" == "ok" ]]; then
        subsection "waybackurls (URLs historicas Wayback)"
        echo "$BASE_DOMAIN" | waybackurls 2>/dev/null | \
            sort -u > "$outdir/wayback_urls.txt" 2>/dev/null || true
        local wayback_count
        wayback_count=$(count_lines "$outdir/wayback_urls.txt")
        info "waybackurls: $wayback_count URLs historicas"
    fi

    # GAU (AlienVault + Wayback + CommonCrawl)
    if [[ "${TOOL_STATUS[gau]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "gau (URLs AlienVault, Wayback, CommonCrawl)"
        echo "$BASE_DOMAIN" | timeout 120 gau --threads "$THREADS" 2>/dev/null | \
            sort -u > "$outdir/gau_urls.txt" 2>/dev/null || true
        local gau_count
        gau_count=$(count_lines "$outdir/gau_urls.txt")
        info "gau: $gau_count URLs"
    fi

    # KATANA (web crawler moderno)
    if [[ "${TOOL_STATUS[katana]:-missing}" == "ok" && $LEVEL -ge 2 ]]; then
        subsection "katana (web crawler)"
        if [[ -s "$live_urls" ]]; then
            cat "$live_urls" | katana \
                -d "$KATANA_DEPTH" \
                -timeout "$KATANA_TIMEOUT" \
                -silent \
                -jc \
                -ef css,svg,woff,png,jpg,gif \
                -o "$outdir/katana_urls.txt" 2>/dev/null || true
        else
            echo "$base_url" | katana \
                -d "$KATANA_DEPTH" \
                -timeout "$KATANA_TIMEOUT" \
                -silent \
                -jc \
                -ef css,svg,woff,png,jpg,gif \
                -o "$outdir/katana_urls.txt" 2>/dev/null || true
        fi
        local katana_count
        katana_count=$(count_lines "$outdir/katana_urls.txt")
        info "katana: $katana_count URLs"
    fi

    # LINKFINDER (endpoints en JavaScript)
    if [[ $LEVEL -ge 2 ]]; then
        subsection "Extraccion de endpoints en JS"
        if [[ -s "$outdir/live_urls.txt" ]]; then
            : > "$outdir/endpoints_raw.txt"
            head -10 "$outdir/live_urls.txt" | while IFS= read -r url; do
                [[ -z "$url" ]] && continue
                local js_files
                js_files=$(curl -s "$url" 2>/dev/null | grep -oE 'src="[^"]*\.js[^"]*"' | sed 's/src="//;s/"$//' | head -5)
                for js in $js_files; do
                    [[ "$js" != http* ]] && js="$url$js"
                    curl -s "$js" 2>/dev/null | grep -oE '(https?://[^"'\''> ]+|/[a-zA-Z0-9/_-]+\.[a-zA-Z]{2,})' >> "$outdir/endpoints_raw.txt"
                done
            done
            sort -u "$outdir/endpoints_raw.txt" > "$outdir/endpoints.txt" 2>/dev/null || true
            local ep_count
            ep_count=$(count_lines "$outdir/endpoints.txt")
            info "Endpoints encontrados: $ep_count"
        fi
    fi

    # SECRETFINDER (secrets/API keys en JS)
    if [[ $LEVEL -ge 3 ]]; then
        subsection "Busqueda de secrets en JS"
        local secret_patterns='(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|private[_-]?key|password|aws[_-]?access|aws[_-]?secret|slack[_-]?token|github[_-]?token|jwt)'
        if [[ -s "$outdir/live_urls.txt" ]]; then
            : > "$outdir/secrets_raw.txt"
            head -5 "$outdir/live_urls.txt" | while IFS= read -r url; do
                [[ -z "$url" ]] && continue
                curl -s "$url" 2>/dev/null | grep -oiE "$secret_patterns\s*[:=]\s*['\"][^'\"]+['\"]" >> "$outdir/secrets_raw.txt"
            done
            sort -u "$outdir/secrets_raw.txt" > "$outdir/secrets.txt" 2>/dev/null || true
            if [[ -s "$outdir/secrets.txt" ]]; then
                warn "SECRETS ENCONTRADOS en JavaScript"
                cat "$outdir/secrets.txt"
            fi
        fi
    fi

    # PARAMETROS DESDE URLs HISTORICAS
    if [[ -s "$outdir/wayback_urls.txt" || -s "$outdir/gau_urls.txt" ]]; then
        subsection "Extraccion de parametros de URLs historicas"
        cat "$outdir/wayback_urls.txt" "$outdir/gau_urls.txt" 2>/dev/null | \
            grep -oE '\?[a-zA-Z0-9_]+=' | sort -u > "$outdir/params_from_urls.txt" 2>/dev/null || true
        local param_count
        param_count=$(count_lines "$outdir/params_from_urls.txt")
        info "Parametros unicos encontrados: $param_count"
    fi

    success "Fase 4 completada"
}

# ═══════════════════════════════════════════════════════════════════
# FASE 5: VULNERABILIDADES
# ═══════════════════════════════════════════════════════════════════
phase_5_vulns() {
    local target="$1"
    local outdir="$OUTPUT_DIR/05-vulns"
    mkdir -p "$outdir"

    if [[ $LEVEL -lt 2 ]]; then
        info "Escaneo de vulnerabilidades requiere nivel >= 2. Saltando..."
        return 0
    fi

    section "FASE 5: ESCANEO DE VULNERABILIDADES — $target"

    local base_url="https://$BASE_DOMAIN"
    local live_urls="$OUTPUT_DIR/02-probing/live_urls.txt"
    if [[ -s "$live_urls" ]]; then
        base_url=$(head -1 "$live_urls")
    fi

    # NIKTO
    if [[ "${TOOL_STATUS[nikto]:-missing}" == "ok" ]]; then
        subsection "nikto (scanner web)"
        timeout 300 nikto \
            -h "$base_url" \
            -Tuning 123457890abc \
            -maxtime 120s \
            -o "$outdir/nikto.txt" \
            -Format txt 2>/dev/null || true
        info "nikto completado"
    fi

    # NUCLEI
    if [[ "${TOOL_STATUS[nuclei]:-missing}" == "ok" ]]; then
        subsection "nuclei (scanner de plantillas)"
        # Actualizar templates solo si no se ha hecho en esta sesion
        local nuclei_cache="$HOME/.cache/nuclei/.templates_updated"
        if [[ ! -f "$nuclei_cache" ]] || [[ $(find "$nuclei_cache" -mmin +1440 2>/dev/null | wc -l) -gt 0 ]]; then
            timeout 120 nuclei -update-templates -silent 2>/dev/null || true
            mkdir -p "$(dirname "$nuclei_cache")" && touch "$nuclei_cache"
        fi
        if [[ -s "$live_urls" ]]; then
            cat "$live_urls" | timeout 300 nuclei \
                -severity "$NUCLEI_SEVERITY" \
                -rl "$NUCLEI_RATE" \
                -c "$THREADS" \
                -timeout 5 \
                -retries 1 \
                -silent \
                -nc \
                -o "$outdir/nuclei_results.txt" 2>/dev/null || true
        else
            timeout 300 nuclei -u "$base_url" \
                -severity "$NUCLEI_SEVERITY" \
                -rl "$NUCLEI_RATE" \
                -c "$THREADS" \
                -timeout 5 \
                -retries 1 \
                -silent \
                -nc \
                -o "$outdir/nuclei_results.txt" 2>/dev/null || true
        fi
        local vuln_count
        vuln_count=$(count_lines "$outdir/nuclei_results.txt")
        info "nuclei: $vuln_count vulnerabilidades detectadas"
    fi

    # SQLMAP nivel 3
    if [[ "${TOOL_STATUS[sqlmap]:-missing}" == "ok" && $LEVEL -ge 3 ]]; then
        subsection "sqlmap (SQL injection testing)"
        local param_urls="$OUTPUT_DIR/04-web/param_urls.txt"
        if [[ -s "$param_urls" ]]; then
            head -5 "$param_urls" | while IFS= read -r url; do
                [[ -z "$url" ]] && continue
                sqlmap -u "$url" --batch --level=1 --risk=1 \
                    --output-dir="$outdir/sqlmap/" 2>/dev/null || true
            done
            info "sqlmap completado"
        else
            info "No se encontraron URLs con parametros para SQLi testing"
        fi
    fi

    # HEADER SECURITY CHECK
    subsection "Verificacion de Headers de Seguridad"
    if [[ -s "$live_urls" ]]; then
        : > "$outdir/security_headers.txt"
        head -10 "$live_urls" | while IFS= read -r url; do
            [[ -z "$url" ]] && continue
            local headers=""
            headers=$(curl -s -I "$url" 2>/dev/null) || true
            if ! echo "$headers" | grep -qi "content-security-policy"; then
                echo "CSP_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
            if ! echo "$headers" | grep -qi "strict-transport-security"; then
                echo "HSTS_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
            if ! echo "$headers" | grep -qi "x-frame-options"; then
                echo "XFO_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
            if ! echo "$headers" | grep -qi "x-content-type-options"; then
                echo "XCTO_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
            if ! echo "$headers" | grep -qi "x-xss-protection"; then
                echo "XSS_PROT_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
            if ! echo "$headers" | grep -qi "referrer-policy"; then
                echo "REFERRER_MISSING: $url" >> "$outdir/security_headers.txt"
            fi
        done
        local sec_count
        sec_count=$(count_lines "$outdir/security_headers.txt")
        if [[ $sec_count -gt 0 ]]; then
            warn "Headers de seguridad faltantes: $sec_count"
        fi
        info "Security headers check completado"
    fi

    # CORS CHECK
    subsection "Verificacion CORS"
    if [[ -s "$live_urls" ]]; then
        : > "$outdir/cors_check.txt"
        : > "$outdir/cors_vulnerable.txt"
        head -10 "$live_urls" | while IFS= read -r url; do
            [[ -z "$url" ]] && continue
            local cors
            cors=$(curl -s -I -H "Origin: https://evil.com" "$url" 2>/dev/null | \
                grep -i "access-control-allow-origin" || echo "NONE")
            if [[ "$cors" != "NONE" ]]; then
                echo "CORS: $url -> $cors" >> "$outdir/cors_check.txt"
                if echo "$cors" | grep -qi "evil.com\|*"; then
                    echo "CORS_VULN: $url -> $cors" >> "$outdir/cors_vulnerable.txt"
                    warn "CORS VULNERABLE: $url"
                fi
            fi
        done
        info "CORS check completado"
    fi

    # OPEN REDIRECT CHECK
    subsection "Verificacion Open Redirect"
    if [[ -s "$live_urls" ]]; then
        : > "$outdir/open_redirects.txt"
        local redirect_params="redirect,url,next,return,goto,redir,dest,destination,continue,rurl,ref,site,go,out"
        head -10 "$live_urls" | while IFS= read -r url; do
            [[ -z "$url" ]] && continue
            for param in $(echo "$redirect_params" | tr ',' ' '); do
                local test_url="${url}?${param}=https://evil.com"
                local status=""
                status=$(curl -s -o /dev/null -w "%{http_code}:%{redirect_url}" --max-time 5 "$test_url" 2>/dev/null) || true
                if echo "$status" | grep -q "3[0-9][0-9]:https://evil.com"; then
                    echo "OPEN_REDIRECT: $test_url" >> "$outdir/open_redirects.txt"
                    warn "OPEN REDIRECT: $test_url"
                fi
            done
        done
        info "Open redirect check completado"
    fi

    success "Fase 5 completada"
}

# ═══════════════════════════════════════════════════════════════════
# FASE 6: OSINT (Nivel 3)
# ═══════════════════════════════════════════════════════════════════
phase_6_osint() {
    local target="$1"
    local scan_domain="$BASE_DOMAIN"
    local outdir="$OUTPUT_DIR/06-osint"
    mkdir -p "$outdir"

    if [[ $LEVEL -lt 3 ]]; then
        info "OSINT requiere nivel >= 3. Saltando..."
        return 0
    fi

    section "FASE 6: OSINT — $target"

    # SHODAN
    if [[ "${TOOL_STATUS[shodan]:-missing}" == "ok" ]]; then
        subsection "shodan (reputacion IP)"
        local ip
        ip=$(dig +short A "$scan_domain" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
        if [[ -n "$ip" ]]; then
            shodan host "$ip" > "$outdir/shodan_host.txt" 2>/dev/null || true
            shodan host "$ip" 2>/dev/null | grep -i "vuln\|CVE\|vulnerability" > "$outdir/shodan_vulns.txt" 2>/dev/null || true
            shodan host "$ip" 2>/dev/null | grep -iE "port|product|version" > "$outdir/shodan_services.txt" 2>/dev/null || true
            info "shodan completado para $ip"
        fi
        subsection "shodan search (dominio)"
        shodan search "hostname:$scan_domain" --fields ip_str,port,product,vulns 2>/dev/null > "$outdir/shodan_search.txt" 2>/dev/null || true
    fi

    # RECON-NG
    if [[ "${TOOL_STATUS[recon-ng]:-missing}" == "ok" ]]; then
        subsection "recon-ng (framework modular)"
        local ws="recon_pro_$(date +%s)"
        recon-ng -w "$ws" -C "
workspaces create $ws
load recon/domains-hosts/hackertarget
options set SOURCE $scan_domain
run
load recon/domains-hosts/certificate_transparency
options set SOURCE $scan_domain
run
load recon/hosts-hosts/bingip
options set SOURCE $scan_domain
run
back
show hosts
exit
" > "$outdir/recon_ng.txt" 2>/dev/null || true
        info "recon-ng completado"
    fi

    # WAYBACK MACHINE
    subsection "Wayback Machine (URLs historicas)"
    curl -s "https://web.archive.org/cdx/search/cdx?url=$scan_domain/*&output=json&fl=original&collapse=urlkey&limit=500" 2>/dev/null | \
        python3 -c "import sys,json; [print(x[0]) for x in json.load(sys.stdin)[1:]]" 2>/dev/null | \
        sort -u > "$outdir/wayback_machine.txt" 2>/dev/null || true
    local wayback_count
    wayback_count=$(count_lines "$outdir/wayback_machine.txt")
    info "Wayback Machine: $wayback_count URLs"

    # EMAIL HARVESTING
    subsection "Email harvesting (crt.sh)"
    curl -s "https://crt.sh/?q=%25.${scan_domain}&output=json" 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    emails = set()
    for entry in data:
        name = entry.get('name_value', '')
        for part in name.split('\n'):
            if '@' in part:
                emails.add(part.strip())
    for e in sorted(emails):
        print(e)
except: pass
" > "$outdir/emails.txt" 2>/dev/null || true
    local email_count
    email_count=$(count_lines "$outdir/emails.txt")
    info "Emails encontrados: $email_count"

    # SUBDOMINIOS SENSIBLES
    subsection "Busqueda de subdominios sensibles"
    local sensitive_words="admin,panel,dashboard,login,auth,api,dev,staging,test,backup,db,mysql,redis,git,svn,ftp,smtp,mail,webmail,smtp,pop,imap,ns1,ns2,dns,cdn,assets,static,media,img,images,upload,files,docs,help,support,portal,app,mobile,status,monitor,grafana,kibana,elastic,splunk,jenkins,circleci,gitlab,github,bitbucket"
    echo "$sensitive_words" | tr ',' '\n' | while read -r word; do
        echo "${word}.${scan_domain}"
    done | dnsx -silent -a 2>/dev/null >> "$outdir/sensitive_subs.txt" || true
    local sens_count
    sens_count=$(count_lines "$outdir/sensitive_subs.txt")
    info "Subdominios sensibles: $sens_count"

    success "Fase 6 completada"
}

# ═══════════════════════════════════════════════════════════════════
# MODO BUG BOUNTY (*)
# ═══════════════════════════════════════════════════════════════════
run_bug_bounty_mode() {
    section "MODO BUG BOUNTY — Todos los targets en scope"

    local registry="__HOME__/BugBounty/scope-registry.json"
    local projects_dir="__HOME__/BugBounty"

    if [[ ! -f "$registry" ]]; then
        error "No se encontro scope-registry.json en $projects_dir"
        return 1
    fi

    local active_projects
    active_projects=$(python3 -c "
import json
try:
    with open('$registry') as f:
        data = json.load(f)
    for proj in data.get('projects', []):
        if proj.get('status') == 'active':
            print(proj.get('name', ''))
except: pass
" 2>/dev/null)

    if [[ -z "$active_projects" ]]; then
        warn "No hay proyectos activos en scope."
        return 1
    fi

    info "Proyectos activos encontrados:"
    echo "$active_projects" | while read -r proj; do
        [[ -z "$proj" ]] && continue
        echo -e "  ${GREEN}->$NC $proj"
    done

    echo "$active_projects" | while read -r project; do
        [[ -z "$project" ]] && continue

        local scope_file="$projects_dir/$project/scope/scope.json"
        local project_outdir="$OUTPUT_DIR/$project"
        mkdir -p "$project_outdir"

        subsection "Recon para proyecto: $project"

        local targets=""
        if [[ -f "$scope_file" ]]; then
            targets=$(python3 -c "
import json
try:
    with open('$scope_file') as f:
        data = json.load(f)
    for t in data.get('targets', []):
        if isinstance(t, str):
            print(t)
        elif isinstance(t, dict):
            print(t.get('target', ''))
except: pass
" 2>/dev/null)
        fi

        if [[ -z "$targets" ]]; then
            warn "Sin targets para $project"
            continue
        fi

        echo "$targets" | while IFS= read -r tgt; do
            [[ -z "$tgt" ]] && continue
            tgt=$(echo "$tgt" | sed 's/^\*\.//')
            info "Target: $tgt"

            local orig_output="$OUTPUT_DIR"
            OUTPUT_DIR="$project_outdir"

            phase_0_whois_dns "$tgt"
            phase_1_subdomains "$tgt"
            phase_2_probing "$tgt"
            phase_3_ports "$tgt"

            if [[ $LEVEL -ge 2 ]]; then
                phase_4_web_enum "$tgt"
                phase_5_vulns "$tgt"
            fi

            OUTPUT_DIR="$orig_output"
        done
    done

    success "Bug bounty mode completado"
}

# ═══════════════════════════════════════════════════════════════════
# GENERACION DE INFORME CONDENSADO
# ═══════════════════════════════════════════════════════════════════
generate_report() {
    section "GENERANDO INFORME CONDENSADO"

    local target="$1"
    local outdir="$OUTPUT_DIR"
    local report="$outdir/RECON_REPORT.md"
    local elapsed_time
    elapsed_time=$(elapsed)

    # Contar metricas
    local subdomains=0
    local live_hosts=0
    local open_ports=0
    local urls_total=0
    local vulns_critical=0
    local vulns_high=0
    local vulns_medium=0
    local vulns_low=0
    local technologies=""
    local emails=0
    local wayback_urls=0
    local endpoints=0
    local secrets=0
    local cors_vuln=0
    local open_redirects=0
    local security_headers=0
    local sensitive_subs=0

    [[ -f "$outdir/01-subdomains/all_subdomains.txt" ]] && subdomains=$(count_lines "$outdir/01-subdomains/all_subdomains.txt")
    [[ -f "$outdir/02-probing/live_urls.txt" ]] && live_hosts=$(count_lines "$outdir/02-probing/live_urls.txt")
    [[ -f "$outdir/03-ports/open_ports.txt" ]] && open_ports=$(count_lines "$outdir/03-ports/open_ports.txt")
    if [[ $open_ports -eq 0 && -f "$outdir/03-ports/nmap_service.txt" ]]; then
        open_ports=$(grep -cE "(tcp|udp).+open" "$outdir/03-ports/nmap_service.txt" 2>/dev/null || echo 0)
    fi
    open_ports=$(echo "$open_ports" | tail -1 | tr -d '[:space:]')
    [[ -f "$outdir/04-web/ffuf_dirs.txt" ]] && urls_total=$(count_lines "$outdir/04-web/ffuf_dirs.txt")
    [[ -f "$outdir/04-web/wayback_urls.txt" ]] && urls_total=$((urls_total + $(count_lines "$outdir/04-web/wayback_urls.txt")))
    [[ -f "$outdir/06-osint/emails.txt" ]] && emails=$(count_lines "$outdir/06-osint/emails.txt")

    if [[ -f "$outdir/05-vulns/nuclei_results.txt" ]]; then
        vulns_critical=$(grep -c "\[critical\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null || true)
        vulns_high=$(grep -c "\[high\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null || true)
        vulns_medium=$(grep -c "\[medium\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null || true)
        vulns_low=$(grep -c "\[low\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null || true)
    fi
    # Default a 0 si estan vacios
    vulns_critical=${vulns_critical:-0}
    vulns_high=${vulns_high:-0}
    vulns_medium=${vulns_medium:-0}
    vulns_low=${vulns_low:-0}
    # Limpiar newlines/espacios de todos los contadores
    subdomains=$(echo "$subdomains" | tr -d '[:space:]')
    live_hosts=$(echo "$live_hosts" | tr -d '[:space:]')
    open_ports=$(echo "$open_ports" | tr -d '[:space:]')
    urls_total=$(echo "$urls_total" | tr -d '[:space:]')
    emails=$(echo "$emails" | tr -d '[:space:]')
    vulns_critical=$(echo "$vulns_critical" | tr -d '[:space:]')
    vulns_high=$(echo "$vulns_high" | tr -d '[:space:]')
    vulns_medium=$(echo "$vulns_medium" | tr -d '[:space:]')
    vulns_low=$(echo "$vulns_low" | tr -d '[:space:]')

    if [[ -f "$outdir/02-probing/technologies.txt" ]]; then
        technologies=$(head -5 "$outdir/02-probing/technologies.txt" | tr '\n' ', ' | sed 's/,$//')
    fi

    [[ -f "$outdir/04-web/wayback_urls.txt" ]] && wayback_urls=$(count_lines "$outdir/04-web/wayback_urls.txt")
    [[ -f "$outdir/04-web/endpoints.txt" ]] && endpoints=$(count_lines "$outdir/04-web/endpoints.txt")
    [[ -f "$outdir/04-web/secrets.txt" ]] && secrets=$(count_lines "$outdir/04-web/secrets.txt")
    [[ -f "$outdir/05-vulns/cors_vulnerable.txt" ]] && cors_vuln=$(count_lines "$outdir/05-vulns/cors_vulnerable.txt")
    [[ -f "$outdir/05-vulns/open_redirects.txt" ]] && open_redirects=$(count_lines "$outdir/05-vulns/open_redirects.txt")
    [[ -f "$outdir/05-vulns/security_headers.txt" ]] && security_headers=$(count_lines "$outdir/05-vulns/security_headers.txt")
    [[ -f "$outdir/06-osint/sensitive_subs.txt" ]] && sensitive_subs=$(count_lines "$outdir/06-osint/sensitive_subs.txt")

    cat > "$report" << REPORT
# RECON_REPORT — $target

**Fecha:** $(date '+%Y-%m-%d %H:%M:%S')
**Nivel:** $LEVEL | **Duracion:** $(human_time $elapsed_time)
**Target:** $target | **Tipo:** $TARGET_TYPE

---

## Dashboard

| Metrica | Valor |
|---------|-------|
| Subdominios | $subdomains |
| Hosts vivos | $live_hosts |
| Puertos abiertos | $open_ports |
| URLs historicas | $wayback_urls |
| Endpoints JS | $endpoints |
| Secrets encontrados | **$secrets** |
| Emails | $emails |
| Subdominios sensibles | $sensitive_subs |
| **Vulns CRITICAL** | **$vulns_critical** |
| **Vulns HIGH** | **$vulns_high** |
| Vulns MEDIUM | $vulns_medium |
| Vulns LOW | $vulns_low |
| **CORS Vulnerable** | **$cors_vuln** |
| **Open Redirects** | **$open_redirects** |
| Headers faltantes | $security_headers |

---

## Tecnologias Detectadas

$technologies

REPORT

    # IPs
    if [[ -s "$outdir/02-probing/live_ips.txt" ]]; then
        cat >> "$report" << REPORT
## IPs

\`\`\`
$(cat "$outdir/02-probing/live_ips.txt")
\`\`\`

REPORT
    elif [[ -s "$outdir/02-probing/live_hosts.txt" ]]; then
        cat >> "$report" << REPORT
## Hosts Vivos

\`\`\`
$(cat "$outdir/02-probing/live_hosts.txt")
\`\`\`

REPORT
    fi

    # Subdominios
    if [[ -f "$outdir/01-subdomains/all_subdomains.txt" ]]; then
        cat >> "$report" << REPORT
## Subdominios (top 50)

\`\`\`
$(head -50 "$outdir/01-subdomains/all_subdomains.txt")
\`\`\`

REPORT
    fi

    # Puertos
    if [[ -f "$outdir/03-ports/open_ports.txt" ]]; then
        cat >> "$report" << REPORT
## Puertos Abiertos

\`\`\`
$(cat "$outdir/03-ports/open_ports.txt")
\`\`\`

REPORT
    fi

    # Servicios
    if [[ -f "$outdir/03-ports/nmap_service.txt" ]]; then
        cat >> "$report" << REPORT
## Servicios Detectados

\`\`\`
$(grep -E "^[0-9]+/open" "$outdir/03-ports/nmap_service.txt" 2>/dev/null | head -30)
\`\`\`

REPORT
    fi

    # Vulnerabilidades
    if [[ -f "$outdir/05-vulns/nuclei_results.txt" ]] && [[ $(count_lines "$outdir/05-vulns/nuclei_results.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Vulnerabilidades Detectadas

### CRITICAL
\`\`\`
$(grep "\[critical\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null | head -20)
\`\`\`

### HIGH
\`\`\`
$(grep "\[high\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null | head -20)
\`\`\`

### MEDIUM
\`\`\`
$(grep "\[medium\]" "$outdir/05-vulns/nuclei_results.txt" 2>/dev/null | head -20)
\`\`\`

REPORT
    fi

    # Alerts
    if [[ -f "$outdir/ALERTS.txt" ]]; then
        cat >> "$report" << REPORT
## ALERTAS

\`\`\`
$(cat "$outdir/ALERTS.txt")
\`\`\`

REPORT
    fi

    # CORS
    if [[ -f "$outdir/05-vulns/cors_check.txt" ]]; then
        cat >> "$report" << REPORT
## CORS Check

\`\`\`
$(cat "$outdir/05-vulns/cors_check.txt")
\`\`\`

REPORT
    fi

    # CORS Vulnerable
    if [[ -f "$outdir/05-vulns/cors_vulnerable.txt" ]] && [[ $(count_lines "$outdir/05-vulns/cors_vulnerable.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## CORS VULNERABLE

\`\`\`
$(cat "$outdir/05-vulns/cors_vulnerable.txt")
\`\`\`

REPORT
    fi

    # Open Redirects
    if [[ -f "$outdir/05-vulns/open_redirects.txt" ]] && [[ $(count_lines "$outdir/05-vulns/open_redirects.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Open Redirects

\`\`\`
$(cat "$outdir/05-vulns/open_redirects.txt")
\`\`\`

REPORT
    fi

    # Security Headers
    if [[ -f "$outdir/05-vulns/security_headers.txt" ]] && [[ $(count_lines "$outdir/05-vulns/security_headers.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Security Headers Faltantes

\`\`\`
$(cat "$outdir/05-vulns/security_headers.txt")
\`\`\`

REPORT
    fi

    # Secrets
    if [[ -f "$outdir/04-web/secrets.txt" ]] && [[ $(count_lines "$outdir/04-web/secrets.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## SECRETS ENCONTRADOS

\`\`\`
$(cat "$outdir/04-web/secrets.txt")
\`\`\`

REPORT
    fi

    # WAF Detection
    if [[ -f "$outdir/02-probing/waf_detection.txt" ]]; then
        cat >> "$report" << REPORT
## WAF/CDN Detection

\`\`\`
$(cat "$outdir/02-probing/waf_detection.txt")
\`\`\`

REPORT
    fi

    # Sensitive Subdomains
    if [[ -f "$outdir/06-osint/sensitive_subs.txt" ]] && [[ $(count_lines "$outdir/06-osint/sensitive_subs.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Subdominios Sensibles

\`\`\`
$(cat "$outdir/06-osint/sensitive_subs.txt")
\`\`\`

REPORT
    fi

    # Wayback URLs (sample)
    if [[ -f "$outdir/04-web/wayback_urls.txt" ]] && [[ $(count_lines "$outdir/04-web/wayback_urls.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Wayback URLs (top 30)

\`\`\`
$(head -30 "$outdir/04-web/wayback_urls.txt")
\`\`\`

REPORT
    fi

    # Endpoints
    if [[ -f "$outdir/04-web/endpoints.txt" ]] && [[ $(count_lines "$outdir/04-web/endpoints.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Endpoints (JS)

\`\`\`
$(head -30 "$outdir/04-web/endpoints.txt")
\`\`\`

REPORT
    fi

    # TLS
    if [[ -f "$outdir/02-probing/tls_protocols.txt" ]]; then
        cat >> "$report" << REPORT
## TLS/SSL Protocols

\`\`\`
$(cat "$outdir/02-probing/tls_protocols.txt")
\`\`\`

REPORT
    fi

    # Emails
    if [[ -f "$outdir/06-osint/emails.txt" ]] && [[ $(count_lines "$outdir/06-osint/emails.txt") -gt 0 ]]; then
        cat >> "$report" << REPORT
## Emails Encontrados

\`\`\`
$(cat "$outdir/06-osint/emails.txt")
\`\`\`

REPORT
    fi

    cat >> "$report" << REPORT
---

## Estructura de Archivos

\`\`\`
$(find "$outdir" -type f | head -60 | sed "s|$outdir/||")
\`\`\`

---

## Comandos de Seguimiento

\`\`\`bash
# Escaneo de vulnerabilidades profundo
nuclei -l $outdir/02-probing/live_urls.txt -severity critical,high -rl 20 -o $outdir/followup_nuclei.txt

# SQLi testing
cat $outdir/04-web/param_urls.txt | head -10 | xargs -I{} sqlmap -u "{}" --batch

# Directory brute force
gobuster dir -u https://$BASE_DOMAIN -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 50

# Parameter discovery
arjun -u https://$BASE_DOMAIN -t 50

# Subdomain takeover check
subzy run --targets $outdir/01-subdomains/all_subdomains.txt --concurrency 50
\`\`\`

---

*Generado por RECON_PRO v${VERSION} · ECS Ecosistema de Ciberseguridad*
*$(date '+%Y-%m-%d %H:%M:%S')*
REPORT

    success "Informe generado: $report"

    generate_report_formats "$target"
}

# ═══════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════
# INFORMES DERIVADOS: RECON_REPORT.json + RECON_REPORT.html
#   JSON -> maquina-legible (diff, CI, pipelines)
#   HTML -> panel autocontenido con graficos SVG en linea (sin CDN,
#           abre en local sin conexion a Internet)
# ═══════════════════════════════════════════════════════════════════
generate_report_formats() {
    local target="$1"
    local outdir="$OUTPUT_DIR"

    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 no disponible: solo se genera RECON_REPORT.md"
        return 0
    fi

    RECON_TARGET="$target" \
    RECON_OUTDIR="$outdir" \
    RECON_TARGET_TYPE="$TARGET_TYPE" \
    RECON_LEVEL="$LEVEL" \
    RECON_VERSION="$VERSION" \
    RECON_ELAPSED="$(elapsed)" \
    RECON_STARTED_AT="${RECON_STARTED_AT:-}" \
    python3 - <<'PY'
import os, json, html, pathlib, datetime, traceback

def build():
    out    = pathlib.Path(os.environ.get('RECON_OUTDIR', '.'))
    target = os.environ.get('RECON_TARGET', '')
    ttype  = os.environ.get('RECON_TARGET_TYPE', '')
    level  = os.environ.get('RECON_LEVEL', '')
    ver    = os.environ.get('RECON_VERSION', '')
    elap   = os.environ.get('RECON_ELAPSED', '0')
    start  = os.environ.get('RECON_STARTED_AT', '') or \
             datetime.datetime.now().isoformat(timespec='seconds')

    def fmt(n):
        """Separador de miles a la espanola: 1234 -> 1.234"""
        return f'{n:,}'.replace(',', '.')

    def rd(rels):
        """Primer fichero existente de la lista; devuelve lineas no vacias."""
        for cand in rels:
            p = out / cand
            if p.is_file():
                try:
                    txt = p.read_text(encoding='utf-8', errors='replace')
                except Exception:
                    return []
                return [l.rstrip('\n') for l in txt.splitlines() if l.strip()]
        return []

    subdom  = rd(['01-subdomains/all_subdomains.txt'])
    live    = rd(['02-probing/live_urls.txt'])
    hosts   = rd(['02-probing/live_hosts.txt', '02-probing/httpx_live.txt'])
    ips     = rd(['02-probing/live_ips.txt'])
    ports   = rd(['03-ports/open_ports.txt', '03-ports/open_ports_nmap.txt'])
    techs   = rd(['02-probing/technologies.txt'])
    emails  = rd(['06-osint/emails.txt', '00-whois/emails.txt'])
    waybk   = rd(['06-osint/wayback_urls.txt'])
    endpts  = rd(['04-web/endpoints.txt'])
    secrets = rd(['04-web/secrets.txt'])
    nuclei  = rd(['05-vulns/nuclei_results.txt'])
    sechdr  = rd(['05-vulns/security_headers.txt'])
    sens    = rd(['06-osint/sensitive_subs.txt'])
    waf     = rd(['02-probing/waf_detection.txt'])

    def sev(tag):
        t = tag.lower()
        return sum(1 for l in nuclei if t in l.lower())

    vulns = {
        'critical': sev('critical'), 'high': sev('high'),
        'medium': sev('medium'), 'low': sev('low'),
        'total': len(nuclei),
    }

    counts = {
        'subdominios': len(subdom),
        'urls_vivas': len(live),
        'hosts_vivos': len(hosts),
        'ips_vivas': len(ips),
        'puertos_abiertos': len(ports),
        'tecnologias': len(techs),
        'emails': len(emails),
        'wayback_urls': len(waybk),
        'endpoints': len(endpts),
        'secrets': len(secrets),
        'hallazgos_nuclei': len(nuclei),
        'security_headers_faltantes': len(sechdr),
        'subdominios_sensibles': len(sens),
        'waf_detectado': len(waf),
    }

    md_path = out / 'RECON_REPORT.md'
    md_text = ''
    if md_path.is_file():
        try:
            md_text = md_path.read_text(encoding='utf-8', errors='replace')
        except Exception:
            md_text = ''

    data = {
        'schema': 'recon_pro.report/v1',
        'meta': {
            'target': target,
            'target_type': ttype,
            'nivel': level,
            'version': ver,
            'inicio': start,
            'duracion_seg': int(elap) if str(elap).isdigit() else elap,
            'directorio': str(out),
            'generado': datetime.datetime.now().isoformat(timespec='seconds'),
            'informe_md': md_path.name,
        },
        'conteos': counts,
        'vulnerabilidades': vulns,
        'datos': {
            'subdominios': subdom[:5000],
            'urls_vivas': live[:5000],
            'hosts_vivos': hosts[:5000],
            'ips_vivas': ips[:2000],
            'puertos_abiertos': ports[:2000],
            'tecnologias': techs[:500],
            'emails': emails[:2000],
            'wayback_urls': waybk[:5000],
            'endpoints': endpts[:5000],
            'secrets': secrets[:500],
            'nuclei': nuclei[:2000],
            'security_headers': sechdr[:500],
            'subdominios_sensibles': sens[:1000],
            'waf': waf[:100],
        },
    }

    (out / 'RECON_REPORT.json').write_text(
        json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')

    # ── HTML autocontenido ──────────────────────────────────────────
    esc = lambda s: html.escape(str(s))

    def li(items, limit=300):
        if not items:
            return '<p class="empty">Sin datos</p>\n'
        rows = ''.join('<li>' + esc(x) + '</li>' for x in items[:limit])
        more = ''
        if len(items) > limit:
            more = '<p class="more">&hellip; y ' + fmt(len(items) - limit) + ' mas</p>\n'
        return '<ul>' + rows + '</ul>\n' + more

    bars = [
        ('Subdominios', counts['subdominios']),
        ('URLs vivas', counts['urls_vivas']),
        ('Hosts vivos', counts['hosts_vivos']),
        ('Puertos abiertos', counts['puertos_abiertos']),
        ('Tecnologias', counts['tecnologias']),
        ('Endpoints', counts['endpoints']),
        ('Emails', counts['emails']),
        ('Secrets', counts['secrets']),
        ('Hallazgos nuclei', counts['hallazgos_nuclei']),
    ]
    mx  = max([v for _, v in bars] + [1])
    BW  = 300
    bars_html = []
    for label, val in bars:
        w = int(BW * val / mx)
        bars_html.append(
            '<div class="bar"><span class="lbl">' + esc(label) + '</span>'
            '<span class="track"><svg width="' + str(BW) + '" height="16" role="img">'
            '<rect x="0" y="0" width="' + str(w) + '" height="16" fill="#38bdf8"/>'
            '</svg></span><span class="val">' + fmt(val) + '</span></div>\n')
    bars_html = ''.join(bars_html)

    sev_rows = ''.join(
        '<tr><td>' + esc(k) + '</td><td>' + fmt(v) + '</td></tr>'
        for k, v in vulns.items())

    cards = ''.join(
        '<div class="card"><b>' + fmt(v) + '</b><span>' +
        esc(k.replace('_', ' ')) + '</span></div>'
        for k, v in counts.items())

    css = """
:root{--bg:#0b1220;--fg:#e2e8f0;--mut:#94a3b8;--card:#111a2e;--ln:#1e293b;--ac:#38bdf8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
 font:14px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace}
header{padding:22px 26px;border-bottom:1px solid var(--ln);
 background:linear-gradient(180deg,#0f1a33,#0b1220)}
h1{margin:0 0 6px;font-size:21px}
.meta{color:var(--mut);font-size:12px}
main{padding:22px 26px;max-width:1200px;margin:0 auto}
h2{font-size:15px;color:var(--ac);border-bottom:1px solid var(--ln);
 padding-bottom:6px;margin:26px 0 12px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.card{background:var(--card);border:1px solid var(--ln);border-radius:9px;padding:12px 14px}
.card b{display:block;font-size:23px;color:var(--ac)}
.card span{color:var(--mut);font-size:11px;text-transform:uppercase;letter-spacing:.05em}
.bar{display:grid;grid-template-columns:150px auto 80px;align-items:center;
 gap:10px;margin:5px 0;font-size:12px}
.bar .lbl{color:var(--mut)}
.bar .val{text-align:right}
table{border-collapse:collapse;width:100%;font-size:12px}
th,td{text-align:left;padding:6px 9px;border-bottom:1px solid var(--ln)}
th{color:var(--mut);font-weight:600}
ul{columns:2;column-gap:24px;margin:8px 0;padding-left:18px;font-size:12px}
li{break-inside:avoid;list-style:none;padding:2px 0;color:#cbd5e1}
li:before{content:"\\25B8 ";color:var(--ac)}
.empty{color:var(--mut);font-style:italic}
.more{color:var(--mut);font-size:11px}
details{background:var(--card);border:1px solid var(--ln);border-radius:9px;
 padding:12px 14px;margin:14px 0}
summary{cursor:pointer;color:var(--ac);font-weight:600}
pre{white-space:pre-wrap;word-break:break-word;color:#cbd5e1;font-size:12px}
footer{color:var(--mut);font-size:11px;padding:18px 26px;border-top:1px solid var(--ln)}
"""

    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    def section(title, body):
        return '<h2>' + title + '</h2>\n' + body + '\n'

    h = []
    h.append('<!doctype html>\n<html lang="es"><head><meta charset="utf-8">\n')
    h.append('<meta name="viewport" content="width=device-width,initial-scale=1">\n')
    h.append('<title>Recon ' + esc(target) + '</title>\n')
    h.append('<style>' + css + '</style></head><body>\n')
    h.append('<header><h1>RECON_REPORT &mdash; ' + esc(target) + '</h1>\n')
    h.append('<div class="meta">tipo: ' + esc(ttype) + ' &middot; nivel: ' + esc(level) +
             ' &middot; ' + esc(ver) + ' &middot; inicio ' + esc(start) +
             ' &middot; duraci&oacute;n ' + esc(elap) + ' s</div>\n</header>\n<main>\n')
    h.append(section('Conteos', '<div class="cards">' + cards + '</div>'))
    h.append(section('Distribuci&oacute;n', bars_html))
    h.append(section('Vulnerabilidades (nuclei)',
        '<table><thead><tr><th>Severidad</th><th>Hallazgos</th></tr></thead>'
        '<tbody>' + sev_rows + '</tbody></table>'))
    h.append(section('Subdominios (' + fmt(len(subdom)) + ')', li(subdom)))
    h.append(section('URLs vivas (' + fmt(len(live)) + ')', li(live)))
    h.append(section('Puertos abiertos (' + fmt(len(ports)) + ')', li(ports)))
    h.append(section('Tecnolog&iacute;as (' + fmt(len(techs)) + ')', li(techs, 200)))
    h.append(section('Emails (' + fmt(len(emails)) + ')', li(emails)))
    h.append(section('Secrets (' + fmt(len(secrets)) + ')', li(secrets, 100)))
    h.append('<details><summary>Informe Markdown completo</summary><pre>' +
             esc(md_text) + '</pre></details>\n')
    h.append('</main>\n<footer>Generado por RECON_PRO v' + esc(ver) +
             ' &middot; ECS Ecosistema de Ciberseguridad &middot; ' + now +
             ' &middot; offline (sin CDN)</footer>\n</body></html>\n')

    (out / 'RECON_REPORT.html').write_text(''.join(h), encoding='utf-8')

try:
    build()
except Exception:
    traceback.print_exc()
    raise SystemExit(1)
PY

    if [[ -f "$outdir/RECON_REPORT.json" ]]; then
        success "JSON generado: $outdir/RECON_REPORT.json"
    fi
    if [[ -f "$outdir/RECON_REPORT.html" ]]; then
        success "HTML generado: $outdir/RECON_REPORT.html"
    fi
    return 0
}

# FUNCION PRINCIPAL
# ═══════════════════════════════════════════════════════════════════
main() {
    parse_args "$@"

    RECON_STARTED_AT="$(date +%Y-%m-%dT%H:%M:%S%z)"

    if [[ "$TARGET_TYPE" != "wildcard" && -z "$TARGET" ]]; then
        error "Target no definido."
        exit 1
    fi

    # Solo mostrar banner si no es modo interactivo
    if [[ $# -gt 0 ]]; then
        show_banner
    fi

    detect_target_type "$TARGET"

    info "Target: ${WHITE}$TARGET${NC}"
    info "Tipo: ${WHITE}$TARGET_TYPE${NC}"
    info "Nivel: ${WHITE}$LEVEL${NC}"
    info "Threads: ${WHITE}$THREADS${NC}"

    # Gate de autorizacion ANTES de tocar el target (sólo con --ecc)
    if [[ "$ECC_MODE" == "true" ]]; then
        ecc_gate "$TARGET"
    fi

    if [[ -z "$OUTPUT_DIR" ]]; then
        local safe_target
        safe_target=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g;s/__*/_/g;s/^_//;s/_$//')
        OUTPUT_DIR="$(pwd)/recon_${safe_target}_$(date +%Y%m%d_%H%M%S)"
    fi

    if [[ -d "$OUTPUT_DIR" && "$FORCE" != "true" ]]; then
        error "Directorio ya existe: $OUTPUT_DIR"
        error "Usa -f para sobreescribir."
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="$OUTPUT_DIR/recon.log"
    touch "$LOG_FILE"

    info "Salida: ${WHITE}$OUTPUT_DIR${NC}"

    check_all_tools

    if [[ "$TARGET_TYPE" == "wildcard" && "$TARGET" == "*" ]]; then
        run_bug_bounty_mode
    else
        phase_0_whois_dns "$TARGET"
        phase_1_subdomains "$TARGET"
        phase_2_probing "$TARGET"
        phase_3_ports "$TARGET"
        phase_4_web_enum "$TARGET"
        phase_5_vulns "$TARGET"
        phase_6_osint "$TARGET"
    fi

    generate_report "$TARGET"

    if [[ "$ECC_MODE" == "true" ]]; then
        ecc_audit "recon end target=$TARGET nivel=$LEVEL dir=$OUTPUT_DIR"
    fi

    section "RESUMEN FINAL"
    local elapsed_time
    elapsed_time=$(elapsed)

    echo -e "${GREEN}  Reconocimiento completado para: ${WHITE}$TARGET${NC}"
    echo ""
    echo -e "  ${CYAN}Duracion:${NC}     $(human_time $elapsed_time)"
    echo -e "  ${CYAN}Nivel:${NC}        $LEVEL"
    echo -e "  ${CYAN}Salida:${NC}       $OUTPUT_DIR"
    echo -e "  ${CYAN}Informe:${NC}      $OUTPUT_DIR/RECON_REPORT.md"
    echo -e "  ${CYAN}              ${NC}  $OUTPUT_DIR/RECON_REPORT.html"
    echo -e "  ${CYAN}              ${NC}  $OUTPUT_DIR/RECON_REPORT.json"
    echo ""

    local s=0 l=0 p=0 v=0
    [[ -f "$OUTPUT_DIR/01-subdomains/all_subdomains.txt" ]] && s=$(count_lines "$OUTPUT_DIR/01-subdomains/all_subdomains.txt")
    [[ -f "$OUTPUT_DIR/02-probing/live_urls.txt" ]] && l=$(count_lines "$OUTPUT_DIR/02-probing/live_urls.txt")
    [[ -f "$OUTPUT_DIR/03-ports/open_ports.txt" ]] && p=$(count_lines "$OUTPUT_DIR/03-ports/open_ports.txt")
    [[ -f "$OUTPUT_DIR/05-vulns/nuclei_results.txt" ]] && v=$(count_lines "$OUTPUT_DIR/05-vulns/nuclei_results.txt")

    echo -e "  ${MAGENTA}Estadisticas:${NC}"
    echo -e "    Subdominios:  ${WHITE}$s${NC}"
    echo -e "    Hosts vivos:  ${WHITE}$l${NC}"
    echo -e "    Puertos:      ${WHITE}$p${NC}"
    echo -e "    Vulns:        ${WHITE}$v${NC}"
    echo ""
    echo -e "  ${GREEN}Listo para la siguiente fase!${NC}"
}

# ═══════════════════════════════════════════════════════════════════
# EJECUCION
# ═══════════════════════════════════════════════════════════════════
main "$@"
