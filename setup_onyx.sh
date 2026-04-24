#!/bin/bash
# Setup script for the Onyx device.
# Run this on the machine that will host the Onyx web interface.
# Docker is required on this device; Ollama is NOT installed here.
#
# Usage:
#   ./setup_onyx.sh                         # auto-detect Ollama host
#   ./setup_onyx.sh --ollama-host <IP>      # override with a specific host

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/steps/common.sh"
source "$SCRIPT_DIR/steps/preflight.sh"
source "$SCRIPT_DIR/steps/step_homebrew.sh"
source "$SCRIPT_DIR/steps/step_repo.sh"
source "$SCRIPT_DIR/steps/step_docker.sh"
source "$SCRIPT_DIR/steps/step_onyx.sh"
source "$SCRIPT_DIR/steps/step_webconfig.sh"
source "$SCRIPT_DIR/steps/step_rag.sh"

check_mac

# ---------------------------------------------------------------------------
# Detect where Ollama is running
# ---------------------------------------------------------------------------
detect_ollama_host() {
    # 1. Check if Ollama is reachable on the Docker host (single-device)
    if curl -sf --connect-timeout 2 http://host.docker.internal:11434 >/dev/null 2>&1; then
        echo "host.docker.internal"
        return
    fi

    # 2. Scan the local /24 subnet for port 11434
    local LOCAL_IP
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
    if [ -z "$LOCAL_IP" ]; then
        echo ""
        return
    fi

    local SUBNET
    SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3)

    print_warning "Ollama not found locally — scanning ${SUBNET}.0/24 for Ollama..."

    local FOUND=()
    for i in $(seq 1 254); do
        (nc -z -w 1 "${SUBNET}.${i}" 11434 2>/dev/null && echo "${SUBNET}.${i}") &
    done
    # Collect results as background jobs finish
    while IFS= read -r line; do
        FOUND+=("$line")
    done < <(wait; jobs -p | xargs -I{} wait {} 2>/dev/null; true)

    # Re-run synchronously to get output (background approach above doesn't capture stdout cleanly)
    FOUND=()
    for i in $(seq 1 254); do
        if nc -z -w 1 "${SUBNET}.${i}" 11434 2>/dev/null; then
            FOUND+=("${SUBNET}.${i}")
        fi
    done

    if [ ${#FOUND[@]} -eq 1 ]; then
        echo "${FOUND[0]}"
    elif [ ${#FOUND[@]} -gt 1 ]; then
        # Multiple hosts found — let the user pick
        echo "" >&2
        print_warning "Multiple hosts with Ollama found:" >&2
        for i in "${!FOUND[@]}"; do
            echo "  $((i+1))) ${FOUND[$i]}" >&2
        done
        echo "" >&2
        read -p "Select the Ollama host (1-${#FOUND[@]}): " pick >&2
        echo "${FOUND[$((pick-1))]}"
    else
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
OLLAMA_HOST_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ollama-host)
            OLLAMA_HOST_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--ollama-host <IP or hostname>]"
            exit 1
            ;;
    esac
done

echo ""
echo -e "${BLUE}RIoT Secure — Onyx Device Setup${NC}"
echo ""
echo "Estimated installation time: 15-30 minutes"
echo ""
echo "The following will be installed/configured:"
echo "  • Homebrew (package manager)"
echo "  • Docker Desktop (containerization)"
echo "  • Onyx (web interface)"
echo ""

preflight_checks

install_homebrew
setup_repo
install_docker
install_onyx

# ---------------------------------------------------------------------------
# Resolve Ollama host (after Docker is running so host.docker.internal works)
# ---------------------------------------------------------------------------
if [ -n "$OLLAMA_HOST_OVERRIDE" ]; then
    OLLAMA_HOST="$OLLAMA_HOST_OVERRIDE"
    echo -e "Using provided Ollama host: ${BLUE}${OLLAMA_HOST}${NC}"
else
    print_warning "Detecting Ollama host..."
    OLLAMA_HOST=$(detect_ollama_host)

    if [ -z "$OLLAMA_HOST" ]; then
        print_warning "Could not detect Ollama automatically."
        read -p "Enter the IP address or hostname of the Ollama device: " OLLAMA_HOST
    fi

    if [ "$OLLAMA_HOST" = "host.docker.internal" ]; then
        print_success "Ollama detected on this machine (single-device mode)"
    else
        print_success "Ollama detected at: ${OLLAMA_HOST}"
    fi
fi

web_config "$OLLAMA_HOST"
rag_upload

# =============================================================================
# Done
# =============================================================================
print_step "Onyx Device Setup Complete!"

echo ""
echo -e "${GREEN}✓ All automated steps completed successfully!${NC}"
echo ""
echo -e "Access the web interface at: ${BLUE}http://localhost:3000${NC}"

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
if [ -n "$LOCAL_IP" ]; then
    echo -e "From other devices on the network: ${BLUE}http://${LOCAL_IP}:3000${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - View Onyx logs:    cd ~/riotsecure/onyx_data && docker compose logs -f"
echo "  - Restart Onyx:      cd ~/riotsecure/onyx_data/deployment && docker compose restart"
echo ""
