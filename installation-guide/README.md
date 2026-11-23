# Arch Linux — Manual Installation Guide

A step-by-step guide to manually installing Arch Linux on a MacBook Pro 2017.

**Target Device:** MacBook Pro 13-inch (2017)  
**Model Identifier:** MacBookPro14,1  
**Architecture:** x86_64  
**Bootloader:** GRUB  
**Filesystem:** ext4  
**Installation Type:** UEFI

> This guide follows my personal installation workflow. It's primarily written around my MacBook's partition layout, so don't blindly copy disk names or partition numbers if your hardware is different.

---

# 1. Inspect Your Disk Layout

Before doing anything, we need to identify our disks and partitions.

Boot into the Arch Linux installation USB and run:

```bash
lsblk
```

`lsblk` displays all available block devices, their sizes, partition layouts and mount points.

### Example output

```text
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 967.1M  1 loop /run/archiso/airootfs
sda           8:0    1  29.3G  0 disk
└─sda1        8:1    1  29.3G  0 part
nvme0n1     259:0    0 233.8G  0 disk
├─nvme0n1p1 259:1    0   300M  0 part
└─nvme0n1p2 259:2    0 233.5G  0 part
nvme0n2     259:3    0     8K  0 disk
```

### Understanding the output

| Device | Purpose |
|---|---|
| `sda` | Installation USB |
| `nvme0n1` | Main internal SSD |
| `nvme0n1p1` | EFI partition |
| `nvme0n1p2` | macOS APFS partition |

In my case:

- `nvme0n1p1` is the existing EFI partition. We need to preserve it.
- `nvme0n1p2` contains macOS. We need to preserve it.
- The remaining space will be used for Arch Linux.

**IMPORTANT:** Your disk names and partition numbers may be different. Always identify your actual internal SSD before proceeding.

## Shrink macOS and create free space

We need to create unallocated space for Arch Linux from macOS itself.

1. Reboot into macOS.
2. Hold the Option (⌥) key during startup.
3. Select macOS.
4. Open Disk Utility.
5. Select **View → Show All Devices**.
6. Select the APFS Container, not an individual volume.
7. Click **Partition** (NOT Erase).
8. Reduce the macOS partition size.
9. Leave the remaining space unallocated.
10. Select msfat file system while partitioning

### Example partition allocation

| Partition | Size |
|---|---:|
| macOS | 150 GB |
| Free space for Arch | ~80 GB |

These are example values, not mandatory sizes. Choose an allocation that suits your storage requirements.

**DO NOT:**

- Delete the APFS container.
- Format the macOS partition.
- Touch or delete the existing EFI partition.
- Create a filesystem in the newly unallocated space yet.

Once done, boot back into your Arch installation USB.

---

# 2. Partition Disk Using fdisk

Now that we have free space, we'll use `fdisk` to create our Linux partitions.

In my setup, the internal SSD is `/dev/nvme0n1`.

```bash
fdisk /dev/nvme0n1
```

**Before proceeding:** Make sure this is actually your internal SSD. Selecting the wrong disk can destroy your data.

## Step 1 — Display existing partitions

Inside fdisk, type:

```text
p
```

Press Enter.

This displays the current partition table.

Check that your EFI and macOS partitions are present and that you're working with the correct disk.

## Step 2 — Delete p3

```text
d
```

When prompted for the partition number, enter:

```text
3
```

Press Enter.

This is specific to my previous partition layout. Only delete a partition after confirming that it is the intended Linux partition and does not contain data you need.

If fdisk reports an existing APFS signature, stop and verify the partition identity before agreeing to remove it.

## Step 3 — Create ROOT partition

Type:

```text
n
```

fdisk will ask for three things:

**Partition number:**

Press Enter to accept the default.

**First sector:**

Press Enter to accept the default.

**Last sector:**

```text
+95G
```

This allocates approximately 95 GB to the Linux root partition.

You can change this value depending on your available space.

Examples:

| Value | Allocation |
|---|---:|
| `+50G` | 50 GB |
| `+80G` | 80 GB |
| `+95G` | 95 GB |
| `+100G` | 100 GB |

Use a size that leaves enough room for your swap partition.

## Step 4 — Create SWAP partition

Type:

```text
n
```

**Partition number:**

Press Enter.

**First sector:**

Press Enter.

**Last sector:**

Press Enter to use the remaining available space.

This creates the second Linux partition, which we'll use for swap.

## Step 5 — Set SWAP partition type

Type:

```text
t
```

Select the swap partition:

```text
4
```

Enter the partition type:

```text
19
```

This selects the Linux swap partition type for the GPT partition table.

## Step 6 — Verify your partition layout

Type:

```text
p
```

Your expected layout should look something like this:

