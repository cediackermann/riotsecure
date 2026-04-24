#!/bin/bash
# Setup script for the Ollama device.
# Run this on the machine that will host AI models only.
# No Docker required on this device.
#
# Usage (one-liner):
#   bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_ollama.sh)

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
source "$REPO/steps/step_models.sh"
source "$REPO/steps/step_sleep.sh"

# ---------------------------------------------------------------------------
# Main setup
# ---------------------------------------------------------------------------
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
install_ollama
setup_models
prevent_sleep

# =============================================================================
# Done
# =============================================================================
print_step "Ollama Device Setup Complete!"

echo ""
echo -e "${GREEN}✓ Ollama is running and models are loaded.${NC}"
echo ""

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

if [ -n "$LOCAL_IP" ]; then
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}  Run this command on the Onyx device:${NC}"
    echo ""
    echo -e "  ${YELLOW}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh) --ollama-host ${LOCAL_IP}${NC}"
    echo ""
    echo -e "${BLUE}===================================================${NC}"
else
    print_warning "Could not detect local IP address automatically."
    echo "  Find it manually with:  ipconfig getifaddr en0"
    echo "  Then on the Onyx device run:"
    echo -e "  ${YELLOW}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh) --ollama-host <this-machine-IP>${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - List Ollama models:   ollama list"
echo "  - Update models:        cd ~/riotsecure && ./updateModels.sh modelfiles"
echo "  - View Ollama logs:     tail -f /tmp/ollama.log"
echo ""
