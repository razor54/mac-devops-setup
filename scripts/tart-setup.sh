#!/bin/bash
set -e

# Tart VM Setup Script for mac-devops-setup testing
# This script installs Tart and creates a macOS VM for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
VM_NAME="${VM_NAME:-macos-test}"
DISK_SIZE="${DISK_SIZE:-100}"
# Use IPSW for fresh install (full disk available) or IMAGE for pre-built (faster, pre-configured)
# Pre-built is default: admin/admin user, SSH enabled, ready to use (but ~44GB usable due to recovery partition)
# Set USE_IPSW=true for full disk, but requires manual Setup Assistant completion
USE_IPSW="${USE_IPSW:-false}"
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

if [[ "$USE_IPSW" == "true" ]]; then
	# Create from IPSW - slower but gives full disk space
	echo "==> Creating macOS VM from IPSW (this takes a while on first run)..."
	echo "    Disk size: ${DISK_SIZE}GB"
	echo ""
	echo "NOTE: After VM boots, you must complete macOS Setup Assistant manually:"
	echo "  1. Select language and region"
	echo "  2. Skip Accessibility, Migration Assistant, Apple ID"
	echo "  3. Create user: admin / admin"
	echo "  4. Skip Screen Time, Siri, Analytics"
	echo "  5. Enable Remote Login: System Settings > General > Sharing > Remote Login"
	echo ""
	tart create "${VM_NAME}" --from-ipsw=latest --disk-size="${DISK_SIZE}"

	echo "==> Starting VM for initial setup..."
	echo "    Complete the Setup Assistant, then close the VM window."
	tart run "${VM_NAME}"
else
	# Clone pre-built image - faster but only ~44GB usable due to recovery partition
	echo "==> Cloning pre-built macOS ${MACOS_VERSION} image..."
	echo "    Image: ${IMAGE}"
	echo "    Note: Pre-built images have ~44GB usable (recovery partition blocks expansion)"
	tart clone "${IMAGE}" "${VM_NAME}"

	# Resize disk (won't help much due to recovery partition, but set it anyway)
	echo "==> Setting disk size to ${DISK_SIZE}GB..."
	tart set "${VM_NAME}" --disk-size "${DISK_SIZE}"
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "Available commands:"
echo "  tart run ${VM_NAME}                    # Start VM with GUI"
echo "  tart run ${VM_NAME} --no-graphics      # Start VM headless"
echo "  ./scripts/tart-test.sh                 # Run full test suite"
echo ""

if [[ "$USE_IPSW" == "true" ]]; then
	echo "NEXT STEPS (one-time setup):"
	echo "  1. Complete Setup Assistant (create user: admin / admin)"
	echo "  2. Enable Remote Login: System Settings > General > Sharing > Remote Login"
	echo "  3. Shut down the VM"
	echo "  4. Save as reusable image: tart clone ${VM_NAME} macos-base"
	echo "  5. Future runs: VM_NAME=macos-base ./scripts/tart-test.sh run"
	echo ""
fi

echo "VM Details:"
tart get "${VM_NAME}"
