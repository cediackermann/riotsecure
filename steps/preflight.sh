#!/bin/bash
# Pre-flight checks. Source common.sh before sourcing this file.
# Usage: preflight_checks [--skip-docker] [--skip-ollama]

preflight_checks() {
    local SKIP_DOCKER=0
    local SKIP_OLLAMA=0
    for arg in "$@"; do
        [[ "$arg" == "--skip-docker" ]] && SKIP_DOCKER=1
        [[ "$arg" == "--skip-ollama" ]] && SKIP_OLLAMA=1
    done

    print_step "Pre-flight System Checks"
    local PREFLIGHT_FAILED=0

    MACOS_VERSION=$(sw_vers -productVersion)
    MACOS_MAJOR=$(echo $MACOS_VERSION | cut -d. -f1)
    echo -e "macOS Version: ${BLUE}$MACOS_VERSION${NC}"
    if [ "$MACOS_MAJOR" -lt 12 ]; then
        print_error "macOS 12 (Monterey) or later recommended. You have: $MACOS_VERSION"
        PREFLIGHT_FAILED=1
    else
        print_success "macOS version compatible"
    fi

    AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
    echo -e "Available disk space: ${BLUE}${AVAILABLE_GB}GB${NC}"
    if [ "$AVAILABLE_GB" -lt 30 ]; then
        print_error "Insufficient disk space. Required: 30GB+, Available: ${AVAILABLE_GB}GB"
        PREFLIGHT_FAILED=1
    elif [ "$AVAILABLE_GB" -lt 50 ]; then
        print_warning "Low disk space. Recommended: 50GB+, Available: ${AVAILABLE_GB}GB"
    else
        print_success "Sufficient disk space available"
    fi

    TOTAL_MEM_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    echo -e "Total system memory: ${BLUE}${TOTAL_MEM_GB}GB${NC}"
    if [ "$TOTAL_MEM_GB" -lt 16 ]; then
        print_warning "Low memory. Recommended: 16GB+, Available: ${TOTAL_MEM_GB}GB"
    else
        print_success "Sufficient memory available"
    fi

    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connection detected"
        PREFLIGHT_FAILED=1
    fi

    if [ $SKIP_DOCKER -eq 0 ]; then
        if pgrep -x "Docker" > /dev/null 2>&1; then
            print_warning "Docker Desktop is already running"
        fi
        if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port 3000 is already in use (required for Onyx web interface)"
        fi
    fi

    if [ $PREFLIGHT_FAILED -eq 1 ]; then
        print_error "Pre-flight checks failed. Please resolve the issues above."
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
