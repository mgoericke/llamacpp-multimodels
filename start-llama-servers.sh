#!/usr/bin/env bash

# ==============================================================================
# Llama.cpp Server Starter
# ==============================================================================
# Startet mehrere llama-server Instanzen für Chat und Embeddings
# Installiert llama.cpp automatisch via Homebrew falls nicht vorhanden
# ==============================================================================

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Konfiguration
LLAMA_SERVER="llama-server"
LOG_DIR="./logs"
PID_FILE="./llama-servers.pid"

# Server Konfigurationen (einfache Arrays)
# Chat Server
CHAT_NAME="Chat (Qwen3-4B)"
CHAT_MODEL="ggml-org/Qwen3-4B-GGUF:Q4_K_M"
CHAT_PORT=8033
CHAT_CONTEXT=16384

# Embedding Server
EMBEDDING_NAME="Embeddings (nomic-embed-text)"
EMBEDDING_MODEL="nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0"
EMBEDDING_PORT=8034
EMBEDDING_CONTEXT=1024 # may cause input is larger than the max context size. skipping
EMBEDDING_UBATCH=1024   # Neu: muss >= CONTEXT sein

# ==============================================================================
# Hilfsfunktionen
# ==============================================================================

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  🦙 Llama.cpp Server Manager                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC}  $1"
}

print_step() {
    echo -e "${MAGENTA}▶${NC}  $1"
}

check_homebrew() {
    print_info "Prüfe Homebrew Installation..."

    if ! command -v brew &> /dev/null; then
        print_error "Homebrew ist nicht installiert"
        echo ""
        echo -e "${YELLOW}Homebrew wird benötigt, um llama.cpp zu installieren.${NC}"
        echo -e "${YELLOW}Möchtest du Homebrew jetzt installieren? (j/n)${NC}"
        read -r response

        if [[ "$response" =~ ^([jJ][aA]|[jJ])$ ]]; then
            print_step "Installiere Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Homebrew in PATH für diese Session
            if [[ $(uname -m) == "arm64" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                eval "$(/usr/local/bin/brew shellenv)"
            fi

            print_success "Homebrew erfolgreich installiert"
        else
            print_error "Installation abgebrochen. Homebrew wird benötigt."
            echo ""
            echo -e "${CYAN}Installiere Homebrew manuell:${NC}"
            echo -e "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    else
        print_success "Homebrew ist installiert ($(brew --version | head -n1))"
    fi
}

check_llama_cpp() {
    print_info "Prüfe llama.cpp Installation..."

    if ! command -v llama-server &> /dev/null; then
        print_warning "llama.cpp ist nicht installiert"
        echo ""
        echo -e "${YELLOW}Möchtest du llama.cpp jetzt via Homebrew installieren? (j/n)${NC}"
        read -r response

        if [[ "$response" =~ ^([jJ][aA]|[jJ])$ ]]; then
            install_llama_cpp
        else
            print_error "Installation abgebrochen. llama.cpp wird benötigt."
            echo ""
            echo -e "${CYAN}Installiere llama.cpp manuell:${NC}"
            echo -e "  brew install llama.cpp"
            exit 1
        fi
    else
        local version=$(llama-server --version 2>&1 | head -n1 || echo "unbekannt")
        print_success "llama.cpp ist installiert ($version)"
    fi
}

install_llama_cpp() {
    print_step "Installiere llama.cpp via Homebrew..."
    echo ""

    # llama.cpp installieren
    print_info "Installiere llama.cpp..."
    if brew install llama.cpp; then
        echo ""
        print_success "llama.cpp erfolgreich installiert!"

        # Prüfe Installation
        if command -v llama-server &> /dev/null; then
            local version=$(llama-server --version 2>&1 | head -n1 || echo "unbekannt")
            print_success "Version: $version"
        fi
    else
        echo ""
        print_error "Installation von llama.cpp fehlgeschlagen"
        echo ""
        echo -e "${CYAN}Versuche manuelle Installation:${NC}"
        echo -e "  brew install llama.cpp"
        exit 1
    fi
}

check_prerequisites() {
    print_info "Prüfe Voraussetzungen..."

    # Betriebssystem erkennen
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Betriebssystem: macOS ($(sw_vers -productVersion))"
    else
        print_info "Betriebssystem: $OSTYPE"
    fi

    echo ""

    # Homebrew prüfen/installieren
    check_homebrew

    echo ""

    # llama.cpp prüfen/installieren
    check_llama_cpp

    echo ""
    print_success "Alle Voraussetzungen erfüllt"
}

create_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        print_success "Log-Verzeichnis erstellt: $LOG_DIR"
    fi
}

check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        return 1
    fi
    return 0
}

