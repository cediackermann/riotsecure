#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status indicators
PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "$PASS $2 installed"
        return 0
    else
        echo -e "$FAIL $2 not found"
        return 1
    fi
}

check_service() {
    if $1 &> /dev/null; then
        echo -e "$PASS $2"
        return 0
    else
        echo -e "$FAIL $2"
        return 1
    fi
}

# Main status check
print_header "RIoT AI System Status Check"

OVERALL_STATUS=0

# =============================================================================
# System Information
# =============================================================================
print_section "System Information"

echo -e "$INFO macOS Version: $(sw_vers -productVersion)"
echo -e "$INFO Hostname: $(hostname)"

# Check available disk space
AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_GB" -lt 20 ]; then
    echo -e "$WARN Available disk space: ${AVAILABLE_GB}GB (recommended: 20GB+)"
    OVERALL_STATUS=1
else
    echo -e "$PASS Available disk space: ${AVAILABLE_GB}GB"
fi

# Check total memory
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

# Homebrew
if check_command brew "Homebrew"; then
    echo -e "  ${INFO} Version: $(brew --version | head -n1)"
else
    OVERALL_STATUS=1
fi

# Ollama
if check_command ollama "Ollama"; then
    echo -e "  ${INFO} Version: $(ollama --version 2>&1 | head -n1)"
else
    OVERALL_STATUS=1
fi

# Docker Desktop
if [ -d "/Applications/Docker.app" ]; then
    echo -e "$PASS Docker Desktop installed"
else
    echo -e "$FAIL Docker Desktop not found"
    OVERALL_STATUS=1
fi

# =============================================================================
# Docker Service
# =============================================================================
print_section "Docker Service"

if check_service "docker info" "Docker daemon running"; then
    # Get Docker resource settings
    DOCKER_CPUS=$(docker info 2>/dev/null | grep "CPUs:" | awk '{print $2}')
    DOCKER_MEM=$(docker info 2>/dev/null | grep "Total Memory:" | awk '{print $3$4}')

    echo -e "  ${INFO} CPUs allocated: ${DOCKER_CPUS}"
    echo -e "  ${INFO} Memory allocated: ${DOCKER_MEM}"

    # Check running containers
    CONTAINER_COUNT=$(docker ps -q | wc -l | tr -d ' ')
    echo -e "  ${INFO} Running containers: ${CONTAINER_COUNT}"
else
    echo -e "$WARN Docker is not running. Start Docker Desktop to continue."
    OVERALL_STATUS=1
fi

# =============================================================================
# Ollama Service
# =============================================================================
print_section "Ollama Service"

if pgrep -x "ollama" > /dev/null; then
    echo -e "$PASS Ollama service running"

    # Check available models
    if command -v ollama &> /dev/null; then
        echo -e "\n  Available models:"
        MODELS=$(ollama list 2>/dev/null)
        if [ -n "$MODELS" ]; then
            echo "$MODELS" | tail -n +2 | while read line; do
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
    fi
else
    echo -e "$WARN Ollama service not running"
    echo -e "  ${INFO} Start with: ollama serve"
    OVERALL_STATUS=1
fi

# =============================================================================
# Onyx Installation
# =============================================================================
print_section "Onyx"

if [ -d ~/riotsecure/onyx_data ]; then
    echo -e "$PASS Onyx data directory exists"

    # Check if Onyx containers are running
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        cd ~/riotsecure/onyx_data 2>/dev/null
        if [ -f "docker-compose.yaml" ] || [ -f "docker-compose.yml" ]; then
            echo -e "$PASS Docker Compose file found"

            # Check running Onyx containers
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
        cd - > /dev/null 2>&1
    fi
else
    echo -e "$FAIL Onyx data directory not found"
    echo -e "  ${INFO} Run ./setup.sh to install"
    OVERALL_STATUS=1
fi

# =============================================================================
# Web Interface
# =============================================================================
print_section "Web Interface"

# Check if port 3000 is in use
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "$PASS Port 3000 is active"

    # Try to connect to the web interface
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo -e "$PASS Web interface responding"
        echo -e "\n  ${INFO} Access at: ${GREEN}http://localhost:3000${NC}"

        # Get local IP for network access
        LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
        if [ -n "$LOCAL_IP" ]; then
            echo -e "  ${INFO} Network access: ${GREEN}http://${LOCAL_IP}:3000${NC}"
        fi
    else
        echo -e "$WARN Port 3000 is active but interface not responding"
        OVERALL_STATUS=1
    fi
else
    echo -e "$FAIL Port 3000 not in use"
    echo -e "  ${INFO} Onyx containers may not be running"
    OVERALL_STATUS=1
fi

# =============================================================================
# Repository Status
# =============================================================================
print_section "Repository"

if [ -d ~/riotsecure ]; then
    echo -e "$PASS Repository exists at ~/riotsecure"

    cd ~/riotsecure 2>/dev/null
    if [ -d .git ]; then
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
        echo -e "  ${INFO} Current branch: ${CURRENT_BRANCH}"

        # Check for updates
        git fetch --quiet 2>/dev/null
        LOCAL=$(git rev-parse @ 2>/dev/null)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "  $WARN Updates available (run: git pull)"
        else
            echo -e "  $PASS Repository up to date"
        fi
    fi
    cd - > /dev/null 2>&1
else
    echo -e "$FAIL Repository not found at ~/riotsecure"
    OVERALL_STATUS=1
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Summary"

if [ $OVERALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ All systems operational${NC}\n"
    exit 0
else
    echo -e "${YELLOW}⚠ Some issues detected - review output above${NC}\n"
    echo "Common fixes:"
    echo "  • Docker not running → Open Docker Desktop"
    echo "  • Ollama not running → Run: ollama serve"
    echo "  • Onyx not running → cd ~/riotsecure/onyx_data && docker compose up -d"
    echo "  • Low disk space → Free up disk space"
    echo ""
    exit 1
fi
