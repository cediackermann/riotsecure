#!/bin/bash

# Source shared helpers if running from the repo; otherwise define inline.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/steps/common.sh" ]; then
    source "$SCRIPT_DIR/steps/common.sh"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    print_header()  { echo -e "\n${BLUE}===================================================${NC}\n${BLUE}$1${NC}\n${BLUE}===================================================${NC}\n"; }
    print_section() { echo -e "\n${BLUE}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_error()   { echo -e "${RED}✗ $1${NC}"; }
fi

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

# ---------------------------------------------------------------------------
# Detect which role this machine plays
# ---------------------------------------------------------------------------
HAS_DOCKER=0
HAS_OLLAMA=0
HAS_ONYX=0

[ -d "/Applications/Docker.app" ] && HAS_DOCKER=1
command -v ollama &>/dev/null && HAS_OLLAMA=1
[ -d ~/riotsecure/onyx_data ] && HAS_ONYX=1

if [ $HAS_OLLAMA -eq 1 ] && [ $HAS_DOCKER -eq 1 ]; then
    DEVICE_MODE="single"
elif [ $HAS_OLLAMA -eq 1 ]; then
    DEVICE_MODE="ollama"
elif [ $HAS_DOCKER -eq 1 ] || [ $HAS_ONYX -eq 1 ]; then
    DEVICE_MODE="onyx"
else
    DEVICE_MODE="unknown"
fi

print_header "RIoT AI System Status Check"

case $DEVICE_MODE in
    single) echo -e "${INFO} Mode: ${BLUE}single-device${NC} (Ollama + Onyx)" ;;
    ollama) echo -e "${INFO} Mode: ${BLUE}Ollama device${NC}" ;;
    onyx)   echo -e "${INFO} Mode: ${BLUE}Onyx device${NC}" ;;
    *)      echo -e "${WARN} Mode: ${YELLOW}unknown${NC} — no RIoT components detected" ;;
esac

OVERALL_STATUS=0

# =============================================================================
# System Information
# =============================================================================
print_section "System Information"

echo -e "$INFO macOS Version: $(sw_vers -productVersion)"
echo -e "$INFO Hostname: $(hostname)"

AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_GB" -lt 20 ]; then
    echo -e "$WARN Available disk space: ${AVAILABLE_GB}GB (recommended: 20GB+)"
    OVERALL_STATUS=1
else
    echo -e "$PASS Available disk space: ${AVAILABLE_GB}GB"
fi

TOTAL_MEM_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
if [ "$TOTAL_MEM_GB" -lt 16 ]; then
    echo -e "$WARN Total memory: ${TOTAL_MEM_GB}GB (recommended: 16GB+)"
else
    echo -e "$PASS Total memory: ${TOTAL_MEM_GB}GB"
fi

# =============================================================================
# Core Components
# =============================================================================
print_section "Core Components"

if command -v brew &>/dev/null; then
    echo -e "$PASS Homebrew installed  ($(brew --version | head -n1))"
else
    echo -e "$FAIL Homebrew not found"
    OVERALL_STATUS=1
fi

# Ollama — only expected on single or ollama devices
if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "ollama" ]; then
    if command -v ollama &>/dev/null; then
        echo -e "$PASS Ollama installed  ($(ollama --version 2>&1 | head -n1))"
    else
        echo -e "$FAIL Ollama not found"
        OVERALL_STATUS=1
    fi
else
    echo -e "$INFO Ollama not expected on this device (Onyx-only mode)"
fi

# Docker — only expected on single or onyx devices
if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "onyx" ]; then
    if [ -d "/Applications/Docker.app" ]; then
        echo -e "$PASS Docker Desktop installed"
    else
        echo -e "$FAIL Docker Desktop not found"
        OVERALL_STATUS=1
    fi
else
    echo -e "$INFO Docker not expected on this device (Ollama-only mode)"
fi

# =============================================================================
# Ollama Service (single / ollama devices only)
# =============================================================================
if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "ollama" ]; then
    print_section "Ollama Service"

    if pgrep -x "ollama" > /dev/null; then
        echo -e "$PASS Ollama service running"

        echo -e "\n  Available models:"
        MODELS=$(ollama list 2>/dev/null)
        if [ -n "$MODELS" ]; then
            echo "$MODELS" | tail -n +2 | while read -r line; do
                MODEL_NAME=$(echo "$line" | awk '{print $1}')
                if [[ $MODEL_NAME == riot* ]]; then
                    echo -e "  $PASS $line"
                else
                    echo -e "  $INFO $line"
                fi
            done
        else
            echo -e "  $WARN No models found"
            OVERALL_STATUS=1
        fi
    else
        echo -e "$WARN Ollama service not running"
        echo -e "  ${INFO} Start with: ollama serve"
        OVERALL_STATUS=1
    fi
