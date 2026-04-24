#!/bin/bash
# Step: Install Onyx. Source common.sh before sourcing this file.
# Requires: Docker to be running, repo cloned at ~/riotsecure.

install_onyx() {
    print_step "Installing Onyx"

    if [ -d ~/riotsecure/onyx_data ]; then
        print_warning "Onyx data directory already exists. Skipping installation."
    else
        print_warning "Installing Onyx..."
        echo "When prompted:"
        echo "  1. Press ENTER to acknowledge"
        echo "  2. Choose '2' for Standard"
        echo "  3. Press ENTER for Edge"
        echo ""

        cd ~/riotsecure
        curl -fsSL https://onyx.app/install_onyx.sh | bash

        print_success "Onyx installation complete"
    fi

    print_warning "Configuring power settings to prevent sleep..."
    sudo pmset -a sleep 0 disksleep 0
    print_success "Sleep prevention configured"
}
