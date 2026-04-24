#!/bin/bash
# Step: Clone or update the riotsecure repository. Source common.sh before sourcing this file.

setup_repo() {
    print_step "Setting up Repository"

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
}
