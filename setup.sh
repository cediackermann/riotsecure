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

preflight_checks() {
    print_step "Pre-flight System Checks"

    local PREFLIGHT_FAILED=0

    # Check macOS version
    MACOS_VERSION=$(sw_vers -productVersion)
    MACOS_MAJOR=$(echo $MACOS_VERSION | cut -d. -f1)
    echo -e "macOS Version: ${BLUE}$MACOS_VERSION${NC}"

    if [ "$MACOS_MAJOR" -lt 12 ]; then
        print_error "macOS 12 (Monterey) or later recommended. You have: $MACOS_VERSION"
        PREFLIGHT_FAILED=1
    else
        print_success "macOS version compatible"
    fi

    # Check available disk space
    AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
    echo -e "Available disk space: ${BLUE}${AVAILABLE_GB}GB${NC}"

    if [ "$AVAILABLE_GB" -lt 30 ]; then
        print_error "Insufficient disk space. Required: 30GB+, Available: ${AVAILABLE_GB}GB"
        echo "  Docker images, Ollama models, and Onyx require significant storage"
        PREFLIGHT_FAILED=1
    elif [ "$AVAILABLE_GB" -lt 50 ]; then
        print_warning "Low disk space. Recommended: 50GB+, Available: ${AVAILABLE_GB}GB"
        echo "  Installation will proceed but may fail if space runs out"
    else
        print_success "Sufficient disk space available"
    fi

    # Check total memory
    TOTAL_MEM_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    echo -e "Total system memory: ${BLUE}${TOTAL_MEM_GB}GB${NC}"

    if [ "$TOTAL_MEM_GB" -lt 16 ]; then
        print_warning "Low memory. Recommended: 16GB+, Available: ${TOTAL_MEM_GB}GB"
        echo "  Docker will be configured with 20GB limit (may need adjustment)"
    else
        print_success "Sufficient memory available"
    fi

    # Check internet connectivity
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connection detected"
        echo "  Internet required to download Homebrew, Docker, Ollama, etc."
        PREFLIGHT_FAILED=1
    fi

    # Check if Docker is already running (might conflict)
    if pgrep -x "Docker" > /dev/null 2>&1; then
        print_warning "Docker Desktop is already running"
        echo "  This is fine if it's already installed, otherwise it may cause conflicts"
    fi

    # Check if port 3000 is already in use
    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port 3000 is already in use"
        echo "  Onyx web interface requires port 3000 to be available"
        echo "  You may need to stop the conflicting service"
    fi

    # Estimate installation time
    echo ""
    echo -e "${YELLOW}⏱  Estimated installation time: 20-40 minutes${NC}"
    echo "  (depends on internet speed and system performance)"
    echo ""

    # Show what will be installed
    echo "The following will be installed/configured:"
    echo "  • Homebrew (package manager)"
    echo "  • Ollama (AI model runtime)"
    echo "  • Docker Desktop (containerization)"
    echo "  • Onyx (web interface)"
    echo "  • RIoT AI models (several GB download)"
    echo ""

    if [ $PREFLIGHT_FAILED -eq 1 ]; then
        print_error "Pre-flight checks failed. Please resolve the issues above."
        echo ""
        echo "Continue anyway? (not recommended) [y/N]"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_error "Setup aborted by user"
            exit 1
        fi
    else
        print_success "Pre-flight checks passed"
    fi

    echo ""
    echo "Press ENTER to begin installation..."
    read
}

# Check if running on macOS
check_mac

# Run pre-flight checks
preflight_checks

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

# Ensure Ollama service is running
print_warning "Starting Ollama service..."
if ! pgrep -x "ollama" > /dev/null; then
    # Start Ollama in the background
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3  # Give it time to start

    if pgrep -x "ollama" > /dev/null; then
        print_success "Ollama service started"
    else
        print_warning "Ollama service may not have started properly"
        echo "  Check logs at: /tmp/ollama.log"
    fi
else
    print_success "Ollama service already running"
fi

# =============================================================================
# STEP 3: Clone Repository
# =============================================================================
print_step "STEP 3: Setting up Repository"

# Clone or update the repository first, as Onyx will be installed here
if [ -d ~/riotsecure ]; then
    print_warning "riotsecure directory already exists"
    cd ~/riotsecure
    git pull
    print_success "Repository updated"
else
    print_warning "Cloning riotsecure repository..."
    cd ~
    git clone https://github.com/cediackermann/riotsecure.git
    cd ~/riotsecure
    print_success "Repository cloned"
fi

# =============================================================================
# STEP 4: Docker Desktop
# =============================================================================
print_step "STEP 4: Installing Docker Desktop"

if [ -d "/Applications/Docker.app" ]; then
    print_success "Docker Desktop is already installed"
else
    print_warning "Installing Docker Desktop via Homebrew..."
    brew install --cask docker-desktop
    print_success "Docker Desktop installed"
fi

print_warning "Opening Docker Desktop..."
if [ -d "/Applications/Docker.app" ]; then
    open -a Docker
else
    print_error "Docker.app not found in /Applications. Please install Docker Desktop manually."
    exit 1
fi

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
# STEP 5: Onyx
# =============================================================================
print_step "STEP 5: Installing Onyx"

if [ -d ~/riotsecure/onyx_data ]; then
    print_warning "Onyx data directory already exists. Skipping installation."
else
    print_warning "Installing Onyx..."
    echo "When prompted:"
    echo "  1. Press ENTER to acknowledge"
    echo "  2. Choose '2' for Standard"
    echo "  3. Press ENTER for Edge"
    echo ""

    # Ensure we're in the riotsecure directory so onyx_data is created there
    cd ~/riotsecure

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
# STEP 6: Ollama Models
# =============================================================================
print_step "STEP 6: Setting up Ollama Models"

# Ensure we're in the riotsecure directory
cd ~/riotsecure

print_warning "Creating Ollama models from modelfiles..."
if [ -f "./updateModels.sh" ]; then
    chmod +x ./updateModels.sh
    ./updateModels.sh modelfiles
    print_success "Ollama models created successfully"
else
    print_error "updateModels.sh not found!"
fi

# =============================================================================
# STEP 7: Web Interface Configuration
# =============================================================================
print_step "STEP 7: Web Interface Configuration"

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
# STEP 8: RAG Content Upload
# =============================================================================
print_step "STEP 8: RAG Content Upload"

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
echo -e "Access the web interface at: ${BLUE}http://localhost:3000${NC}"

# Get local IP address
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "Unable to detect")
if [ "$LOCAL_IP" != "Unable to detect" ]; then
    echo -e "From other devices on the network: ${BLUE}http://${LOCAL_IP}:3000${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - View Onyx logs: cd ~/riotsecure/onyx_data && docker compose logs -f"
echo "  - Restart Onyx: cd ~/riotsecure/onyx_data && docker compose restart"
echo "  - List Ollama models: ollama list"
echo "  - Update Ollama models: cd ~/riotsecure && ./updateModels.sh modelfiles"
echo ""
