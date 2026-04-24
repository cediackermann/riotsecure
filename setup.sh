#!/bin/bash
# All-in-one setup: installs everything on a single machine.
# For a split setup (Onyx on one machine, Ollama on another) use:
#   setup_onyx.sh  — on the Onyx device
#   setup_ollama.sh — on the Ollama device

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/steps/common.sh"
source "$SCRIPT_DIR/steps/preflight.sh"
source "$SCRIPT_DIR/steps/step_homebrew.sh"
source "$SCRIPT_DIR/steps/step_ollama.sh"
source "$SCRIPT_DIR/steps/step_repo.sh"
source "$SCRIPT_DIR/steps/step_docker.sh"
source "$SCRIPT_DIR/steps/step_onyx.sh"
source "$SCRIPT_DIR/steps/step_models.sh"
source "$SCRIPT_DIR/steps/step_webconfig.sh"
source "$SCRIPT_DIR/steps/step_rag.sh"

check_mac

echo ""
echo -e "${BLUE}RIoT Secure — Full Single-Device Setup${NC}"
echo ""
echo -e "${YELLOW}⏱  Estimated installation time: 20-40 minutes${NC}"
echo ""
echo "The following will be installed/configured:"
echo "  • Homebrew (package manager)"
echo "  • Ollama (AI model runtime)"
echo "  • Docker Desktop (containerization)"
echo "  • Onyx (web interface)"
echo "  • RIoT AI models (several GB download)"
echo ""

preflight_checks

install_homebrew
install_ollama
setup_repo
install_docker
install_onyx
setup_models
web_config "host.docker.internal"
rag_upload

# =============================================================================
# Done
# =============================================================================
print_step "Setup Complete!"

echo ""
echo -e "${GREEN}✓ All automated steps completed successfully!${NC}"
echo ""
echo -e "Access the web interface at: ${BLUE}http://localhost:3000${NC}"

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "Unable to detect")
if [ "$LOCAL_IP" != "Unable to detect" ]; then
    echo -e "From other devices on the network: ${BLUE}http://${LOCAL_IP}:3000${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - View Onyx logs:    cd ~/riotsecure/onyx_data && docker compose logs -f"
echo "  - Restart Onyx:      cd ~/riotsecure/onyx_data/deployment && docker compose restart"
echo "  - List Ollama models: ollama list"
echo "  - Update models:      cd ~/riotsecure && ./updateModels.sh modelfiles"
echo ""
