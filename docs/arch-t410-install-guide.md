# Arch Linux Installation Guide — ThinkPad T410

> **Repo:** [linux-bash-cheatsheet](../README.MD) · **Related:** [Polybar battery](./archcraft-polybar-battery.md) · [i3 tweaks (lock, brightness, fonts)](./archcraft-i3wm-t410-tweaks.md) · Bash: [../scripts/.bash_profile](../scripts/.bash_profile)

**Hardware:** ThinkPad T410 · Intel Core i7-620M (1st gen) · 4 GB RAM · NVIDIA NVS 3100M  
**Boot:** Legacy BIOS only (not UEFI)  
**Official reference:** [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide)

---

## Table of contents

1. [Hardware overview](#1-hardware-overview)
2. [Pre-installation checklist](#2-pre-installation-checklist)
3. [Create installation media](#3-create-installation-media)
4. [BIOS configuration](#4-bios-configuration)
5. [Live environment — step-by-step](#5-live-environment--step-by-step)
6. [Wi-Fi setup (iwctl — live ISO only)](#6-wi-fi-setup-iwctl--live-iso-only)
7. [Disk partitioning](#7-disk-partitioning)
8. [Install base system](#8-install-base-system)
9. [Configure system (chroot)](#9-configure-system-chroot)
10. [Reboot](#10-reboot)
11. [Wi-Fi on installed system (nmtui)](#11-wi-fi-on-installed-system-nmtui)
12. [Graphics drivers](#12-graphics-drivers)
13. [Archcraft i3wm (4 GB RAM)](#13-archcraft-i3wm-4-gb-ram)
14. [ThinkPad-specific extras](#14-thinkpad-specific-extras)
15. [Post-install checklist (verified on T410)](#15-post-install-checklist-verified-on-t410)
16. [Post-install verification](#16-post-install-verification)
17. [Troubleshooting](#17-troubleshooting)
18. [References](#18-references)

---

## 1. Hardware overview

| Component | Details | Linux status |
|-----------|---------|--------------|
| CPU | Intel Core i7-620M, 2C/4T, 64-bit | Supported — install **x86_64** Arch |
| RAM | 4 GB (max 8 GB, 2× SO-DIMM) | Usable; upgrade to 8 GB strongly recommended |
| GPU | NVS 3100M (GT218) + Intel HD on CPU | Both work; see [Graphics](#12-graphics-drivers) |
| Firmware | Legacy BIOS only | Install in **BIOS/Legacy** mode |
| Wi-Fi | Intel 6200 / 6300 / 6250 typical | `iwlwifi` + `linux-firmware` |
| Ethernet | Intel Gigabit | Works (`e1000e`); base T410 has no RJ45 jack |
| TrackPoint | PS/2 | Works with `libinput` |

[ArchWiki Lenovo laptops](https://wiki.archlinux.org/title/Laptop/Lenovo) lists T410 as working for video, sound, Ethernet, Wi-Fi, and Bluetooth.

---

## 2. Pre-installation checklist

### What you need

- USB flash drive (≥ 2 GB)
- Another computer to write the ISO
- Internet during install (packages download live)
- Wi-Fi password **or** USB Ethernet adapter
- Backup of existing data on the T410 disk

### Recommended hardware upgrades

- **RAM:** 2× 4 GB DDR3 SO-DIMM → 8 GB max
- **Storage:** Replace HDD with SATA SSD; enable `fstrim.timer` after install

---

## 3. Create installation media

### Download

1. https://archlinux.org/download/
2. Download latest **x86_64 ISO**
3. Verify with `sha256sums.txt`

**macOS verify:**

```bash
shasum -a 256 -c sha256sums.txt 2>&1 | grep archlinux
```

### Write to USB

**macOS:**

```bash
diskutil list
diskutil unmountDisk /dev/diskX
sudo dd if=~/Downloads/archlinux-*.iso of=/dev/rdiskX bs=4m status=progress
diskutil eject /dev/diskX
```

**Linux:**

```bash
sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `diskX` / `sdX` with your USB device.

---

## 4. BIOS configuration

Press **F1** at boot. Press **F12** for one-time boot menu → **USB HDD**.

| Setting | Value |
|---------|-------|
| Boot mode | Legacy / BIOS (not UEFI) |
| SATA mode | **AHCI** (not RAID) |
| Secure Boot | Disabled |
| Wireless LAN | **Enabled** (Config → Network) |
| Graphics | **Integrated** or **Discrete** — not Optimus |

### Graphics BIOS choice

| Option | Linux result | Use when |
|--------|--------------|----------|
| **Integrated** | Intel HD (`i915`) | Best battery, simplest setup |
| **Discrete** | NVS 3100M (`nouveau`) | Need NVIDIA outputs (e.g. dock DisplayPort) |
| **Optimus / Switchable** | Poor support on T410 | **Avoid** |

---

## 5. Live environment — step-by-step

Boot USB → select **Arch Linux install medium** → root shell (`root@archiso`).

### Step 5.1 — Confirm BIOS mode

```bash
cat /sys/firmware/efi/fw_platform_size
```

**Expected:** `No such file or directory` (= Legacy). If `64`, fix BIOS and reboot installer.

Optional:

```bash
loadkeys us
```

### Step 5.2 — Connect to internet

See [Section 6 — Wi-Fi (live ISO only)](#6-wi-fi-setup-iwctl--live-iso-only).

Verify before continuing:

```bash
ping -c 3 archlinux.org
```

### Step 5.3 — Sync clock

```bash
timedatectl set-ntp true
```

### Step 5.4 — Identify disk

```bash
lsblk
fdisk -l
```

Typical disk: **`/dev/sda`**. If missing, set BIOS SATA = AHCI.

---

## 6. Wi-Fi setup (iwctl — live ISO only)

> **After install:** use [Section 11 — nmtui / NetworkManager](#11-wi-fi-on-installed-system-nmtui), not `iwctl`.

### Enable hardware radio first

1. Toggle **hardware wireless switch** on T410 (front edge).
2. Press **Fn + F9** (once or twice, wait between presses).

Check rfkill:

```bash
rfkill list
```

Required:

```text
Hard blocked: no
Soft blocked: no
```

If soft-blocked:

```bash
rfkill unblock wifi
rfkill unblock all
```

If **hard blocked** persists → BIOS → Wireless LAN = Enabled → reboot live USB.

### Connect with iwctl

> **`NetworkConfigurationEnabled: disabled` is normal.** iwd connects Wi-Fi; live ISO gets IP via systemd-networkd.

```bash
iwctl
```

Inside `iwd>`:

```text
device list
device wlan0 set-property Powered on
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YourSSID"
exit
```

Verify:

```bash
ping -c 3 archlinux.org
```

If ping fails after `Connected`:

```bash
ip addr show wlan0
systemctl restart systemd-networkd
sleep 5
ping -c 3 archlinux.org
```

---

## 7. Disk partitioning

### Recommended layout (BIOS + MBR)

| Partition | Size | Type | Mount |
|-----------|------|------|-------|
| `sda1` | 4 GB | Linux swap (82) | `[SWAP]` |
| `sda2` | Rest | Linux (83) | `/` ext4 |

Minimum root: 32 GB; 64 GB+ recommended with desktop.

### fdisk

```bash
fdisk /dev/sda
```

```
o          # new MBR table
n, p, 1, Enter, +4G
t, 1, 82   # swap
n, p, 2, Enter, Enter
w          # write
```

### Format and mount

```bash
mkswap /dev/sda1
swapon /dev/sda1
mkfs.ext4 -L archroot /dev/sda2
mount /dev/sda2 /mnt
```

> **Note:** GPT + GRUB can cause black-screen boot on some T410 units. MBR is the safest first install. See [Troubleshooting](#15-troubleshooting).

---

## 8. Install base system

### Mirrors (optional)

```bash
reflector --country 'United States' --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
```

### pacstrap

```bash
pacstrap -K /mnt \
  base base-devel linux linux-firmware intel-ucode \
  iwd networkmanager nano vim sudo \
  grub os-prober
```

| Package | Purpose |
|---------|---------|
| `linux-firmware` | **Required** for Intel Wi-Fi |
| `intel-ucode` | CPU microcode (i7-620M) |
| `iwd` + `networkmanager` | Network |
| `grub` | Bootloader (BIOS) |

**Do not install** official `nvidia` package — NVS 3100M is unsupported.

### fstab

```bash
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

Verify swap and root entries are present.

---

## 9. Configure system (chroot)

```bash
arch-chroot /mnt
```

### Timezone

```bash
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
```

Change `America/New_York` to your region.

### Locale

```bash
nano /etc/locale.gen
# Uncomment: en_US.UTF-8 UTF-8

locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### Hostname

```bash
echo "t410" > /etc/hostname
```

### Network

```bash
systemctl enable NetworkManager.service
echo 'options iwlwifi 11n_disable=1' > /etc/modprobe.d/iwlwifi.conf
```

### Root password

```bash
passwd
```

### User account

```bash
useradd -m -G wheel,audio,video,storage,power -s /bin/bash yourname
passwd yourname
```

Replace `yourname` with your login name. The **`wheel`** group is required for sudo access (next step).

### Sudoers (allow your user to run sudo)

The `sudo` package is installed via `pacstrap`. Grant the `wheel` group permission to use it:

```bash
EDITOR=nano visudo
```

Find this line (near the end of the file):

```text
# %wheel ALL=(ALL:ALL) ALL
```

**Uncomment it** — remove the leading `#`:

```text
%wheel ALL=(ALL:ALL) ALL
```

On older sudo configs the line may look like:

```text
# %wheel ALL=(ALL) ALL
```

Uncomment that form instead if that is what you see.

Save and exit (`Ctrl+O`, Enter, `Ctrl+X` in nano).

**Verify** (after reboot, log in as `yourname` — not root):

```bash
sudo whoami
# expected output: root
```

If `sudo` says *"yourname is not in the sudoers file"*, boot the live USB, `arch-chroot /mnt`, and run `visudo` again.

> **Do not** enable `%wheel ALL=(ALL) NOPASSWD: ALL` unless you understand the security tradeoff (no password for sudo).

### Initramfs

```bash
mkinitcpio -P
```

### GRUB (install to disk, not partition)

```bash
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

### TLP (power management)

```bash
pacman -S tlp tlp-rdw
systemctl enable tlp.service
systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

Add to `/etc/tlp.conf`:

```ini
DEVICES_TO_ENABLE_ON_STARTUP="wifi"
```

### Exit chroot

```bash
exit
```

---

## 10. Reboot

```bash
umount -R /mnt
swapoff -a
reboot
```

Remove USB when prompted.

---

## 11. Wi-Fi on installed system (nmtui)

After reboot, the installed system uses **NetworkManager** — not `iwctl` (iwd live ISO only).

### 11.1 Enable the Wi‑Fi radio

```bash
rfkill list
rfkill unblock wifi
sudo nmcli radio wifi on
```

If **Hard blocked: yes** → T410 hardware switch + **Fn+F9**.

If TLP is enabled and Wi‑Fi stays off at boot, set in `/etc/tlp.conf`:

```ini
DEVICES_TO_ENABLE_ON_STARTUP="wifi"
```

Then `sudo systemctl restart tlp`.

### 11.2 Connect with `nmtui` (menu — recommended)

Interactive TUI: pick network, enter password.

```bash
sudo nmtui
```

1. **Activate a connection** → select your Wi‑Fi → enter password if prompted.

First time (no saved profile):

1. **Edit a connection** → **Add** → **Wi‑Fi**
2. Profile name: anything (e.g. `home-wifi`)
3. **SSID:** your network name
4. **Security:** WPA & WPA2 Personal
5. **Password:** your Wi‑Fi password
6. **OK** → back → **Activate a connection** → choose the profile

Verify:

```bash
ping -c 3 archlinux.org
```

`nmtui` is included in the **`networkmanager`** package (installed in [Section 8](#8-install-base-system)).

### 11.3 Connect with `nmcli` (command line)

```bash
nmcli device wifi list
nmcli device wifi connect "YourSSID" password "yourpassword"
ping -c 3 archlinux.org
```

Saved profiles:

```bash
nmcli connection show
nmcli connection up "ProfileName"
```

### 11.4 Archcraft i3 — Super+N Wi‑Fi menu

**Super+N** runs `~/.config/i3/scripts/network_menu` (bundled with Archcraft — **not** AUR/`yay`).

Requires:

```bash
sudo pacman -S python python-gobject networkmanager rofi
~/.config/i3/scripts/network_menu   # test from terminal
```

If it fails, use **`sudo nmtui`** ([Section 11.2](#112-connect-with-nmtui-menu--recommended)).

---

## 12. Graphics drivers

NVS 3100M = **GT218 (Tesla)**. [ArchWiki NVIDIA](https://wiki.archlinux.org/title/NVIDIA): no longer actively supported by proprietary drivers.

### Option A — Nouveau / Intel (recommended)

**BIOS = Integrated:**

```bash
pacman -S mesa
# Intel modesetting/i915 via mesa — no extra driver required on modern Arch
```

**BIOS = Discrete:**

```bash
pacman -S mesa
# nouveau is in the kernel; do NOT install xf86-video-nouveau (deprecated)
```

Verify:

```bash
lspci -k | grep -A3 VGA
lsmod | grep -E 'i915|nouveau'
```

### Option B — Legacy nvidia-340xx (not recommended)

- AUR: `nvidia-340xx-dkms`
- Breaks often on kernel updates; artifacts and black screens reported
- Use X11 only; pin `linux-lts` if attempted
- For daily use: **use Nouveau or Intel instead**

### Option C — Optimus / dual GPU

Do not use Bumblebee on T410. Set BIOS to Integrated **or** Discrete only.

---

## 13. Archcraft i3wm (4 GB RAM)

**`archcraft-i3wm`** is not a separate window manager — it is Archcraft’s **pre-configured i3 setup**: polybar, rofi, picom, dunst, pywal theming, and scripts. The actual WM is still **`i3-wm`**.

Requires **X11** + **`mesa`**. Works with Intel (`i915`) or NVIDIA (`nouveau`) on the T410.

Docs: [Archcraft i3wm wiki](https://wiki.archcraft.io/docs/window-managers/tiling-wm/i3wm) · [GitHub](https://github.com/archcraft-os/archcraft-i3wm)

> **Note:** `archcraft-i3wm` lives in Archcraft’s **third-party repo**, not official Arch `[extra]`. **`picom` and `bluez` are not dependencies** — install them explicitly (Section 15.4) to avoid flicker on T410.

### 13.1 Enable Archcraft repository

```bash
sudo tee /etc/pacman.d/archcraft-mirrorlist <<'EOF'
Server = https://packages.archcraft.io/$arch
EOF

sudo tee -a /etc/pacman.conf <<'EOF'

[archcraft]
SigLevel = Optional TrustAll
Include = /etc/pacman.d/archcraft-mirrorlist
EOF

sudo pacman -Sy
```

Third-party repo — you trust Archcraft’s packages. Remove the `[archcraft]` block from `pacman.conf` anytime to stop using it.

### 13.2 Install archcraft-i3wm stack

As your user (with `sudo`), after network works:

```bash
sudo pacman -S mesa xorg-server xorg-xinit xorg-xrandr \
  lightdm lightdm-gtk-greeter \
  pipewire pipewire-pulse wireplumber polkit \
  archcraft-i3wm archcraft-fonts archcraft-dunst-icons \
  alacritty thunar firefox \
  maim xclip \
  picom bluez bluez-utils bc \
  acpi upower light \
  python python-gobject \
  bash-completion fzf git

sudo systemctl enable lightdm NetworkManager bluetooth
reboot
```

| Package | Purpose |
|---------|---------|
| `archcraft-i3wm` | i3 configs, polybar, rofi, dunst, pywal theme (config references picom — package **not** included) |
| `archcraft-fonts` | **Required** — `archcraft` icon font, Symbols Nerd Font, JetBrains/Iosevka Nerd (polybar + rofi icons) |
| `archcraft-dunst-icons` | PNG icons for volume/brightness **dunst** notifications (`i3_volume`, `i3_brightness`) — not pulled by `archcraft-i3wm` |
| `mesa` | Graphics (Intel / nouveau) |
| `lightdm` | Login screen → session **i3** |
| `picom` | **Required on T410** — not an `archcraft-i3wm` dependency; fixes screen/terminal flicker |
| `bluez` + `bluez-utils` + `bc` | Polybar `bluetooth.sh` module (stops menubar flicker/errors) |
| `acpi` + `upower` + `light` | Polybar first-run scripts (`launch.sh` / `polybar.sh`) — **not** the same as `acpid` |
| `python` + `python-gobject` | Archcraft **Super+N** `network_menu` script |
| `alacritty` | Default terminal |
| `thunar` / `firefox` | File manager / browser (Super+Shift+F / W) |
| `bash-completion` + `fzf` + `git` | Mac-style shell (Section 15.5) |
| `maim` + `xclip` | Screenshot scripts |

> **`archcraft-i3wm` does not pull in `picom`, `bluez`, fonts, or `acpi`.** Autostart runs `~/.config/i3/scripts/i3_comp` (picom) and polybar runs `bluetooth.sh` — both fail silently if packages are missing, which causes flicker and garbage in the top bar. Without **`archcraft-fonts`**, polybar and rofi show gibberish instead of icons ([15.10](#1510-fix-menu-icons-gibberish-in-polybarrofi)). On first bar launch, **`launch.sh` runs `acpi -b`** — without the **`acpi`** package it prints *command not found* and permanently swaps the battery module for an empty placeholder — see **[archcraft-polybar-battery.md](./archcraft-polybar-battery.md)**.

**Wi‑Fi (Super+N)** — uses Archcraft’s built-in script, not AUR:

```bash
~/.config/i3/scripts/network_menu   # test; needs python-gobject
```

Fallback: **`sudo nmtui`** ([Section 11](#11-wi-fi-on-installed-system-nmtui)).

### 13.3 Apply configs to your user

On first install, the package post-install hook usually copies configs into `~/.config/i3`. If missing after install:

```bash
mkdir -p ~/.config
cp -r /etc/skel/.config/i3 ~/.config/
```

Config layout:

```text
~/.config/i3/
├── config          # main i3 config
├── config.d/       # keybindings, gaps, rules
├── theme/          # polybar + rofi themes
├── alacritty/      # terminal
├── scripts/        # autostart, wallpaper, applets
├── picom.conf
└── dunstrc
```

### 13.4 First login

1. LightDM → session **i3** → login.
2. Archcraft autostart runs polybar, dunst, wallpaper — and **attempts** picom via `i3_comp` (needs `picom` installed).

| Key | Action |
|-----|--------|
| **Super** (⊞ Windows key) | Rofi app launcher |
| **Super+Return** | Terminal (alacritty) |
| **Super+V** | Split side-by-side, then Super+Return for 2nd tile |
| **Super+H** | Split top/bottom |
| **Super+Q** / **Super+C** | Close focused window |
| **Super+1…0** | Switch workspace |
| **Super+Shift+1…0** | Move window to workspace |
| **Super+Shift+W** | Firefox |
| **Super+Shift+F** | Thunar |
| **Super+N** | Wi‑Fi menu (`network_menu` script) |
| **Super+X** | Power menu |
| **Super+Shift+C** | Reload i3 config |
| **Super+Shift+Q** | Quit i3 session |

Full keybind list: `~/.config/i3/config.d/02_keybindings.conf` · [Archcraft keybindings](https://wiki.archcraft.io/docs/window-managers/tiling-wm/i3wm#keybindings)

### 13.5 T410-specific tweaks (verified)

**Screen / terminal flicker** — install **picom** (not included in `archcraft-i3wm` deps):

```bash
sudo pacman -S picom
~/.config/i3/scripts/i3_comp
pgrep -a picom
```

On T410 this fixes white tearing when switching terminals/windows. Config: `~/.config/i3/picom.conf`. If sluggish later, disable shadows/blur there — do not remove picom unless flicker returns acceptable.

**Polybar menubar flicker / `bluetooth.sh` text** — install Bluetooth stack:

```bash
sudo pacman -S bluez bluez-utils bc
sudo systemctl enable --now bluetooth.service
~/.config/i3/theme/polybar/scripts/bluetooth.sh   # should print status, not errors
~/.config/i3/scripts/i3_bar
```

To hide BT entirely: remove `bluetooth` from `modules-right=` in `~/.config/i3/theme/polybar/config.ini`.

**NVIDIA / Alacritty black or crash** — prefix launches with:

```bash
LIBGL_ALWAYS_SOFTWARE=1 alacritty
```

**Firefox “profile cannot be loaded” / no `~/.mozilla`** — never run `sudo firefox`:

```bash
sudo chown -R $USER:$USER ~/.mozilla ~/.cache/mozilla 2>/dev/null
rm -rf ~/.cache/mozilla
firefox --ProfileManager   # Create Profile → Start Firefox
```

**Wallpaper** — edit `~/.config/i3/scripts/i3_autostart` → `hsetroot -cover '...'`

**Config updates** — after `pacman -Syu`, new configs may appear as `~/.config/i3_pacnew_YYYY-MM-DD`. Backup old `~/.config/i3`, rename pacnew to `i3`, re-login.

### 13.6 Bash setup (match macOS prompt/completion)

From this repo — **`scripts/.bash_profile`** (clone or copy from `linux-bash-cheatsheet`):

```bash
cp ~/github/linux-bash-cheatsheet/scripts/.bash_profile ~/.bash_profile
ln -sf ~/.bash_profile ~/.bashrc
source ~/.bash_profile
```

See also **[../scripts/README.MD](../scripts/README.MD)**.

Optional — show hostname in prompt (`nano ~/.bash_profile`), change `\u` to `\u@\h` in the `PS1=` line.

Secrets (AWS, vault, etc.) → `~/.bashrc.local` only (`chmod 600`).

### 13.7 Plain i3 fallback (no Archcraft repo)

If you prefer minimal i3 without third-party repos:

```bash
sudo pacman -S mesa xorg-server i3-wm i3status alacritty picom \
  lightdm lightdm-gtk-greeter rofi pipewire pipewire-pulse wireplumber
mkdir -p ~/.config/i3 && cp /etc/i3/config ~/.config/i3/config
sudo systemctl enable lightdm
```

### 13.8 Other desktops (if you change your mind)

| Desktop | Idle RAM | Notes |
|---------|----------|-------|
| **archcraft-i3wm** | ~400–700 MB | Themed i3 + polybar; more than bare i3 |
| Bare i3 | ~200–400 MB | Section 13.7 |
| Xfce / LXQt | ~300–600 MB | Traditional desktop |
| GNOME / KDE | 1–2 GB+ | Will swap on 4 GB |

---

## 14. ThinkPad-specific extras

```bash
sudo pacman -S acpid acpi upower light
sudo systemctl enable --now acpid.service
```

| Package | Purpose |
|---------|---------|
| `acpid` | ACPI events daemon (ThinkPad extras) |
| `acpi` | CLI — **`acpi -b`** in polybar `launch.sh` (battery detection on first bar start) |
| `upower` | Used by `polybar.sh` to auto-fill `system.ini` battery/adapter names |
| `light` | Backlight control — used by `polybar.sh` / `launch.sh` for brightness module |

> **`acpi` ≠ `acpid`.** Installing only `acpid` does **not** provide the `acpi` command.

**SSD trim** (after SSD upgrade):

```bash
systemctl enable fstrim.timer
```

**TrackPoint sensitivity** — `/etc/udev/rules.d/10-trackpoint.rules`:

```
ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", \
  ATTR{device/sensitivity}="240"
```

See [ArchWiki TrackPoint](https://wiki.archlinux.org/title/TrackPoint).

---

## 15. Post-install checklist (verified on T410)

Run in order after first login to Archcraft i3. Assumes [Section 13](#13-archcraft-i3wm-4-gb-ram) base install.

### 15.1 Wi‑Fi

```bash
rfkill unblock wifi
sudo nmcli radio wifi on
sudo nmtui
ping -c 3 archlinux.org
```

See [Section 11](#11-wi-fi-on-installed-system-nmtui). Remember **Fn+F9** / hardware switch if `Hard blocked: yes`.

### 15.2 Sudo access

```bash
sudo whoami   # must print: root
```

If not in sudoers → [Section 9 — Sudoers](#sudoers-allow-your-user-to-run-sudo).

### 15.3 System update

```bash
sudo pacman -Syu
reboot   # if kernel updated
```

### 15.4 Fix flicker — picom + polybar bluetooth

**Verified on T410:** missing packages caused screen tear and menubar garbage; installing these fixes it.

```bash
sudo pacman -S picom bluez bluez-utils bc
sudo systemctl enable --now bluetooth.service
~/.config/i3/scripts/i3_comp
pgrep -a picom
~/.config/i3/theme/polybar/scripts/bluetooth.sh
~/.config/i3/scripts/i3_bar
```

### 15.5 Bash profile (Mac-style)

From this repo — clone **`linux-bash-cheatsheet`** first, then:

```bash
cp ~/github/linux-bash-cheatsheet/scripts/.bash_profile ~/.bash_profile
ln -sf ~/.bash_profile ~/.bashrc
source ~/.bash_profile
```

Optional hostname in prompt — in `~/.bash_profile`, change `\u` to `\u@\h` in `PS1=`.

Private exports → `~/.bashrc.local` (`chmod 600`).

### 15.6 Git identity

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 15.7 Firefox (if profile missing)

Never `sudo firefox`.

```bash
sudo chown -R $USER:$USER ~/.mozilla ~/.cache/mozilla 2>/dev/null
firefox --ProfileManager
```

Create a profile → **Start Firefox**. Or launch with **Super+Shift+W**.

### 15.8 Wi‑Fi menu in i3 (optional)

```bash
sudo pacman -S python python-gobject
# Super+N — or keep using nmtui
```

### 15.9 One-shot command block

After Archcraft login, copy-paste:

```bash
rfkill unblock wifi && sudo nmcli radio wifi on
sudo nmtui
sudo pacman -Syu
sudo pacman -S archcraft-fonts archcraft-dunst-icons picom bluez bluez-utils bc acpi upower light python python-gobject bash-completion fzf git
sudo fc-cache -fv
sudo systemctl enable --now bluetooth.service
~/.config/i3/scripts/i3_comp
~/.config/i3/scripts/i3_bar
sudo whoami
# then: copy ~/.bash_profile, git config, firefox --ProfileManager if needed
```

### 15.10 Fix menu icons (polybar/rofi fonts + dunst PNGs)

Archcraft uses **two different “icon” systems**:

| Layer | Package | Used by |
|-------|---------|---------|
| **Font glyphs** in polybar/rofi | **`archcraft-fonts`** | Wi‑Fi, battery, volume %, menu button, etc. |
| **PNG files** for notifications | **`archcraft-dunst-icons`** | `i3_volume`, `i3_brightness` → `/usr/share/archcraft/icons/dunst/` |
| **GTK folder icons** (optional) | **`archcraft-icons-luv`** | Thunar — `xsettingsd` → `Luv-Folders-Dark` |

**Verified on T410:** without **`archcraft-fonts`**, polybar and rofi show boxes, random letters, or gibberish instead of Wi‑Fi, battery, volume, and launcher icons.

Polybar expects these fonts (from `~/.config/i3/theme/polybar/config.ini`):

```text
JetBrains Mono
Symbols Nerd Font
Iosevka Nerd Font
archcraft          ← custom Archcraft icon font (menu button, etc.)
```

Install from the **Archcraft repo** ([13.1](#131-enable-archcraft-repository)):

```bash
sudo pacman -S archcraft-fonts archcraft-dunst-icons
sudo fc-cache -fv
~/.config/i3/scripts/i3_bar
```

Verify dunst PNGs exist:

```bash
ls /usr/share/archcraft/icons/dunst/volume-high.png
ls /usr/share/archcraft/icons/dunst/brightness-80.png
```

| Package | Purpose |
|---------|---------|
| `archcraft-fonts` | Polybar/rofi **font** icons (~160 MB) |
| `archcraft-dunst-icons` | Volume/brightness notification PNGs — scripts error if this dir is missing |

> **Do not use `ac-fonts` or `ac-pixmaps`** — obsolete ISO names (2021). Use **`archcraft-fonts`** + **`archcraft-dunst-icons`** instead.

**Optional — GTK folder icons in Thunar** (`xsettingsd` uses `Luv-Folders-Dark`):

```bash
sudo pacman -S archcraft-icons-luv
```

**Verify fonts loaded:**

```bash
fc-list | grep -iE 'archcraft|symbols nerd|jetbrains|iosevka' | head -10
polybar -l info main 2>&1 | grep -i font
```

If polybar still loads **DejaVu** instead of **Symbols Nerd Font**, font names in config do not match what's installed — compare `fc-list` output with `config.ini` font lines.

### 15.11 Fix missing battery icon in polybar

Full steps (missing **`acpi`** package, `btna` placeholder, **`system.ini`** names on T410):

**[archcraft-polybar-battery.md](./archcraft-polybar-battery.md)**

Quick fix if you saw **`acpi: command not found`**:

```bash
sudo pacman -S acpi upower light
rm -f ~/.config/i3/theme/polybar/.module ~/.config/i3/theme/.system
sed -i 's/btna/battery/g; s/ bna / backlight /g' ~/.config/i3/theme/polybar/config.ini
~/.config/i3/scripts/i3_bar
```

### 15.12 Power menu, brightness keys, polybar font overflow

Lock/suspend broken, **Fn+Home/End** brightness, or **Offline** / clock text clipping the rounded polybar pills:

**[archcraft-i3wm-t410-tweaks.md](./archcraft-i3wm-t410-tweaks.md)**

---

## 16. Post-install verification

```bash
# BIOS mode
[ ! -d /sys/firmware/efi ] && echo "BIOS OK"

# Graphics
lspci -k | grep -A3 -E 'VGA|3D'

# Wi-Fi (installed system — not iwctl)
rfkill unblock wifi
sudo nmcli radio wifi on
sudo nmtui
# or: nmcli device wifi connect "SSID" password "pass"
ping -c 3 archlinux.org

# Swap
swapon --show

# Microcode
dmesg | grep microcode

# TLP
systemctl status tlp

# Sudo (as your user, not root)
sudo whoami

# Compositor + polybar BT (flicker fixes)
pgrep -a picom
systemctl is-active bluetooth
~/.config/i3/theme/polybar/scripts/bluetooth.sh

# Icon fonts (polybar + rofi)
fc-list | grep -iE 'archcraft|symbols nerd' | head -3

# Battery (polybar — names must match system.ini)
ls -1 /sys/class/power_supply/
cat /sys/class/power_supply/BAT0/capacity
grep -E 'sys_battery|sys_adapter' ~/.config/i3/theme/system.ini
```

---

## 17. Troubleshooting

| Problem | Fix |
|---------|-----|
| `NetworkConfigurationEnabled: disabled` | Normal — not an error (live ISO / iwctl only) |
| `Hard blocked: yes` | Hardware switch, Fn+F9, BIOS Wireless LAN |
| `wlan0` powered off | rfkill clear; [Section 11.1](#111-enable-the-wi-fi-radio) |
| Ping fails after Wi-Fi connect | `systemctl restart NetworkManager` |
| `iwlwifi: no suitable firmware` | `sudo pacman -S linux-firmware` |
| Wi-Fi unstable | `options iwlwifi 11n_disable=1` in `/etc/modprobe.d/iwlwifi.conf` |
| Screen / terminal flicker | Install **picom** + run `~/.config/i3/scripts/i3_comp` ([15.4](#154-fix-flicker--picom--polybar-bluetooth)) |
| Polybar shows `bluetooth.sh` / bar flicker | Install **bluez bluez-utils bc**; enable `bluetooth.service`; restart `i3_bar` |
| Gibberish / missing icons in polybar or rofi | Install **`archcraft-fonts`**; `fc-cache -fv`; restart `i3_bar` ([15.10](#1510-fix-menu-icons-polybarrofi-fonts--dunst-pngs)) |
| Missing dunst / volume / brightness PNG icons | **`sudo pacman -S archcraft-dunst-icons`** — installs `/usr/share/archcraft/icons/dunst/` ([15.10](#1510-fix-menu-icons-polybarrofi-fonts--dunst-pngs)) |
| `acpi: command not found` when running `i3_bar` | **[archcraft-polybar-battery.md](./archcraft-polybar-battery.md)** — Section A |
| No battery / power icon in polybar (other icons OK) | Same doc — Section A then B; or [15.11](#1511-fix-missing-battery-icon-in-polybar) quick fix |
| `module/backlight` XCB_NAME / Couldn't get data | [archcraft-polybar-battery.md](./archcraft-polybar-battery.md) §C — **`backlight`** → **`brightness`** in `config.ini` |
| Battery **0%** when AC plugged (charging animation) | Same doc §D — **`sys_adapter`** name + **`format-charging`** ramp instead of animation |
| Super+X lock or suspend does nothing | **[archcraft-i3wm-t410-tweaks.md](./archcraft-i3wm-t410-tweaks.md)** §1 — install `i3lock`; fix `rofi_powermenu` (`mpc &&` chain blocks suspend) |
| Fn+Home/End brightness dead | [tweaks doc §2](./archcraft-i3wm-t410-tweaks.md) — **`light` works manually** → patch **`i3_brightness`** or bind keys directly to **`light`** |
| Polybar text clips / overlaps oval pills (workspaces, date) | [tweaks doc §3](./archcraft-i3wm-t410-tweaks.md) — **`height`**, **`font-3`**, **`[module/i3]`** + **`[module/date]`** fonts/padding |
| Polybar **Offline** text clips rounded module | Same doc §3b — network/date font sizes |
| `module/mpd` / `module/song` connection refused | Same doc §4 — remove **`mpd`/`song`** from bar, or install **`mpd mpc`** and **`systemctl --user enable --now mpd`** |
| No battery in sysfs (`BAT0` missing) | Check battery seated; `dmesg \| grep -i battery`; try **`linux-lts`** kernel; see [Arch forum T410 battery thread](https://bbs.archlinux.org/viewtopic.php?id=241180) |
| `ac-fonts` / `ac-pixmaps` not found | Obsolete names — use **`archcraft-fonts`** instead |
| `pgrep picom` empty | `sudo pacman -S picom` — not pulled by `archcraft-i3wm` |
| Firefox profile missing | [Section 15.7](#157-firefox-if-profile-missing); never `sudo firefox` |
| Black screen after GRUB | Reinstall GRUB; or Syslinux ([forum](https://bbs.archlinux.org/viewtopic.php?id=159017)) |
| NVIDIA black screen | Remove nvidia packages; BIOS Integrated or nouveau + mesa |
| Alacritty won't open | `LIBGL_ALWAYS_SOFTWARE=1 alacritty` |
| No Wi‑Fi in i3 | **Super+N** (needs python-gobject) or **`sudo nmtui`** |
| `yay` / AUR not found | Not required for Wi‑Fi; use `nmtui` or install `yay` only if you need AUR |
| `archcraft-i3wm` not found | Enable `[archcraft]` repo ([13.1](#131-enable-archcraft-repository)) |
| Interface disabled in NM | rfkill, Fn+F9, TLP `DEVICES_TO_ENABLE_ON_STARTUP="wifi"` |
| `not in the sudoers file` | [Section 9 — Sudoers](#sudoers-allow-your-user-to-run-sudo) |
| Slow on 4 GB | Reduce picom blur in `picom.conf`; limit browser tabs; 8 GB RAM upgrade |

**Install workaround without Wi-Fi:** USB Ethernet or phone USB tethering for `pacstrap`.

---

## 18. References

- [Installation guide](https://wiki.archlinux.org/title/Installation_guide)
- [General recommendations](https://wiki.archlinux.org/title/General_recommendations)
- [Network / Wireless](https://wiki.archlinux.org/title/Network_configuration/Wireless)
- [Nouveau](https://wiki.archlinux.org/title/Nouveau)
- [NVIDIA (legacy note)](https://wiki.archlinux.org/title/NVIDIA)
- [TLP](https://wiki.archlinux.org/title/TLP)
- [TrackPoint](https://wiki.archlinux.org/title/TrackPoint)
- [i3](https://wiki.archlinux.org/title/I3)
- [Archcraft i3wm](https://wiki.archcraft.io/docs/window-managers/tiling-wm/i3wm)
- [Xorg](https://wiki.archlinux.org/title/Xorg)
- [ThinkWiki T410](https://www.thinkwiki.org/wiki/Category:T410)
- [Arch Forums](https://bbs.archlinux.org/)

---

## Quick command summary (live install)

```bash
# 1. Boot mode
cat /sys/firmware/efi/fw_platform_size

# 2. Wi-Fi
rfkill list && rfkill unblock wifi
iwctl → connect → exit
ping -c 3 archlinux.org

# 3. Clock
timedatectl set-ntp true

# 4. Disk
fdisk /dev/sda          # MBR: 4G swap + rest root
mkswap /dev/sda1 && swapon /dev/sda1
mkfs.ext4 /dev/sda2 && mount /dev/sda2 /mnt

# 5. Install
pacstrap -K /mnt base base-devel linux linux-firmware intel-ucode \
  iwd networkmanager nano vim sudo grub os-prober
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Chroot
arch-chroot /mnt
# timezone, locale, hostname, NetworkManager, passwd, user, grub
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
exit

# 7. Reboot
umount -R /mnt && swapoff -a && reboot

# 8. After first boot — Wi-Fi (nmtui, not iwctl)
rfkill unblock wifi && sudo nmcli radio wifi on
sudo nmtui

# 9. Post-install (verified T410 — Section 15)
sudo pacman -Syu
sudo pacman -S archcraft-fonts archcraft-dunst-icons picom bluez bluez-utils bc acpi upower light python python-gobject bash-completion fzf git
sudo fc-cache -fv
sudo systemctl enable --now bluetooth.service
~/.config/i3/scripts/i3_comp && ~/.config/i3/scripts/i3_bar
cp ~/github/linux-bash-cheatsheet/scripts/.bash_profile ~/.bash_profile && ln -sf ~/.bash_profile ~/.bashrc
```
