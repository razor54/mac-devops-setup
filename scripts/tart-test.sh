#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

VM_NAME="${VM_NAME:-macos-test}"
VM_USER="${VM_USER:-admin}"
VM_PASS="${VM_PASS:-admin}"
VM_IP=""
SHOW_GUI=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
	if [[ "$SHOW_GUI" == true ]]; then
		return
	fi
	log_info "Cleaning up..."
	if [[ -n "$VM_PID" ]]; then
		kill "$VM_PID" 2>/dev/null || true
		wait "$VM_PID" 2>/dev/null || true
	fi
}
trap cleanup EXIT

wait_for_vm_ip() {
	local max_attempts=60
	local attempt=1

	log_info "Waiting for VM to get IP address..."
	while [[ $attempt -le $max_attempts ]]; do
		VM_IP=$(tart ip "${VM_NAME}" 2>/dev/null || true)
		if [[ -n "$VM_IP" ]]; then
			log_info "VM IP: ${VM_IP}"
			return 0
		fi
		echo -n "."
		sleep 2
		((attempt++))
	done
	echo ""
	log_error "Timed out waiting for VM IP after $((max_attempts * 2)) seconds"
	return 1
}

wait_for_ssh() {
	local max_attempts=30
	local attempt=1

	log_info "Waiting for SSH to become available..."
	while [[ $attempt -le $max_attempts ]]; do
		if SSHPASS="${VM_PASS}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
			-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
			-o PreferredAuthentications=password -o PubkeyAuthentication=no \
			"${VM_USER}@${VM_IP}" "echo 'ready'" &>/dev/null; then
			log_info "SSH connection established"
			return 0
		fi
		echo -n "."
		sleep 3
		((attempt++))
	done
	echo ""
	log_error "Timed out waiting for SSH after $((max_attempts * 3)) seconds"
	return 1
}

expand_disk() {
	log_info "Checking disk space..."
	# The Cirrus Labs images have a recovery partition that blocks expansion
	# without booting into Recovery OS. We compensate by using a larger initial disk size.

	ssh_cmd "diskutil list disk0"
	ssh_cmd "df -h /"

	# Note: Automated disk expansion is blocked by recovery partition on Cirrus Labs images.
	# The workaround is using DISK_SIZE=150+ when creating the VM.
	# Manual expansion requires: tart run <vm> --recovery, then diskutil commands
	log_info "Note: ~44GB usable from APFS container (recovery partition blocks auto-expansion)"
}

ssh_cmd() {
	SSHPASS="${VM_PASS}" sshpass -e ssh -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		-o PreferredAuthentications=password -o PubkeyAuthentication=no \
		-o ConnectTimeout=10 \
		"${VM_USER}@${VM_IP}" "$@"
}

scp_to_vm() {
	SSHPASS="${VM_PASS}" sshpass -e scp -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		-o PreferredAuthentications=password -o PubkeyAuthentication=no \
		-o ConnectTimeout=10 \
		-r "$1" "${VM_USER}@${VM_IP}:$2"
}

ensure_sshpass() {
	if ! command -v sshpass &>/dev/null; then
		log_warn "sshpass not installed. Installing..."
		brew install hudochenkov/sshpass/sshpass || brew install esolitos/ipa/sshpass
	fi
}

check_vm_exists() {
	if ! tart list | grep -qw "${VM_NAME}"; then
		log_error "VM '${VM_NAME}' not found. Run: ./scripts/tart-setup.sh"
		exit 1
	fi
}

