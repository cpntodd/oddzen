#!/bin/bash
# oddzen build script
# Builds Linux .deb packages with Zen patches using Clang 21
set -e

KERNEL_VERSION="7.1.5"
ZEN_TAG="v${KERNEL_VERSION}-zen1"
LOCALVERSION="-oddzen"
FULL_VERSION="${KERNEL_VERSION}-zen1${LOCALVERSION}"
JOBS=$(nproc)

echo "=== oddzen build script ==="
echo "Version: ${FULL_VERSION}"
echo "Jobs: ${JOBS}"
echo

# Check for Clang
if ! command -v clang-21 &>/dev/null; then
    echo "ERROR: clang-21 not found. Install: sudo apt install clang-21 lld-21 llvm-21"
    exit 1
fi

export PATH="/usr/lib/llvm-21/bin:$PATH"

# Clone Zen kernel if not present
if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    echo "Cloning Zen kernel ${ZEN_TAG}..."
    git clone --depth 1 --branch "${ZEN_TAG}" https://github.com/zen-kernel/zen-kernel.git "linux-${KERNEL_VERSION}"
fi

cd "linux-${KERNEL_VERSION}"

# Copy config
if [ -f "../config-${FULL_VERSION}" ]; then
    cp "../config-${FULL_VERSION}" .config
    echo "Using saved config: config-${FULL_VERSION}"
else
    echo "ERROR: No config found at ../config-${FULL_VERSION}"
    exit 1
fi

# Update config for new kernel
make LLVM=1 olddefconfig

# Build .deb packages
echo "Building .deb packages for ${FULL_VERSION}..."
make LLVM=1 bindeb-pkg -j${JOBS}

echo ""
echo "=== .deb packages built in parent directory ==="
ls -lh ../linux-*.deb 2>/dev/null
echo ""
echo "To update the apt repo:"
echo "  1. Copy .debs to repo/pool/main/"
echo "  2. Run: dpkg-scanpackages --arch amd64 repo/pool/ > repo/dists/stable/main/binary-amd64/Packages"
echo "  3. Run: gzip -9c repo/dists/stable/main/binary-amd64/Packages > repo/dists/stable/main/binary-amd64/Packages.gz"
echo "  4. Run: apt-ftparchive -c repo/apt-ftparchive.conf release repo/dists/stable > repo/dists/stable/Release"
echo "  5. Sign: gpg --default-key <key> --clearsign --output repo/dists/stable/InRelease repo/dists/stable/Release"
echo "  6. Commit and push"

