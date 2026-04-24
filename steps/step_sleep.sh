#!/bin/bash
# Step: Prevent the machine from sleeping. Source common.sh before sourcing this file.

prevent_sleep() {
    print_step "Preventing Sleep"

    print_warning "Configuring power settings to prevent sleep..."
    sudo pmset -a sleep 0 disksleep 0
    print_success "Sleep prevention configured"
}
