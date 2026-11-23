#!/usr/bin/env bash

# MacBook CS8409 Audio Driver Setup
# Target: Arch Linux
# Hardware: MacBookPro14,1 / Cirrus Logic CS8409
#
# Installs audio dependencies, firmware and the CS8409 driver using DKMS.

set -Eeuo pipefail

# -----------------------------
# Configuration
# -----------------------------

DRIVER_REPO="https://github.com/davidjo/snd_hda_macbookpro.git"
FIRMWARE_BASE="https://github.com/leifliddy/macbook12-audio-driver/raw/master/firmware"

FIRMWARE_DIR="/usr/lib/firmware/cirrus"
DRIVER_NAME="snd_hda_macbookpro"
DRIVER_VERSION="0.1"

FIRMWARE_FILES=(
    "cs8409-apple-141.bin"
    "cs8409-apple-142.bin"
    "cs8409-apple-143.bin"
)

DEPENDENCIES=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    pavucontrol
    alsa-utils
    alsa-tools
    git
    base-devel
    dkms
    curl
    wget
    patch
)

# -----------------------------
# Logging
# -----------------------------

info() {
    echo -e "\n[INFO] $*"
}

success() {
    echo -e "\n[OK] $*"
}

warn() {
    echo -e "\n[WARN] $*" >&2
}

error() {
    echo -e "\n[ERROR] $*" >&2
    exit 1
}

trap 'error "Failed at line $LINENO. Check the output above."' ERR

# -----------------------------
# Root check
# -----------------------------

if [[ $EUID -ne 0 ]]; then
    info "Requesting administrator privileges..."
    exec sudo -E bash "$0" "$@"
fi

# -----------------------------
# System check
# -----------------------------

[[ -f /etc/arch-release ]] || error "This script is intended for Arch Linux."

command -v pacman >/dev/null || error "pacman not found."
command -v mktemp >/dev/null || error "mktemp not found."

KERNEL="$(uname -r)"

info "Detected kernel: $KERNEL"

# -----------------------------
# Kernel header detection
# -----------------------------

HEADER_PACKAGE=""

if [[ -e "/usr/lib/modules/$KERNEL/build/Makefile" ]]; then
    success "Matching kernel headers already available."
else
    info "Matching kernel headers not found."

    # Find the package owning the running kernel.
    for pkg in linux linux-lts linux-zen linux-hardened; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            HEADER_PACKAGE="${pkg}-headers"
            break
        fi
    done

    if [[ -z "$HEADER_PACKAGE" ]]; then
        error "Could not identify your kernel package.
Install the appropriate headers for kernel: $KERNEL
For custom kernels, install their matching headers manually."
    fi

    info "Required headers: $HEADER_PACKAGE"
fi

# -----------------------------
# Dependency installation
# -----------------------------

PACKAGES=("${DEPENDENCIES[@]}")

if [[ -n "$HEADER_PACKAGE" ]]; then
    PACKAGES+=("$HEADER_PACKAGE")
fi

MISSING=()

for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        MISSING+=("$pkg")
    fi
done

if ((${#MISSING[@]})); then
    info "Installing missing packages:"
    printf '  - %s\n' "${MISSING[@]}"

    pacman -S --needed --noconfirm "${MISSING[@]}"
else
    success "All required packages are already installed."
fi

# Verify headers after installation.
if [[ ! -e "/usr/lib/modules/$KERNEL/build/Makefile" ]]; then
    error "Headers for the running kernel are still unavailable.

Your installed kernel and repository kernel may be different.
Reboot into the installed kernel, then run this script again."
fi

# -----------------------------
# Firmware installation
# -----------------------------

info "Checking Cirrus firmware..."

install -d -m 755 "$FIRMWARE_DIR"

for firmware in "${FIRMWARE_FILES[@]}"; do
    destination="$FIRMWARE_DIR/$firmware"

    if [[ -s "$destination" ]]; then
        success "$firmware already exists. Skipping."
        continue
    fi

    info "Downloading $firmware..."

    temporary_file="$(mktemp)"

    if curl --fail --location --silent --show-error \
        "$FIRMWARE_BASE/$firmware" \
        -o "$temporary_file"; then

        if [[ ! -s "$temporary_file" ]]; then
            rm -f "$temporary_file"
            error "Downloaded firmware is empty: $firmware"
        fi

        install -m 644 "$temporary_file" "$destination"
        rm -f "$temporary_file"

        success "$firmware installed."
    else
        rm -f "$temporary_file"
        error "Failed to download $firmware"
    fi
done

# -----------------------------
# Temporary workspace
# -----------------------------

WORK_DIR="$(mktemp -d /tmp/macbook-audio.XXXXXX)"

cleanup() {
    if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}

trap cleanup EXIT

# -----------------------------
# Existing DKMS cleanup
# -----------------------------

info "Checking existing DKMS driver..."

if dkms status -m "$DRIVER_NAME" -v "$DRIVER_VERSION" 2>/dev/null \
    | grep -q .; then

    info "Existing DKMS version found. Removing old registration..."

    dkms remove \
        -m "$DRIVER_NAME" \
        -v "$DRIVER_VERSION" \
        --all
else
    success "No previous DKMS registration found."
fi

# -----------------------------
# Clone driver
# -----------------------------

info "Downloading a fresh driver source..."

git clone --depth 1 "$DRIVER_REPO" "$WORK_DIR/$DRIVER_NAME"

cd "$WORK_DIR/$DRIVER_NAME"

[[ -f install.cirrus.driver.sh ]] \
    || error "Driver installer not found in repository."

# -----------------------------
# Install driver using DKMS
# -----------------------------

info "Installing Cirrus CS8409 driver through DKMS..."

bash ./install.cirrus.driver.sh -i

success "Driver installation completed."

# -----------------------------
# Final checks
# -----------------------------

info "Checking DKMS status..."

dkms status

info "Checking firmware files..."

ls -lh "$FIRMWARE_DIR"/cs8409-apple-*

# -----------------------------
# Finished
# -----------------------------

success "MacBook audio setup completed!"

echo
echo "Next steps:"
echo "1. Reboot your MacBook."
echo "2. Open pavucontrol."
echo "3. Check your audio output devices."
echo
echo "After reboot, verify with:"
echo "  lspci -nnk | grep -A3 -i audio"
echo "  dkms status"
echo "  pactl info"
