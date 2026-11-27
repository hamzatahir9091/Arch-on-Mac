
# Arch Linux · Hyprland Post-Installation Setup

> A small post-install setup script for my stock Arch Linux + Hyprland Lua setup. It installs the essentials and selected applications, enables a few services, and adds a managed block to my Hyprland Lua configuration.

## Table of Contents

- [1. Download and run](#1-download-and-run)
- [2. What the script does](#2-what-the-script-does)
  - [Official packages](#official-packages)
  - [AUR packages and yay](#aur-packages-and-yay)
  - [Commands and directories](#commands-and-directories)
  - [Services enabled](#services-enabled)
- [3. Hyprland Lua configuration](#3-hyprland-lua-configuration)
- [4. Backup and reruns](#4-backup-and-reruns)
- [5. Notes](#5-notes)

---

## 1. Download and run

You don't need to clone the whole repository for this. Grab the script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/hamzatahir9091/Arch-on-Mac/main/post-installation-setup/post-install-setup.sh -o post-install-setup.sh
```

Make it executable and run it:

```bash
chmod +x post-install-setup.sh
./post-install-setup.sh
```

The script targets my current Lua config path:

```text
~/.config/hypr/hyprland.lua
```

Make sure that file exists before running it. Run the script as your normal user, not as root; it calls `sudo` when needed.

---

## 2. What the script does

This script is basically a post-install checklist automated into one run. It backs up my Hyprland Lua config, installs the tools and apps listed below (skipping packages that are already installed where applicable), enables the required services, and appends/refreshes its own managed configuration block.

### Official packages

Installed through `pacman`:

| Packages | What they're for |
|---|---|
| `hyprpolkitagent` | GUI authentication prompts for elevated actions |
| `qt5-wayland`, `qt6-wayland` | Qt applications on Wayland |
| `noto-fonts`, `noto-fonts-emoji`, `ttf-jetbrains-mono-nerd` | Text, emoji and terminal/UI glyphs |
| `bluez`, `bluez-utils` | Bluetooth CLI support (Bluetooth is not enabled at boot by this script) |
| `pipewire`, `pipewire-alsa`, `pipewire-pulse`, `wireplumber` | Audio infrastructure and compatibility |
| `brightnessctl`, `lm_sensors`, `acpi` | Brightness, temperature and battery information |
| `grim`, `slurp`, `libnotify`, `mako` | Screenshots, region selection and notifications |
| `playerctl` | Media playback control from the command line |
| `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` | Wayland portals, screen sharing and file-picker support |
| `tlp` | Laptop power management |
| `thunar`, `gvfs`, `tumbler`, `file-roller`, `thunar-archive-plugin` | File manager, volume/trash integration, thumbnails and archive handling |
| `base-devel`, `git` | Build tools and Git, used for AUR helper bootstrap |

Pacman uses `--needed`, so already-installed packages at the current repository version are not needlessly reinstalled.

### AUR packages and yay

The script checks for `yay`. If it isn't installed, it builds it from the AUR in a temporary directory under `/tmp`, using `git` and `makepkg`, then cleans up the temporary build directory.

It then installs any missing AUR packages from this list:

- `mbpfan` — MacBook fan control
- `google-chrome` — Google Chrome
- `zen-browser-bin` — Zen Browser
- `visual-studio-code-bin` — Visual Studio Code

Packages already installed are skipped. `mbpfan` temperature thresholds are not modified by this script.

### Commands and directories

In addition to package installation, the script runs these setup commands:

```bash
# Enable and start audio services for the current user
systemctl --user enable --now pipewire pipewire-pulse wireplumber

# Enable laptop power management
sudo systemctl enable --now tlp.service

# Enable fan control if mbpfan is installed
sudo systemctl enable --now mbpfan.service

# Create the screenshot destination
mkdir -p ~/Pictures/Screenshots
```

It also uses `sudo` for package installation and service setup as needed, and `makepkg` to build yay if it isn't already available.

### Services enabled

| Service | Scope | Action |
|---|---|---|
| `pipewire` | User | Enabled and started |
| `pipewire-pulse` | User | Enabled and started |
| `wireplumber` | User | Enabled and started |
| `tlp.service` | System | Enabled and started |
| `mbpfan.service` | System | Enabled and started if `mbpfan` is installed |

Bluetooth (`bluetooth.service`) is **not** enabled at boot. Start it manually when needed:

```bash
sudo systemctl start bluetooth
```

---

## 3. Hyprland Lua configuration

The script backs up `~/.config/hypr/hyprland.lua` first, then adds or replaces a marked block at the end of the file. It doesn't rewrite my existing config outside that block.

### Authentication agent and notifications

```lua
-- Authentication agent and notification daemon startup.
hl.on("hyprland.start", function ()
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("mako")
end)
```

### Keyboard backlight

```lua
-- Keyboard backlight (MacBook internal keyboard LED)
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d spi::kbd_backlight set 10%+"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d spi::kbd_backlight set 10%-"))
```

### Screenshots

```lua
-- Ctrl + Shift + 6 = selected region; Ctrl + Shift + 5 = full screen.
hl.bind("CTRL + SHIFT + 6", hl.dsp.exec_cmd('g=$(slurp) && grim -g "$g" "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" && notify-send "Screenshot" "Selection captured"'))
hl.bind("CTRL + SHIFT + 5", hl.dsp.exec_cmd('grim "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" && notify-send "Screenshot" "Full screen captured"'))
```

Both save timestamped PNG files in `~/Pictures/Screenshots` and notify me when the capture succeeds.

### Workspace navigation

```lua
-- Move to the previous and next workspace
hl.bind(mainMod .. " + left",  hl.dsp.workspace({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.workspace({ direction = "right" }))
```

These bindings use `mainMod`, which should already be defined in the existing Lua config.

---

## 4. Backup and reruns

Before installing packages or editing the config, the script creates a timestamped backup, for example:

```text
~/.config/hypr/hyprland.lua.backup-YYYYMMDD-HHMMSS
```

The added Lua entries are wrapped in markers:

```lua
-- BEGIN ARCH-HYPRLAND-ESSENTIALS (managed by setup script)
-- ... managed setup entries ...
-- END ARCH-HYPRLAND-ESSENTIALS
```

On subsequent runs, it replaces this managed block rather than adding another copy. Everything outside the markers is preserved.

---

## 5. Notes

- This is written around my current Arch + Hyprland Lua setup and the config path above.
- Run it as a regular user. Don't launch it with `sudo`.
- Bluetooth is installed, but isn't enabled automatically.
- The script doesn't adjust `mbpfan` temperature thresholds.
- Reload Hyprland or log out and back in after the script finishes so the Lua changes take effect.
