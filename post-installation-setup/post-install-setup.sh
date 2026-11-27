#!/usr/bin/env bash
# Arch Linux + Hyprland Lua essentials setup
# Config path is currently hard-coded for k0haii.
set -Eeuo pipefail

# ---------- Visual helpers ----------
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''; fi

banner() { printf '\n%s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$CYAN" "$BOLD" "$RESET"; printf '%s%s║ %-60s ║%s\n' "$CYAN" "$BOLD" "$1" "$RESET"; printf '%s%s╚══════════════════════════════════════════════════════════════╝%s\n' "$CYAN" "$BOLD" "$RESET"; }
step() { printf '\n%s%s▶ %s%s\n' "$BLUE" "$BOLD" "$1" "$RESET"; }
ok() { printf '%s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '%s⚠%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail() { printf '%s✖%s %s\n' "$RED" "$RESET" "$1" >&2; }

trap 'fail "Setup stopped at line $LINENO. Review the message above; your backup should remain available."' ERR

banner 'ARCH LINUX · HYPRLAND LUA ESSENTIALS'
printf '%sThis setup installs essentials, selected apps, and updates a managed Lua block.%s\n' "$CYAN" "$RESET"
printf 'Bluetooth will not be enabled at boot; mbpfan temperature thresholds are not changed.\n'

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then fail 'Run this script as your normal user, not root.'; exit 1; fi
if ! command -v pacman >/dev/null 2>&1; then fail 'pacman was not found. This script is intended for Arch Linux.'; exit 1; fi

CONFIG_FILE="$HOME/.config/hypr/hyprland.lua"
if [[ ! -f "$CONFIG_FILE" ]]; then fail "Config file not found: $CONFIG_FILE"; exit 1; fi

# Backup BEFORE installing packages or modifying configuration.
step '01/09 · Backing up your Lua configuration'
BACKUP="${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
cp -a -- "$CONFIG_FILE" "$BACKUP"
ok "Backup created: $BACKUP"

step '02/09 · Installing official repository packages'
PACMAN_PACKAGES=(
  hyprpolkitagent qt5-wayland qt6-wayland
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
  bluez bluez-utils pipewire pipewire-alsa pipewire-pulse wireplumber
  brightnessctl lm_sensors acpi
  grim slurp libnotify mako playerctl xdg-desktop-portal
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk tlp
  thunar gvfs tumbler file-roller thunar-archive-plugin
  base-devel git
  hyprpaper
)
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
ok 'Official packages installed (or already present).'

step '03/09 · Setting up user audio services'
systemctl --user enable --now pipewire pipewire-pulse wireplumber
ok 'PipeWire, PipeWire PulseAudio compatibility, and WirePlumber enabled for your user.'

step '04/09 · Enabling laptop power management'
sudo systemctl enable --now tlp.service
ok 'TLP enabled.'

step '05/09 · Checking and installing yay (AUR helper)'
if ! command -v yay >/dev/null 2>&1; then
  warn 'yay is not installed. Building yay from its AUR source in a temporary directory.'
  YAY_TMP=$(mktemp -d /tmp/yay-build.XXXXXX)
  cleanup_yay_tmp() { [[ -n "${YAY_TMP:-}" && -d "$YAY_TMP" ]] && rm -rf -- "$YAY_TMP"; }
  trap cleanup_yay_tmp EXIT
  git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
  (cd "$YAY_TMP/yay" && makepkg -si --noconfirm)
  cleanup_yay_tmp
  unset YAY_TMP
  trap 'fail "Setup stopped at line $LINENO. Review the message above; your backup should remain available."' ERR
  trap - EXIT
else
  ok 'yay is already installed; skipping its bootstrap.'
fi

if command -v yay >/dev/null 2>&1; then
  step '06/09 · Installing AUR applications only if missing'
  AUR_PACKAGES=()
  for pkg in mbpfan google-chrome zen-browser-bin visual-studio-code-bin; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      ok "$pkg is already installed; skipping."
    else
      AUR_PACKAGES+=("$pkg")
    fi
  done
  if ((${#AUR_PACKAGES[@]})); then
    printf '%sMissing AUR packages to install:%s\n' "$CYAN" "$RESET"
    printf '  • %s\n' "${AUR_PACKAGES[@]}"
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
  else
    ok 'All requested AUR packages are already installed.'
  fi
else
  fail 'yay could not be made available; skipping AUR application installation.'
fi

step '07/09 · Enabling mbpfan if installed'
if pacman -Q mbpfan >/dev/null 2>&1; then
  sudo systemctl enable --now mbpfan.service
  ok 'mbpfan service enabled.'
else
  warn 'mbpfan is not installed; its service was not enabled.'
fi

step '08/09 · Creating screenshot destination'
mkdir -p "$HOME/Pictures/Screenshots"
ok 'Created ~/Pictures/Screenshots.'

step '09/09 · Adding managed Lua configuration block'
MARKER_START='-- BEGIN ARCH-HYPRLAND-ESSENTIALS (managed by setup script)'
MARKER_END='-- END ARCH-HYPRLAND-ESSENTIALS'
TMP=$(mktemp)
trap 'rm -f -- "$TMP"; fail "Setup stopped at line $LINENO. Review the message above; your backup should remain available."' ERR
# Preserve everything outside this script-managed block on repeat runs.
awk -v start="$MARKER_START" -v end="$MARKER_END" '
  $0 == start {inside=1; next}
  $0 == end {inside=0; next}
  !inside {print}
' "$CONFIG_FILE" > "$TMP"
cat >> "$TMP" <<'LUA'

-- BEGIN ARCH-HYPRLAND-ESSENTIALS (managed by setup script)
-- Authentication agent and notification daemon startup.
hl.on("hyprland.start", function ()
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("mako")
end)

-- Keyboard backlight (MacBook internal keyboard LED)
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d spi::kbd_backlight set 10%+"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d spi::kbd_backlight set 10%-"))

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("zen-browser"))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- Screenshots: Ctrl + Shift + 6 = selected region; Ctrl + Shift + 5 = full screen.
hl.bind("CTRL + SHIFT + 6", hl.dsp.exec_cmd('g=$(slurp) && grim -g "$g" "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" && notify-send "Screenshot" "Selection captured"'))
hl.bind("CTRL + SHIFT + 5", hl.dsp.exec_cmd('grim "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" && notify-send "Screenshot" "Full screen captured"'))


-- Move focused window to left/right workspace

hl.bind(mainMod .. " +  left",  hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ workspace = "r+1" }))