| Partition | Purpose | Expected size |
|---|---|---:|
| p1 | Existing EFI | 300 MB |
| p2 | macOS | Depends on allocation |
| p3 | Linux ROOT | ~95 GB |
| p4 | Linux SWAP | Remaining space |

Check everything carefully before saving.

If the partition layout isn't what you expected, do not continue.

## Step 7 — Save partition changes

Type:

```text
w
```

Press Enter.

This writes the new partition table to disk.

**Remember:** This is the point where your partition changes are committed.

---

# 3. Format Partitions

Now we need to create filesystems on our Linux partitions.

We'll use ext4 for ROOT and Linux swap for SWAP.

## Step 1 — Format ROOT (p3)

```bash
mkfs.ext4 /dev/nvme0n1p3
```

`mkfs.ext4` creates an ext4 filesystem.

This prepares the partition for the Arch Linux installation.

**WARNING:** Formatting permanently destroys existing data on the selected partition. Double-check the partition number before running this.

## Step 2 — Initialize SWAP (p4)

```bash
mkswap /dev/nvme0n1p4
```

This initializes the partition as Linux swap.

Now enable it:

```bash
swapon /dev/nvme0n1p4
```

Swap provides additional virtual memory space.

---

# 4. Mount Partitions

Before installing Arch, we need to mount our partitions under `/mnt`.

The installer uses `/mnt` as the root directory of our new Linux installation.

## Step 1 — Mount ROOT

```bash
mount /dev/nvme0n1p3 /mnt
```

This mounts the Linux root partition at `/mnt`.

## Step 2 — Create EFI mount point

```bash
mkdir -p /mnt/boot
```

This creates the `/boot` directory inside our new Arch installation.

The `-p` option ensures the directory is created without errors if it already exists.

## Step 3 — Mount EFI

```bash
mount /dev/nvme0n1p1 /mnt/boot
```

This mounts the existing EFI partition at `/mnt/boot`.

We're reusing the EFI partition already present on the MacBook.

**IMPORTANT:** Do not format this partition. It contains boot files that may be required by macOS.

---

# 5. Install Arch Linux

Now comes the actual installation.

We'll use `pacstrap` to install the base system and the packages required for our initial setup.

```bash
pacstrap /mnt base linux linux-firmware nano sudo networkmanager grub efibootmgr
```

### What are these packages?

| Package | Purpose |
|---|---|
| `base` | Essential Arch Linux system |
| `linux` | Linux kernel |
| `linux-firmware` | Firmware for supported hardware |
| `nano` | Terminal text editor |
| `sudo` | Run commands with elevated privileges |
| `networkmanager` | Network connection management |
| `grub` | Bootloader |
| `efibootmgr` | Manage UEFI boot entries |

Wait for the installation to finish.

## Generate fstab

After installing the packages, generate the filesystem table:

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

This detects mounted filesystems and writes their UUID-based mount configuration into `/etc/fstab`.

The `>>` operator appends the generated entries to the file.

This allows Arch to identify and mount its partitions during future boots.

---

# 6. Enter Chroot

Now we need to enter our newly installed Arch system.

```bash
arch-chroot /mnt
```

Once inside, commands will operate on the installed Arch system instead of the temporary installation environment.

From this point onward, we're configuring our actual Linux installation.

---

# 7. System Configuration

Let's configure the basic system settings.

## Step 1 — Set Timezone

My timezone is Asia/Karachi.

Run:

```bash
ln -sf /usr/share/zoneinfo/Asia/Karachi /etc/localtime
```

This creates a symbolic link to the selected timezone.

You can use another timezone if required.

Examples:

| Location | Timezone |
|---|---|
| Pakistan | `Asia/Karachi` |
| United Kingdom | `Europe/London` |
| United States (New York) | `America/New_York` |
| United States (Los Angeles) | `America/Los_Angeles` |
| India | `Asia/Kolkata` |
| Japan | `Asia/Tokyo` |

Next, synchronize the hardware clock:

```bash
hwclock --systohc
```

This sets the system hardware clock based on the current system time.

## Step 2 — Configure Locale

Locale controls the system's language and regional formatting.

Open the locale configuration file:

```bash
nano /etc/locale.gen
```

Find this line:

```text
#en_US.UTF-8 UTF-8
```

Remove the `#` from the beginning:

```text
en_US.UTF-8 UTF-8
```

You can enable additional locales if you need them.

### Save and exit Nano

- `Ctrl + O` → Save.
- Press Enter to confirm.
- `Ctrl + X` → Exit.

Generate the selected locale:

```bash
locale-gen
```

Now set the default system locale:

