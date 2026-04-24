#!/bin/bash
# Step: Install and start Ollama. Source common.sh before sourcing this file.

# Launchd plist that starts Ollama on all interfaces at login.
OLLAMA_PLIST="$HOME/Library/LaunchAgents/com.ollama.serve.plist"

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

    # Register Ollama as a launchd agent so it:
    #   - starts automatically at login
    #   - listens on all interfaces (0.0.0.0) so other devices can reach it
    print_warning "Configuring Ollama to listen on all network interfaces..."
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$OLLAMA_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.serve</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11434</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ollama.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.log</string>
</dict>
</plist>
EOF

    # Stop any existing instance first so the new config takes effect
    if pgrep -x "ollama" > /dev/null; then
        print_warning "Restarting Ollama with network binding..."
        launchctl unload "$OLLAMA_PLIST" 2>/dev/null || true
        pkill -x ollama 2>/dev/null || true
        sleep 1
    fi

    launchctl load "$OLLAMA_PLIST"
    sleep 3

    if pgrep -x "ollama" > /dev/null; then
        print_success "Ollama service started (listening on 0.0.0.0:11434)"
    else
        print_warning "Ollama service may not have started properly"
        echo "  Check logs at: /tmp/ollama.log"
    fi
}
