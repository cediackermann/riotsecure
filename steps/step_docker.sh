#!/bin/bash
# Step: Install and start Docker Desktop. Source common.sh before sourcing this file.

install_docker() {
    print_step "Installing Docker Desktop"

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
    local TOTAL_MEM_GB
    TOTAL_MEM_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    local MEM_RECOMMENDATION
    if [ "$TOTAL_MEM_GB" -ge 20 ]; then
        MEM_RECOMMENDATION="20 GB"
    else
        MEM_RECOMMENDATION="MAX"
    fi

    echo "3. Go to Docker → Settings → Resources and set:"
    echo "   - CPU limit: MAX"
    echo "   - Memory limit: ${MEM_RECOMMENDATION}"
    echo "   - Disk usage limit: MAX"
    echo "4. Click 'Apply & Restart'"
    echo ""
    wait_for_user

    print_warning "Waiting for Docker to be ready..."
    while ! docker info &> /dev/null; do
        echo "Waiting for Docker daemon..."
        sleep 5
    done
    print_success "Docker is ready"
}
