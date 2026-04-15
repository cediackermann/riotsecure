#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

wait_for_user() {
    echo -e "\n${YELLOW}Press ENTER when you have completed the above step...${NC}"
    read
}

check_mac() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS. Exiting."
        exit 1
    fi
}

# Check if running on macOS
check_mac

print_step "RIoT AI Setup Script - Mac Mini Configuration"
echo "This script will guide you through setting up the RIoT AI system."
echo "Some steps require manual interaction and will pause for your input."
echo ""
echo "Press ENTER to begin..."
read

# =============================================================================
# STEP 1: Homebrew
# =============================================================================
print_step "STEP 1: Installing Homebrew"

if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
    brew --version
else
    print_warning "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to shell profile
    echo >> ~/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"

    print_success "Homebrew installed successfully"
fi

# =============================================================================
# STEP 2: Ollama
# =============================================================================
print_step "STEP 2: Installing Ollama"

if command -v ollama &> /dev/null; then
    print_success "Ollama is already installed"
    ollama --version
else
    print_warning "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    print_success "Ollama installed successfully"
fi

# =============================================================================
# STEP 3: Docker Desktop
# =============================================================================
print_step "STEP 3: Installing Docker Desktop"

if [ -d "/Applications/Docker.app" ]; then
    print_success "Docker Desktop is already installed"
else
    print_warning "Installing Docker Desktop via Homebrew..."
    brew install --cask docker
    print_success "Docker Desktop installed"
fi

print_warning "Opening Docker Desktop..."
open -a Docker

echo ""
echo "MANUAL STEP REQUIRED:"
echo "1. Click through the Docker Desktop installer"
echo "2. Install any prompted software updates"
echo "3. Go to Docker → Settings → Resources and set:"
echo "   - CPU limit: MAX"
echo "   - Memory limit: 20 GB"
echo "   - Disk usage limit: MAX"
echo "4. Click 'Apply & Restart'"
echo ""
wait_for_user

# Wait for Docker to be ready
print_warning "Waiting for Docker to be ready..."
while ! docker info &> /dev/null; do
    echo "Waiting for Docker daemon..."
    sleep 5
done
print_success "Docker is ready"

# =============================================================================
# STEP 4: Onyx
# =============================================================================
print_step "STEP 4: Installing Onyx"

if [ -d ~/onyx_data ]; then
    print_warning "Onyx data directory already exists. Skipping installation."
else
    print_warning "Installing Onyx..."
    echo "When prompted:"
    echo "  1. Press ENTER to acknowledge"
    echo "  2. Choose '2' for Standard"
    echo "  3. Press ENTER for Edge"
    echo ""

    # Download and run Onyx installer
    # Note: The interactive prompts need to be handled by the user
    curl -fsSL https://onyx.app/install_onyx.sh | bash

    print_success "Onyx installation complete"
fi

# Prevent sleep
print_warning "Configuring power settings to prevent sleep..."
sudo pmset -a sleep 0 disksleep 0
print_success "Sleep prevention configured"

# =============================================================================
# STEP 5: Ollama Models
# =============================================================================
print_step "STEP 5: Setting up Ollama Models"

# Check if we're already in the riotsecure directory
if [ ! -f "./updateModels.sh" ]; then
    if [ -d ~/riotsecure ]; then
        print_warning "riotsecure directory already exists"
        cd ~/riotsecure
        git pull
    else
        print_warning "Cloning riotsecure repository..."
        cd ~
        git clone https://github.com/cediackermann/riotsecure.git
        cd ~/riotsecure
    fi
else
    print_success "Already in riotsecure directory"
fi

print_warning "Creating Ollama models from modelfiles..."
if [ -f "./updateModels.sh" ]; then
    chmod +x ./updateModels.sh
    ./updateModels.sh modelfiles
    print_success "Ollama models created successfully"
else
    print_error "updateModels.sh not found!"
fi

# =============================================================================
# STEP 6: Web Interface Configuration
# =============================================================================
print_step "STEP 6: Web Interface Configuration"

echo ""
echo "MANUAL STEPS REQUIRED:"
echo ""
echo "1. Open your browser to http://localhost:3000"
echo "2. Create an admin account"
echo "3. Go to Admin Panel → Language Models:"
echo "   - Select 'Ollama' as provider and give it a name"
echo "   - Set API base URL to: http://host.docker.internal:11434"
echo "   - Refresh the model list"
echo "   - Select at least the three RIoT models"
echo "   - Click 'Connect'"
echo "4. Go to Admin Panel → Chat Preferences → System Prompt → Modify Prompt"
echo "   - Delete the entire prompt"
echo "   - Save"
echo ""
wait_for_user

# =============================================================================
# STEP 7: RAG Content Upload
# =============================================================================
print_step "STEP 7: RAG Content Upload"

echo "Choose content upload method:"
echo "  A - Upload as File (recommended)"
echo "  B - Upload as URL"
echo "  S - Skip this step"
echo ""
read -p "Enter your choice (A/B/S): " choice

case $choice in
    [Aa])
        print_warning "Fetching content from riot-sources.txt..."
        if [ -f "./fetchContent.sh" ]; then
            chmod +x ./fetchContent.sh
            if [ -f "./riot-sources.txt" ]; then
                ./fetchContent.sh riot-sources.txt
                print_success "Content fetched successfully"

                echo ""
                echo "MANUAL STEP REQUIRED:"
                echo "1. In the web interface, go to Admin Panel → Add Connector → File"
                echo "2. Give the connector a name"
                echo "3. Upload the files from ~/riotsecure/content"
                echo "4. Wait ~30 seconds for indexing to complete"
                echo ""
            else
                print_error "riot-sources.txt not found!"
            fi
        else
            print_error "fetchContent.sh not found!"
        fi
        wait_for_user
        ;;
    [Bb])
        echo ""
        echo "MANUAL STEP REQUIRED:"
        echo "1. In the web interface, go to Admin Panel → Add Connector → Web"
        echo "2. Add each URL from riot-sources.txt as a separate connector"
        echo "3. Use scrape method 'Single'"
        echo "4. Wait ~30 seconds for indexing to complete"
        echo ""
        wait_for_user
        ;;
    [Ss])
        print_warning "Skipping RAG content upload"
        ;;
    *)
        print_warning "Invalid choice. Skipping RAG content upload"
        ;;
esac

# =============================================================================
# COMPLETION
# =============================================================================
print_step "Setup Complete!"

echo ""
echo -e "${GREEN}✓ All automated steps completed successfully!${NC}"
echo ""
echo "Your RIoT AI system should now be ready to use."
echo ""
echo "Access the web interface at: ${BLUE}http://localhost:3000${NC}"
echo ""
echo "Useful commands:"
echo "  - View Onyx logs: cd ~/onyx_data && docker compose logs -f"
echo "  - Restart Onyx: cd ~/onyx_data && docker compose restart"
echo "  - List Ollama models: ollama list"
echo "  - Update Ollama models: cd ~/riotsecure && ./updateModels.sh modelfiles"
echo ""
