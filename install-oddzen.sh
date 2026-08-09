#!/bin/bash
# oddzen install script
# Adds the oddzen apt repo and installs the kernel.
# Modeled after the liquorix install script, with a live progress bar.
set -euo pipefail

# Non-interactive guard for `curl ... | sudo bash`
export DEBIAN_FRONTEND="noninteractive"
# Suspend needrestart so it does not restart services mid-install
export NEEDRESTART_SUSPEND="*"

# Structured logging
log() {
    local level=$1; shift
    case "$level" in
        INFO)  printf '\033[32m[INFO]\033[0m  %s\n' "$*" ;;
        WARN)  printf '\033[33m[WARN]\033[0m  %s\n' "$*" ;;
        ERROR) printf '\033[31m[ERROR]\033[0m %s\n' "$*" ;;
    esac
}

# Live progress bar: 40-cell bar, step/total, message
progress() {
    local step=$1 total=$2 msg=$3
    local pct=$((step * 100 / total))
    local filled=$((pct * 40 / 100))
    local bar
    bar="$(printf '%*s' "$filled" '' | tr ' ' '█')$(printf '%*s' $((40 - filled)) '' | tr ' ' '░')"
    printf '  %s  %2d/%-2d  %s\n' "$bar" "$step" "$total" "$msg"
}

REPO_URL="https://cpntodd.github.io/oddzen"
KEYRING_PATH="/etc/apt/keyrings/oddzen-archive-keyring.gpg"
APT_LIST="/etc/apt/sources.list.d/oddzen.list"
TOTAL_STEPS=7

# Must be root
if [[ $EUID -ne 0 ]]; then
    log ERROR "This script must be run as root. Use: curl -s 'https://...' | sudo bash"
    exit 1
fi

# Must be amd64
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
if [[ "$ARCH" != "amd64" ]]; then
    log ERROR "oddzen only supports amd64 (x86_64). Detected: $ARCH"
    exit 1
fi

# Must be Debian
if ! grep -qi 'debian' /etc/os-release 2>/dev/null && ! command -v apt-get &>/dev/null; then
    log ERROR "This system does not appear to be Debian-based. oddzen currently only supports Debian."
    exit 1
fi

echo ""
echo "  ⚡ oddzen — Oddsoul's custom Zen kernel for Debian ⚡"
echo "     AMD Zen/Polaris tuned | Clang-built | PREEMPT_DYNAMIC"
echo ""

# Step 1/7 - detect the Debian codename (trixie, bookworm, ...)
progress 1 "$TOTAL_STEPS" "Detecting Debian release..."
DEBIAN_CODENAME=$(apt-cache policy 2>/dev/null | grep -oP 'o=Debian.*?n=\K\w+' | sort -u | head -1 || true)
if [ -z "$DEBIAN_CODENAME" ]; then
    DEBIAN_CODENAME="stable"
    log WARN "Could not detect Debian codename, falling back to 'stable'"
else
    log INFO "Detected Debian ${DEBIAN_CODENAME}"
fi

# Step 2/7 - install prerequisites
progress 2 "$TOTAL_STEPS" "Installing prerequisites..."
apt-get update
apt-get install -y --no-install-recommends curl gpg ca-certificates

# Step 3/7 - set up GPG keyring
progress 3 "$TOTAL_STEPS" "Setting up GPG keyring..."
mkdir -p /etc/apt/keyrings
chmod 0755 /etc/apt/keyrings
curl -fsSL "${REPO_URL}/oddzen-archive-keyring.gpg" | \
    gpg --batch --yes --output "$KEYRING_PATH" --dearmor
chmod 0644 "$KEYRING_PATH"
log INFO "GPG key installed to ${KEYRING_PATH}"

# Step 4/7 - add apt source
progress 4 "$TOTAL_STEPS" "Adding apt repository..."
cat > "$APT_LIST" << EOF
deb [arch=amd64 signed-by=${KEYRING_PATH}] ${REPO_URL}/repo ${DEBIAN_CODENAME} main
EOF
log INFO "Repository added to ${APT_LIST}"

# Step 5/7 - update package lists
progress 5 "$TOTAL_STEPS" "Updating package lists..."
apt-get update

# Step 6/7 - install the kernel
progress 6 "$TOTAL_STEPS" "Installing oddzen kernel..."
apt-get install -y 'linux-image-*-oddzen' 'linux-headers-*-oddzen'
log INFO "Kernel packages installed"

# Step 7/7 - update GRUB
progress 7 "$TOTAL_STEPS" "Updating GRUB..."
GRUB_CFG='/boot/grub/grub.cfg'
if [ -f "$GRUB_CFG" ]; then
    grub-mkconfig -o "$GRUB_CFG"
else
    log WARN "GRUB config not found at ${GRUB_CFG}, skipping"
fi

echo ""
echo "  ═══════════════════════════════════════════════════════════"
echo "    oddzen 7.1.5-zen1-oddzen installed successfully."
echo "  ═══════════════════════════════════════════════════════════"
echo ""
echo "  Reboot to use the new kernel:"
echo "    sudo reboot"
echo ""
echo "  After reboot, verify with:"
echo "    uname -r"
echo ""
