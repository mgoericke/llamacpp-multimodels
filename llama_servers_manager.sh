
#!/usr/bin/env bash

# ==============================================================================
# Llama.cpp Server Starter (Vereinfacht)
# ==============================================================================
# Startet mehrere llama-server Instanzen für Chat und Embeddings
# Voraussetzung: Brew und Ollama sind bereits installiert
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
CHAT_CONTEXT=4000

# Embedding Server
EMBEDDING_NAME="Embeddings (nomic-embed-text)"
EMBEDDING_MODEL="nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0"
EMBEDDING_PORT=8034
EMBEDDING_CONTEXT=1024
EMBEDDING_UBATCH=1024

# ==============================================================================
# Hilfsfunktionen
# ==============================================================================

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  🦙 Llama.cpp Server Manager (Vereinfacht)                  ${CYAN}║${NC}"
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

# Prüfe ob Ollama installiert ist
check_ollama() {
    print_info "Prüfe Ollama Installation..."
    
    if ! command -v ollama &> /dev/null; then
        print_error "Ollama ist nicht installiert"
        echo ""
        echo -e "${YELLOW}Bitte installiere Ollama zuerst:${NC}"
        echo -e "  https://ollama.com/download"
        exit 1
    else
        print_success "Ollama ist installiert ($(ollama --version))"
    fi
}

# Starte Chat Server
start_chat_server() {
    print_info "Starte Chat Server..."
    
    # Prüfe ob Modell bereits heruntergeladen ist
    if ! ollama list | grep -q "Qwen3-4B"; then
        print_step "Lade Qwen3-4B Modell herunter..."
        ollama pull ${CHAT_MODEL}
    else
        print_success "Qwen3-4B Modell bereits vorhanden"
    fi
    
    # Starte Server
    ollama run ${CHAT_MODEL} --port ${CHAT_PORT} --host 127.0.0.1 --context ${CHAT_CONTEXT} > ${LOG_DIR}/llama-server-${CHAT_PORT}.log 2>&1 &
    
    echo $! > ${PID_FILE}.chat
    print_success "Chat Server gestartet auf Port ${CHAT_PORT}"
}

# Starte Embedding Server
start_embedding_server() {
    print_info "Starte Embedding Server..."
    
    # Prüfe ob Modell bereits heruntergeladen ist
    if ! ollama list | grep -q "nomic-embed-text"; then
        print_step "Lade nomic-embed-text Modell herunter..."
        ollama pull ${EMBEDDING_MODEL}
    else
        print_success "nomic-embed-text Modell bereits vorhanden"
    fi
    
    # Starte Server
    ollama run ${EMBEDDING_MODEL} --port ${EMBEDDING_PORT} --host 127.0.0.1 --context ${EMBEDDING_CONTEXT} --ubatch ${EMBEDDING_UBATCH} > ${LOG_DIR}/llama-server-${EMBEDDING_PORT}.log 2>&1 &
    
    echo $! > ${PID_FILE}.embedding
    print_success "Embedding Server gestartet auf Port ${EMBEDDING_PORT}"
}

# Status prüfen
check_status() {
    print_info "Prüfe Server Status..."
    
    if [ -f "${PID_FILE}.chat" ]; then
        PID=$(cat ${PID_FILE}.chat)
        if ps -p $PID > /dev/null 2>&1; then
            print_success "Chat Server läuft (PID: $PID)"
        else
            print_warning "Chat Server PID $PID nicht gefunden"
        fi
    else
        print_warning "Kein Chat Server Prozess gefunden"
    fi
    
    if [ -f "${PID_FILE}.embedding" ]; then
        PID=$(cat ${PID_FILE}.embedding)
        if ps -p $PID > /dev/null 2>&1; then
            print_success "Embedding Server läuft (PID: $PID)"
        else
            print_warning "Embedding Server PID $PID nicht gefunden"
        fi
    else
        print_warning "Kein Embedding Server Prozess gefunden"
    fi
}

# Logs anzeigen
show_logs() {
    print_info "Zeige Logs..."
    
    if [ -f "${LOG_DIR}/llama-server-${CHAT_PORT}.log" ]; then
        echo -e "${BLUE}Chat Server Log:${NC}"
        tail -n 20 ${LOG_DIR}/llama-server-${CHAT_PORT}.log
        echo ""
    fi
    
    if [ -f "${LOG_DIR}/llama-server-${EMBEDDING_PORT}.log" ]; then
        echo -e "${BLUE}Embedding Server Log:${NC}"
        tail -n 20 ${LOG_DIR}/llama-server-${EMBEDDING_PORT}.log
        echo ""
    fi
}

# Hauptprogramm
main() {
    print_header
    
    # Prüfe Voraussetzungen
    check_ollama
    
    case "$1" in
        "start")
            print_step "Starte Server..."
            mkdir -p ${LOG_DIR}
            start_chat_server
            start_embedding_server
            echo ""
            print_success "Alle Server gestartet!"
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs
            ;;
        *)
            echo "Verwendung: $0 {start|status|logs}"
            exit 1
            ;;
    esac
}

# Starte Hauptprogramm mit allen übergebenen Argumenten
main "$@"
