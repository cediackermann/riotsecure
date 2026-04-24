#!/bin/bash
# Step: Web interface configuration instructions. Source common.sh before sourcing this file.
# OLLAMA_HOST: hostname/IP of the machine running Ollama (default: host.docker.internal)

web_config() {
    local OLLAMA_HOST="${1:-host.docker.internal}"

    print_step "Web Interface Configuration"

    echo ""
    echo "MANUAL STEPS REQUIRED:"
    echo ""
    echo "1. Open your browser to http://localhost:3000"
    echo "2. Create an admin account"
    echo "3. Go to Admin Panel → Language Models:"
    echo "   - Select 'Ollama' as provider and give it a name"
    echo "   - Set API base URL to: http://${OLLAMA_HOST}:11434"
    echo "   - Refresh the model list"
    echo "   - Select at least the three RIoT models"
    echo "   - Click 'Connect'"
    echo "4. Go to Admin Panel → Chat Preferences → System Prompt → Modify Prompt"
    echo "   - Delete the entire prompt"
    echo "   - Save"
    echo ""
    wait_for_user
}
