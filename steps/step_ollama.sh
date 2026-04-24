#!/bin/bash
# Step: Install and start Ollama. Source common.sh before sourcing this file.

install_ollama() {
    print_step "Installing Ollama"

    if command -v ollama &> /dev/null; then
        print_success "Ollama is already installed"
        ollama --version
    else
        print_warning "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        print_success "Ollama installed successfully"
    fi

    print_warning "Starting Ollama service..."
    if ! pgrep -x "ollama" > /dev/null; then
        nohup ollama serve > /tmp/ollama.log 2>&1 &
        sleep 3

        if pgrep -x "ollama" > /dev/null; then
            print_success "Ollama service started"
        else
            print_warning "Ollama service may not have started properly"
            echo "  Check logs at: /tmp/ollama.log"
        fi
    else
        print_success "Ollama service already running"
    fi
}
