#!/bin/bash
# Step: RAG content upload. Source common.sh before sourcing this file.
# Requires: repo cloned at ~/riotsecure.

rag_upload() {
    print_step "RAG Content Upload"

    echo "Choose content upload method:"
    echo "  A - Upload as File (recommended)"
    echo "  B - Upload as URL"
    echo "  S - Skip this step"
    echo ""
    read -p "Enter your choice (A/B/S): " choice

    case $choice in
        [Aa])
            print_warning "Fetching content from riot-sources.txt..."
            cd ~/riotsecure
            if [ -f "./fetchContent.sh" ]; then
                chmod +x ./fetchContent.sh
                if [ -f "./riot-sources.txt" ]; then
                    ./fetchContent.sh riot-sources.txt
                    print_success "Content fetched successfully"

                    echo ""
                    echo "MANUAL STEP REQUIRED:"
                    echo "1. In the web interface, go to Admin Panel → Add Connector → File"
                    echo "2. Give the connector a name"
                    echo "3. Upload the files from ~/riotsecure/content"
                    echo "4. Wait ~30 seconds for indexing to complete"
                    echo ""
                else
                    print_error "riot-sources.txt not found!"
                fi
            else
                print_error "fetchContent.sh not found!"
            fi
            wait_for_user
            ;;
        [Bb])
            echo ""
            echo "MANUAL STEP REQUIRED:"
            echo "1. In the web interface, go to Admin Panel → Add Connector → Web"
            echo "2. Add each URL from riot-sources.txt as a separate connector"
            echo "3. Use scrape method 'Single'"
            echo "4. Wait ~30 seconds for indexing to complete"
            echo ""
            wait_for_user
            ;;
        [Ss])
            print_warning "Skipping RAG content upload"
            ;;
        *)
            print_warning "Invalid choice. Skipping RAG content upload"
            ;;
    esac
}