-- END ARCH-HYPRLAND-ESSENTIALS
LUA
cp "$TMP" "$CONFIG_FILE"
rm -f "$TMP"
trap 'fail "Setup stopped at line $LINENO. Review the message above; your backup should remain available."' ERR
ok 'Lua block updated. Repeat runs replace only this marked block, avoiding duplicates.'

printf '\n%sInstalled/configured package check:%s\n' "$GREEN" "$RESET"
for pkg in hyprpolkitagent qt5-wayland qt6-wayland noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd bluez bluez-utils pipewire pipewire-alsa pipewire-pulse wireplumber brightnessctl lm_sensors acpi thunar gvfs tumbler file-roller thunar-archive-plugin grim slurp libnotify mako playerctl xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk tlp mbpfan google-chrome zen-browser-bin visual-studio-code-bin; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$pkg"; else printf '  %s–%s %s (not detected)\n' "$YELLOW" "$RESET" "$pkg"; fi
done

printf '\n%sBluetooth remains disabled/not enabled at boot.%s To use it later: %s sudo systemctl start bluetooth %s\n' "$YELLOW" "$RESET" "$BOLD" "$RESET"
printf '%sCheck temperatures with: sensors | Check battery with: acpi -b | Open file manager with: thunar%s\n' "$CYAN" "$RESET"
printf '\n%s%sSETUP COMPLETE%s\n' "$GREEN" "$BOLD" "$RESET"
printf 'Backup: %s\nConfig edited: %s\n' "$BACKUP" "$CONFIG_FILE"
warn 'Reload Hyprland or log out and back in for Lua changes to take effect.'
