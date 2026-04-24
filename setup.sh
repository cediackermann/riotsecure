#!/bin/bash
# All-in-one setup: installs everything on a single machine.
# For a split setup (Onyx on one machine, Ollama on another) use:
#   setup_onyx.sh  — on the Onyx device
#   setup_ollama.sh — on the Ollama device
#
# Usage (one-liner):
#   bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup.sh)

set -e

# Minimal helpers needed before the repo is cloned
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
_info()    { echo -e "${BLUE}$1${NC}"; }
_success() { echo -e "${GREEN}✓ $1${NC}"; }
_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
_error()   { echo -e "${RED}✗ $1${NC}"; exit 1; }

[[ "$OSTYPE" != "darwin"* ]] && _error "This script is designed for macOS."

# ---------------------------------------------------------------------------
# Bootstrap: Homebrew first (installs Xcode CLT → git), then clone the repo
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    _info "Installing Homebrew (this also installs git via Xcode CLT)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> ~/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    _success "Homebrew installed"
fi

_info "Setting up riotsecure repository..."
if [ -d ~/riotsecure ]; then
    _warning "Repository already exists — updating..."
    git -C ~/riotsecure pull
else
    git clone https://github.com/cediackermann/riotsecure.git ~/riotsecure
fi
_success "Repository ready at ~/riotsecure"

# Source all shared step files from the cloned repo
REPO="$HOME/riotsecure"
source "$REPO/steps/common.sh"
source "$REPO/steps/preflight.sh"
source "$REPO/steps/step_homebrew.sh"
source "$REPO/steps/step_ollama.sh"
source "$REPO/steps/step_docker.sh"
source "$REPO/steps/step_onyx.sh"
source "$REPO/steps/step_models.sh"
source "$REPO/steps/step_webconfig.sh"
source "$REPO/steps/step_rag.sh"

# ---------------------------------------------------------------------------
# Main setup
# ---------------------------------------------------------------------------
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

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
if [ -n "$LOCAL_IP" ]; then
    echo -e "From other devices on the network: ${BLUE}http://${LOCAL_IP}:3000${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - View Onyx logs:    cd ~/riotsecure/onyx_data && docker compose logs -f"
echo "  - Restart Onyx:      cd ~/riotsecure/onyx_data/deployment && docker compose restart"
echo "  - List Ollama models: ollama list"
echo "  - Update models:      cd ~/riotsecure && ./updateModels.sh modelfiles"
echo ""
