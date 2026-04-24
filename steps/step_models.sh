#!/bin/bash
# Step: Create Ollama models from modelfiles. Source common.sh before sourcing this file.
# Requires: repo cloned at ~/riotsecure, Ollama service running.

setup_models() {
    print_step "Setting up Ollama Models"

    cd ~/riotsecure
    print_warning "Creating Ollama models from modelfiles..."
    if [ -f "./updateModels.sh" ]; then
        chmod +x ./updateModels.sh
        ./updateModels.sh modelfiles
        print_success "Ollama models created successfully"
    else
        print_error "updateModels.sh not found!"
        exit 1
    fi
}
