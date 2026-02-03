#!/bin/bash
set -e

# Tart VM Setup Script for mac-devops-setup testing
# This script installs Tart and pulls a vanilla macOS image for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
VM_NAME="${VM_NAME:-macos-test}"
MACOS_VERSION="${MACOS_VERSION:-tahoe}"
IMAGE="ghcr.io/cirruslabs/macos-${MACOS_VERSION}-vanilla:latest"

echo "==> Tart VM Setup for mac-devops-setup testing"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
	echo "Error: This script requires macOS"
	exit 1
fi

# Check if running on Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
	echo "Error: Tart requires Apple Silicon (M1/M2/M3)"
	exit 1
fi

# Install Tart if not present
if ! command -v tart &>/dev/null; then
	echo "==> Installing Tart..."
	brew install cirruslabs/cli/tart
else
	echo "==> Tart already installed: $(tart --version)"
fi

# Check if VM already exists
if tart list | grep -qw "${VM_NAME}"; then
	echo "==> VM '${VM_NAME}' already exists"
	read -p "Delete and recreate? (y/n) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "==> Deleting existing VM..."
		tart delete "${VM_NAME}" || true
	else
		echo "==> Keeping existing VM"
		exit 0
	fi
fi

# Pull/clone the macOS image
echo "==> Pulling macOS ${MACOS_VERSION} image (this may take a while on first run)..."
echo "    Image: ${IMAGE}"
tart clone "${IMAGE}" "${VM_NAME}"

echo ""
echo "==> Setup complete!"
echo ""
echo "Available commands:"
echo "  tart run ${VM_NAME}                    # Start VM with GUI"
echo "  tart run ${VM_NAME} --no-graphics      # Start VM headless"
echo "  ./scripts/tart-test.sh                 # Run full test suite"
echo ""
echo "VM Details:"
tart get "${VM_NAME}"
