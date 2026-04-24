#!/bin/bash
# Shared helpers sourced by all setup scripts

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_section() { echo -e "\n${BLUE}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }

wait_for_user() {
    echo -e "\n${YELLOW}Press ENTER when you have completed the above step...${NC}"
    read
}

ask_confirmation() {
    echo -e "${YELLOW}$1 [y/N]${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_mac() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS. Exiting."
        exit 1
    fi
}