```bash
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

You can replace `en_US.UTF-8` with another locale that you've enabled in `/etc/locale.gen`.

## Step 3 — Configure Keyboard

Set the default virtual console keyboard layout:

```bash
echo "KEYMAP=us" > /etc/vconsole.conf
```

The value `us` represents the US keyboard layout.

Other possible layouts include:

- `uk` — United Kingdom
- `de` — German
- `fr` — French

Choose the layout that matches your keyboard.

## Step 4 — Set Hostname

The hostname is the name assigned to your computer on the network.

Run:

```bash
echo "archmac" > /etc/hostname
```

Here, `archmac` is just my example hostname.

You can replace it with anything you prefer.

Examples:

- `archmac`
- `pinkBox`
- `devmachine`
- `linuxbox`

Use a simple hostname without spaces.

## Step 5 — Configure Hosts

Open the hosts configuration file:

```bash
nano /etc/hosts
```

Add:

```text
127.0.0.1   localhost
::1         localhost
127.0.1.1   archmac.localdomain archmac
```

If you changed your hostname in the previous step, replace `archmac` here with your chosen hostname.

For example, if your hostname is `pinkBox`, the last line becomes:

```text
127.0.1.1   archmac.localdomain pinkBox
```

Save and exit Nano.

## Step 6 — Set Root Password

Run:

```bash
passwd
```

You'll be asked to enter a new root password.

1. Enter your password.
2. Press Enter.
3. Re-enter the same password.
4. Press Enter.

**Note:** Linux does not display password characters while you're typing. That's completely normal.

---

# 8. Install and Configure GRUB

Now we'll install and configure GRUB as our bootloader.

## Step 1 — Install GRUB packages

```bash
pacman -S grub efibootmgr
```

This ensures that GRUB and the UEFI boot management utility are installed.

## Step 2 — Install GRUB

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
```

This installs GRUB for x86_64 UEFI systems.

### Understanding the command

| Argument | Purpose |
|---|---|
| `--target=x86_64-efi` | Target UEFI architecture |
| `--efi-directory=/boot` | Location of mounted EFI partition |
| `--bootloader-id=GRUB` | Name of the UEFI boot entry |

The bootloader ID can be changed if you prefer another name.

For example:

```text
--bootloader-id=Arch
```

## Step 3 — Generate GRUB configuration

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

This generates the GRUB configuration file.

It detects installed kernels and configures the boot menu.

---

# 9. Create a Normal User

We don't want to use the root account for everyday work.

Let's create a normal user with sudo privileges.

## Step 1 — Create User

```bash
useradd -m -G wheel -s /bin/bash ha
```

### Understanding the command

| Argument | Purpose |
|---|---|
| `-m` | Create the user's home directory |
| `-G wheel` | Add the user to the wheel group |
| `-s /bin/bash` | Set Bash as the default shell |
| `ha` | Username |

In my setup, the username is `ha`.

You can replace it with your preferred username.

For example:

```text
k0haii
alex
archuser
developer
```

If you change the username, remember to use the same username in the next command.

## Step 2 — Set User Password

```bash
passwd ha
```

Replace `ha` with the username you created if you chose a different one.

Enter and confirm the new password.

## Step 3 — Enable sudo for wheel group

Open the sudoers configuration:

```bash
EDITOR=nano visudo
```

Find this line:

```text
# %wheel ALL=(ALL:ALL) ALL
```

Remove the `#` at the beginning:

```text
%wheel ALL=(ALL:ALL) ALL
```

This allows members of the `wheel` group to execute commands using sudo.

Since we added our user to the wheel group earlier, they will now have sudo access.

### Save and exit

- `Ctrl + X`
- Press `Y`
- Press Enter

---

# 10. Finish Installation

That's it. Our base Arch installation is ready.

Now we just need to leave the chroot, unmount the installation and reboot.

## Step 1 — Exit Chroot

```bash
exit
```

This takes us back to the Arch installation USB environment.

## Step 2 — Unmount Partitions

```bash
umount -R /mnt
```

This recursively unmounts the filesystems mounted under `/mnt`.

## Step 3 — Reboot

```bash
reboot
```

Your system will restart.

Remove the installation USB when appropriate and boot into your newly installed Arch Linux system.

---

# Installation Complete!

You've successfully installed a minimal Arch Linux system.

At this point, you have:

- Arch Linux installed.
- Linux kernel and firmware.
- ext4 root filesystem.
- Swap partition.
- Existing EFI partition mounted.
- GRUB bootloader installed.
- Timezone and locale configured.
- Hostname configured.
- Root account configured.
- Normal user created.
- Sudo access enabled.

**This is only the base installation.** Desktop environments, window managers, graphics configuration, audio, Wi-Fi utilities and development tools can be installed separately.

Welcome to Arch Linux. :)