fi

# =============================================================================
# Docker Service (single / onyx devices only)
# =============================================================================
if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "onyx" ]; then
    print_section "Docker Service"

    if docker info &>/dev/null; then
        DOCKER_CPUS=$(docker info 2>/dev/null | grep "CPUs:" | awk '{print $2}')
        DOCKER_MEM=$(docker info 2>/dev/null | grep "Total Memory:" | awk '{print $3$4}')
        CONTAINER_COUNT=$(docker ps -q | wc -l | tr -d ' ')

        echo -e "$PASS Docker daemon running"
        echo -e "  ${INFO} CPUs allocated: ${DOCKER_CPUS}"
        echo -e "  ${INFO} Memory allocated: ${DOCKER_MEM}"
        echo -e "  ${INFO} Running containers: ${CONTAINER_COUNT}"
    else
        echo -e "$WARN Docker is not running. Start Docker Desktop to continue."
        OVERALL_STATUS=1
    fi

    # =============================================================================
    # Onyx
    # =============================================================================
    print_section "Onyx"

    if [ -d ~/riotsecure/onyx_data ]; then
        echo -e "$PASS Onyx data directory exists"

        if docker info &>/dev/null; then
            cd ~/riotsecure/onyx_data 2>/dev/null
            if [ -f "docker-compose.yaml" ] || [ -f "docker-compose.yml" ]; then
                echo -e "$PASS Docker Compose file found"

                ONYX_CONTAINERS=$(docker ps --filter "name=onyx" -q | wc -l | tr -d ' ')
                if [ "$ONYX_CONTAINERS" -gt 0 ]; then
                    echo -e "$PASS Onyx containers running: ${ONYX_CONTAINERS}"
                    docker ps --filter "name=onyx" --format "  $INFO {{.Names}} ({{.Status}})"
                else
                    echo -e "$WARN No Onyx containers running"
                    echo -e "  ${INFO} Start with: cd ~/riotsecure/onyx_data && docker compose up -d"
                    OVERALL_STATUS=1
                fi
            fi
            cd - >/dev/null 2>&1
        fi
    else
        echo -e "$FAIL Onyx data directory not found"
        OVERALL_STATUS=1
    fi

    # =============================================================================
    # Web Interface
    # =============================================================================
    print_section "Web Interface"

    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
            echo -e "$PASS Web interface responding at http://localhost:3000"

            LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
            if [ -n "$LOCAL_IP" ]; then
                echo -e "  ${INFO} Network access: ${GREEN}http://${LOCAL_IP}:3000${NC}"
            fi
        else
            echo -e "$WARN Port 3000 active but interface not responding"
            OVERALL_STATUS=1
        fi
    else
        echo -e "$FAIL Port 3000 not in use — Onyx containers may not be running"
        OVERALL_STATUS=1
    fi
fi

# =============================================================================
# Repository
# =============================================================================
print_section "Repository"

if [ -d ~/riotsecure ]; then
    echo -e "$PASS Repository exists at ~/riotsecure"

    cd ~/riotsecure 2>/dev/null
    if [ -d .git ]; then
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
        echo -e "  ${INFO} Branch: ${CURRENT_BRANCH}"

        git fetch --quiet 2>/dev/null
        LOCAL=$(git rev-parse @ 2>/dev/null)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "  $WARN Updates available — run: git pull"
        else
            echo -e "  $PASS Repository up to date"
        fi
    fi
    cd - >/dev/null 2>&1
else
    echo -e "$FAIL Repository not found at ~/riotsecure"
    OVERALL_STATUS=1
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Summary"

if [ $OVERALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ All systems operational${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ Some issues detected — review output above${NC}"
    echo ""
    echo "Common fixes:"
    if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "ollama" ]; then
        echo "  • Ollama not running  → ollama serve"
        echo "  • Update models       → cd ~/riotsecure && ./updateModels.sh modelfiles"
    fi
    if [ "$DEVICE_MODE" = "single" ] || [ "$DEVICE_MODE" = "onyx" ]; then
        echo "  • Docker not running  → Open Docker Desktop"
        echo "  • Onyx not running    → cd ~/riotsecure/onyx_data && docker compose up -d"
    fi
    echo "  • Low disk space      → Free up disk space"
    echo ""
    exit 1
fi