start_server() {
    local name=$1
    local model=$2
    local port=$3
    local context=$4
    local is_embedding=$5
    local ubatch_size=$6

    print_info "Starte $name auf Port $port..."

    # Port-Check
    if ! check_port $port; then
        print_warning "Port $port ist bereits belegt"
        local pid=$(lsof -ti:$port 2>/dev/null || echo "unbekannt")
        echo -e "         PID: $pid"
        return 1
    fi

    # Server starten
    local log_file="$LOG_DIR/llama-server-$port.log"
    local cmd="$LLAMA_SERVER -hf $model"

    if [ "$is_embedding" = "true" ]; then
        cmd="$cmd --embeddings"
        cmd="$cmd --parallel 2"
    else
        cmd="$cmd --jinja"
    fi

    cmd="$cmd -c $context --host 127.0.0.1 --port $port"

    # ubatch-size hinzufügen wenn gesetzt
    if [ -n "$ubatch_size" ]; then
        cmd="$cmd --ubatch-size $ubatch_size"
    fi

    # Im Hintergrund starten
    nohup $cmd > "$log_file" 2>&1 &
    local pid=$!

    # PID speichern
    echo "$pid" >> "$PID_FILE"

    # Kurz warten und prüfen ob Prozess läuft
    sleep 2
    if ps -p $pid > /dev/null 2>&1; then
        print_success "$name gestartet (PID: $pid)"
        echo -e "         Port: $port | Log: $log_file"
        return 0
    else
        print_error "$name konnte nicht gestartet werden"
        echo -e "         Siehe Log: $log_file"
        return 1
    fi
}

wait_for_health() {
    local port=$1
    local name=$2
    local max_attempts=30
    local attempt=0

    print_info "Warte auf Health-Check für $name..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://127.0.0.1:$port/health > /dev/null 2>&1; then
            print_success "$name ist bereit"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    print_warning "$name antwortet nicht auf Health-Checks"
    return 1
}

stop_servers() {
    print_info "Stoppe laufende Server..."

    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if ps -p $pid > /dev/null 2>&1; then
                kill $pid 2>/dev/null || true
                print_success "Server gestoppt (PID: $pid)"
            fi
        done < "$PID_FILE"
        rm "$PID_FILE"
    else
        print_warning "Keine laufenden Server gefunden"
    fi
}

show_status() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Server Status                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if ps -p $pid > /dev/null 2>&1; then
                local port=$(lsof -Pan -p $pid -i 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2 | head -n1)
                echo -e "${GREEN}●${NC} Running - PID: $pid | Port: ${port:-unbekannt}"

                # Health-Check
                if [ -n "$port" ] && curl -s http://127.0.0.1:$port/health > /dev/null 2>&1; then
                    echo -e "  ${GREEN}✓${NC} Health-Check OK"
                else
                    echo -e "  ${YELLOW}⚠${NC} Health-Check Failed"
                fi
            fi
        done < "$PID_FILE"
    else
        echo -e "${YELLOW}●${NC} Keine Server laufen"
    fi
    echo ""
}

print_usage() {
    cat << EOF
${CYAN}Verwendung:${NC}
    $0 [OPTION]

${CYAN}Optionen:${NC}
    start       Startet alle Server (installiert llama.cpp falls nötig)
    stop        Stoppt alle Server
    restart     Startet alle Server neu
    status      Zeigt den Status aller Server
    logs        Zeigt die letzten Logs
    install     Installiert/Aktualisiert llama.cpp via Homebrew
    help        Zeigt diese Hilfe

${CYAN}Beispiele:${NC}
    $0 start        # Prüft/installiert llama.cpp und startet Server
    $0 install      # Installiert llama.cpp manuell
    $0 status       # Zeigt Status
    $0 logs         # Zeigt Logs
EOF
}

show_logs() {
    print_info "Letzte Log-Einträge:"
    echo ""

    for log in "$LOG_DIR"/*.log; do
        if [ -f "$log" ]; then
            echo -e "${CYAN}═══ $(basename "$log") ═══${NC}"
            tail -n 10 "$log"
            echo ""
        fi
    done
}

manual_install() {
    print_header
    check_homebrew
    echo ""
    install_llama_cpp
    echo ""
    print_success "Installation abgeschlossen!"
}

# ==============================================================================
# Hauptfunktionen
# ==============================================================================

start_all() {
    print_header
    check_prerequisites
    create_log_dir

    echo ""

    # Chat Server starten
    start_server \
        "$CHAT_NAME" \
        "$CHAT_MODEL" \
        "$CHAT_PORT" \
        "$CHAT_CONTEXT" \
        "false" \
        ""

    echo ""

    # Embedding Server starten
    start_server \
        "$EMBEDDING_NAME" \
        "$EMBEDDING_MODEL" \
        "$EMBEDDING_PORT" \
        "$EMBEDDING_CONTEXT" \
        "true" \
        "$EMBEDDING_UBATCH"

    echo ""

    # Health-Checks
    wait_for_health $CHAT_PORT "$CHAT_NAME"
    wait_for_health $EMBEDDING_PORT "$EMBEDDING_NAME"

    echo ""
    print_success "Alle Server gestartet!"
    echo ""
    echo -e "${CYAN}Endpoints:${NC}"
    echo -e "  Chat:       ${GREEN}http://localhost:${CHAT_PORT}/v1/chat/completions${NC}"
    echo -e "  Embeddings: ${GREEN}http://localhost:${EMBEDDING_PORT}/v1/embeddings${NC}"
    echo ""
}

# ==============================================================================
# Main
# ==============================================================================

case "${1:-}" in
    start)
        start_all
        ;;
    stop)
        print_header
        stop_servers
        echo ""
        ;;
    restart)
        print_header
        stop_servers
        echo ""
        sleep 2
        start_all
        ;;
    status)
        print_header
        show_status
        ;;
    logs)
        print_header
        show_logs
        ;;
    install)
        manual_install
        ;;
    help|--help|-h)
        print_header
        print_usage
        ;;
    *)
        print_header
        print_usage
        exit 1
        ;;
esac