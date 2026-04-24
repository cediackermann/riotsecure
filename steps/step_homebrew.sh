#!/bin/bash
# Step: Install Homebrew. Source common.sh before sourcing this file.

install_homebrew() {
    print_step "Installing Homebrew"

    if command -v brew &> /dev/null; then
        print_success "Homebrew is already installed"
        brew --version
    else
        print_warning "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        echo >> ~/.zprofile
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"

        print_success "Homebrew installed successfully"
    fi
}
