# MacBook Audio Repair — Arch Linux

This is a script I made to fix the audio setup on my MacBook Pro 2017 running Arch Linux.

My system specifications:

| Component | Specification |
|---|---|
| Model | MacBook Pro 13-inch (2017) |
| Model Identifier | MacBookPro14,1 |
| Processor | Intel Core i7-7660U |
| RAM | 16 GB |
| Graphics | Intel Iris Plus Graphics 640 |
| Audio | Cirrus Logic CS8409 |

You don't have to panic about dependencies or pre-work. I've included everything for ya (yeah bro, take it).

The setup installs the required audio packages, downloads the Cirrus CS8409 firmware files, and installs the MacBook audio driver.

There are **two ways** to do this: use the script or follow the manual installation steps.

---

## 1. Using the script (Recommended)

First, make sure you have `curl` installed. If you don't, install it:

```bash
sudo pacman -S --needed curl
```

Download the script:

```bash
curl -LO https://raw.githubusercontent.com/hamzatahir9091/Arch-on-Mac/main/audio/mac-audio-repair.sh
```

Make it executable:

```bash
chmod +x mac-audio-repair.sh
```

Run it:

```bash
./mac-audio-repair.sh
```

Follow the instructions in the terminal and let the script finish.

**Yessss, that's it!** Now just reboot and you're good to go!

---

## 2. Manual installation

Prefer doing things yourself? No worries. Here's how to set everything up manually.

### Step 1 — Install the required packages

```bash
sudo pacman -S pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol alsa-utils alsa-tools git base-devel linux-headers
```

### Step 2 — Download the Cirrus firmware

Create the firmware folder:

```bash
sudo mkdir -p /lib/firmware/cirrus
```

Download the three firmware files:

```bash
sudo curl -L https://github.com/leifliddy/macbook12-audio-driver/raw/master/firmware/cs8409-apple-141.bin -o /lib/firmware/cirrus/cs8409-apple-141.bin

sudo curl -L https://github.com/leifliddy/macbook12-audio-driver/raw/master/firmware/cs8409-apple-142.bin -o /lib/firmware/cirrus/cs8409-apple-142.bin

sudo curl -L https://github.com/leifliddy/macbook12-audio-driver/raw/master/firmware/cs8409-apple-143.bin -o /lib/firmware/cirrus/cs8409-apple-143.bin
```

Verify that the files are there:

```bash
ls /lib/firmware/cirrus/cs8409-apple-*
```

### Step 3 — Download and install the audio driver

Go to your home directory and remove the old driver source folder if it exists:

```bash
cd ~
rm -rf snd_hda_macbookpro
```

Clone the driver repository:

```bash
cd /tmp
git clone https://github.com/davidjo/snd_hda_macbookpro.git
```

Enter the directory:

```bash
cd snd_hda_macbookpro
```

Run the installer:

```bash
sudo ./install.cirrus.driver.sh
```

### Step 4 — Rebuild initramfs and reboot

```bash
sudo mkinitcpio -P
```

Reboot your system:

```bash
reboot
```

That's it! After rebooting, check whether your MacBook's audio devices are detected and working.

---

**Note:** These instructions are based on my MacBook Pro 2017 (MacBookPro14,1). Other MacBook models may require different firmware or driver configurations.
