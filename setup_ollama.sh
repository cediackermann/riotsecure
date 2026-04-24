#!/bin/bash
# Setup script for the Ollama device.
# Run this on the machine that will host AI models only.
# No Docker required on this device.
#
# Usage: ./setup_ollama.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/steps/common.sh"
source "$SCRIPT_DIR/steps/preflight.sh"
source "$SCRIPT_DIR/steps/step_homebrew.sh"
source "$SCRIPT_DIR/steps/step_ollama.sh"
source "$SCRIPT_DIR/steps/step_repo.sh"
source "$SCRIPT_DIR/steps/step_models.sh"

check_mac

echo ""
echo -e "${BLUE}RIoT Secure — Ollama Device Setup${NC}"
echo "This machine will run Ollama and serve AI models to the Onyx device."
echo ""
echo "Estimated installation time: 10-20 minutes"
echo ""
echo "The following will be installed/configured:"
echo "  • Homebrew (package manager)"
echo "  • Ollama (AI model runtime)"
echo "  • RIoT AI models (several GB download)"
echo ""

preflight_checks --skip-docker

install_homebrew
setup_repo
install_ollama
setup_models

# =============================================================================
# Done
# =============================================================================
print_step "Ollama Device Setup Complete!"

echo ""
echo -e "${GREEN}✓ Ollama is running and models are loaded.${NC}"
echo ""
echo "Next steps:"
echo "  1. Note this machine's local IP address:"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

if [ -n "$LOCAL_IP" ]; then
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}  Run this command on the Onyx device:${NC}"
    echo ""
    echo -e "  ${YELLOW}./setup_onyx.sh --ollama-host ${LOCAL_IP}${NC}"
    echo ""
    echo -e "${BLUE}===================================================${NC}"
else
    print_warning "Could not detect local IP address automatically."
    echo "  Find it manually with:  ipconfig getifaddr en0"
    echo "  Then on the Onyx device run:"
    echo -e "  ${YELLOW}./setup_onyx.sh --ollama-host <this-machine-IP>${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - List Ollama models:   ollama list"
echo "  - Update models:        cd ~/riotsecure && ./updateModels.sh modelfiles"
echo "  - View Ollama logs:     tail -f /tmp/ollama.log"
echo ""