run_test() {
	log_info "==> Starting mac-devops-setup test run"
	echo ""

	command -v tart &>/dev/null || {
		log_error "Tart not installed. Run: ./scripts/tart-setup.sh"
		exit 1
	}
	ensure_sshpass
	check_vm_exists

	if [[ "$SHOW_GUI" == true ]]; then
		log_info "Starting VM '${VM_NAME}' with GUI (watch progress in VM window)..."
		tart run "${VM_NAME}" &
	else
		log_info "Starting VM '${VM_NAME}' in headless mode..."
		tart run "${VM_NAME}" --no-graphics &
	fi
	VM_PID=$!

	wait_for_vm_ip
	wait_for_ssh
	expand_disk

	log_info "Copying project files to VM..."
	ssh_cmd "rm -rf ~/mac-devops-setup && mkdir -p ~/mac-devops-setup"
	scp_to_vm "${PROJECT_DIR}/." "~/mac-devops-setup/"

	log_info "Running Install.sh in VM (CI mode)..."
	# Pass environment variables to the VM if set
	local ENV_VARS=""
	[[ -n "$GITHUB_ACCESS_TOKEN" ]] && ENV_VARS+="GITHUB_ACCESS_TOKEN='${GITHUB_ACCESS_TOKEN}' "
	[[ -n "$INSTALL_CASK_APPS" ]] && ENV_VARS+="INSTALL_CASK_APPS='${INSTALL_CASK_APPS}' "
	ENV_VARS+="ANSIBLE_BECOME_PASSWORD='${VM_PASS}'"

	ssh_cmd "cd ~/mac-devops-setup && chmod +x Install.sh && ${ENV_VARS} ./Install.sh --ci"

	log_info "==> Test completed successfully!"

	if [[ "$SHOW_GUI" == true ]]; then
		log_info "VM GUI still open for manual testing."
		log_info "Close the VM window or run './scripts/tart-test.sh stop' when done."
		wait "$VM_PID" 2>/dev/null || true
	fi
}

do_ssh() {
	VM_IP=$(tart ip "${VM_NAME}" 2>/dev/null || true)
	if [[ -z "$VM_IP" ]]; then
		log_error "VM not running. Start it first: ./scripts/tart-test.sh start"
		exit 1
	fi
	ensure_sshpass
	log_info "Connecting to ${VM_USER}@${VM_IP}..."
	SSHPASS="${VM_PASS}" sshpass -e ssh -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		-o PreferredAuthentications=password -o PubkeyAuthentication=no \
		"${VM_USER}@${VM_IP}"
}

do_logs() {
	VM_IP=$(tart ip "${VM_NAME}" 2>/dev/null || true)
	if [[ -z "$VM_IP" ]]; then
		log_error "VM not running. Start it first: ./scripts/tart-test.sh start"
		exit 1
	fi
	ensure_sshpass
	log_info "Tailing install log from ${VM_USER}@${VM_IP}..."
	log_info "(Ctrl+C to stop watching)"
	ssh_cmd "tail -f ~/mac-devops-setup/install.log 2>/dev/null || echo 'Log file not found yet. Install may not have started.'"
}

show_help() {
	cat <<EOF
Tart VM Test Runner for mac-devops-setup

Usage: $(basename "$0") [command] [options]

Commands:
    run         Run the full test suite (default)
    ssh         Open SSH session to running VM
    logs        Tail the install log from running VM
    start       Start VM in GUI mode (for debugging)
    stop        Stop the VM
    reset       Delete and recreate VM from fresh image
    help        Show this help message

Options:
    --gui       Run VM with GUI to watch progress (keeps open after test)

Environment Variables:
    VM_NAME                 VM name (default: macos-test)
    VM_USER                 VM username (default: admin)
    VM_PASS                 VM password (default: admin)
    GITHUB_ACCESS_TOKEN     GitHub PAT for full test (optional)

Examples:
    ./scripts/tart-test.sh run
    ./scripts/tart-test.sh run --gui
    GITHUB_ACCESS_TOKEN=ghp_xxx ./scripts/tart-test.sh run --gui
    ./scripts/tart-test.sh ssh
    ./scripts/tart-test.sh start
EOF
}

case "${1:-run}" in
run)
	shift || true
	for arg in "$@"; do
		case "$arg" in
		--gui) SHOW_GUI=true ;;
		esac
	done
	run_test
	;;
ssh)
	do_ssh
	;;
logs)
	do_logs
	;;
start)
	check_vm_exists
	log_info "Starting VM with GUI..."
	tart run "${VM_NAME}"
	;;
stop)
	log_info "Stopping VM..."
	pkill -f "tart run ${VM_NAME}" || log_warn "VM not running"
	;;
reset)
	log_info "Resetting VM..."
	pkill -f "tart run ${VM_NAME}" 2>/dev/null || true
	tart delete "${VM_NAME}" 2>/dev/null || true
	"${SCRIPT_DIR}/tart-setup.sh"
	;;
help | --help | -h)
	show_help
	;;
*)
	log_error "Unknown command: $1"
	show_help
	exit 1
	;;
esac
