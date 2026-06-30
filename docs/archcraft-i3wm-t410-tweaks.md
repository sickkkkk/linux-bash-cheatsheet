# Archcraft i3wm — T410 fixes (power menu, brightness, polybar)

**Target:** ThinkPad T410 · Archcraft i3wm · bare i3 (no full DE)

---

## 1. Super+X power menu — lock / suspend do nothing

Archcraft’s **`~/.config/i3/scripts/rofi_powermenu`** expects tools that are **not** installed by `archcraft-i3wm`:

| Action | Script runs | Usually missing |
|--------|-------------|-----------------|
| **Lock** | `betterlockscreen --lock` | `betterlockscreen` (and first-time wallpaper setup) |
| **Suspend** | `mpc -q pause` **&&** `pulsemixer --mute` **&&** `betterlockscreen --suspend` | `mpc` / running **mpd**, `pulsemixer`, `betterlockscreen` |

Because suspend uses **`&&`**, if **`mpc`** fails (not installed or mpd not running), **suspend never runs** even after you confirm. That feels like “weird” broken buttons.

Logout / reboot / shutdown use **`systemctl`** and usually work.

### Fix A — minimal packages + simpler suspend (recommended)

```bash
sudo pacman -S i3lock pulsemixer
```

Edit the power menu script:

```bash
nano ~/.config/i3/scripts/rofi_powermenu
```

Find **`run_cmd()`** and change **lock** and **suspend** to:

```bash
run_cmd() {
	if [[ "$1" == '--opt1' ]]; then
		i3lock -c 000000
	elif [[ "$1" == '--opt2' ]]; then
		confirm_run 'i3-msg exit'
	elif [[ "$1" == '--opt3' ]]; then
		confirm_run 'systemctl suspend'
	elif [[ "$1" == '--opt4' ]]; then
		confirm_run 'systemctl hibernate'
	elif [[ "$1" == '--opt5' ]]; then
		confirm_run 'systemctl reboot'
	elif [[ "$1" == '--opt6' ]]; then
		confirm_run 'systemctl poweroff'
	fi
}
```

Test:

```bash
~/.config/i3/scripts/rofi_powermenu
# Lock → screen should go black until you type password
# Suspend → confirm → laptop sleeps (power LED blinks)
```

If **`systemctl suspend`** asks for a password, your user needs logind session rights (normal on LightDM login). Try from a terminal: `systemctl suspend`.

### Fix B — keep Archcraft’s betterlockscreen look

```bash
sudo pacman -S betterlockscreen pulsemixer
betterlockscreen -u /path/to/wallpaper.jpg   # once; use any image you have
```

Still change **suspend** in `rofi_powermenu` to **`confirm_run 'systemctl suspend'`** unless you run **mpd** and want music paused first.

### Optional — Alt+Ctrl+L lock binding

Keybindings already include **`Alt+Control+l`** → `betterlockscreen --lock`. After Fix A, change that line in **`~/.config/i3/config.d/02_keybindings.conf`** to:

```text
bindsym $ALT+Control+l exec --no-startup-id i3lock -c 000000
```

Then **`Super+Shift+c`** to reload i3.

---

## 2. Fn+Home / Fn+End — brightness keys

**Symptom:** `light -A 5` / `light -U 5` in a terminal **works**, but **Fn+Home / Fn+End do nothing**.

**Cause:** i3 binds those keys to **`~/.config/i3/scripts/i3_brightness`**. On **`intel_backlight`** (T410), that script calls **`xbacklight`**, which is broken on current Arch. The script uses **`xbacklight … && notify_bl`**, so when `xbacklight` fails, brightness never changes and you often get no error.

### Quick confirm

```bash
~/.config/i3/scripts/i3_brightness --inc    # likely fails or no change
light -A 5                                 # works
```

### Fix A — patch the script (recommended)

```bash
nano ~/.config/i3/scripts/i3_brightness
```

Replace **`get_backlight`**, **`inc_backlight`**, and **`dec_backlight`** with:

```bash
get_backlight() {
	echo "$(light -G | cut -d. -f1)%"
}

inc_backlight() {
	light -A 5
	notify_bl
}

dec_backlight() {
	light -U 5
	notify_bl
}
```

Use **`;`** before **`notify_bl`** (not **`&&`**) so a dunst/icon glitch does not block brightness.

Reload i3: **Super+Shift+c**. Test Fn keys.

### Fix B — bypass the script in i3 (fastest)

```bash
nano ~/.config/i3/config.d/02_keybindings.conf
```

Replace the brightness lines with:

```text
bindsym XF86MonBrightnessUp   exec --no-startup-id light -A 5
bindsym XF86MonBrightnessDown exec --no-startup-id light -U 5
```

**Super+Shift+c** to reload.

### Step 1 — if keys still do nothing: confirm keys reach i3

```bash
xev
```

Press **Fn+Home** and **Fn+End**. Note whether you see **`XF86MonBrightnessUp`** / **`XF86MonBrightnessDown`**.

- **No events** → firmware/kernel (see Step 4).
- **Events appear** → apply **Fix A** or **Fix B** above (you likely still have the stock **`xbacklight`** branch).

### Step 2 — permissions (only if `light` fails in terminal)

```bash
sudo usermod -aG video "$USER"
# log out and back in
```

### Step 3 — alternative: `brightnessctl`

```bash
sudo pacman -S brightnessctl
sudo usermod -aG video "$USER"
```

In **`~/.config/i3/config.d/02_keybindings.conf`**, override the brightness binds:

```text
bindsym XF86MonBrightnessUp   exec --no-startup-id brightnessctl -e intel_backlight -n 2 set +5%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl -e intel_backlight -n 2 set 5%-
```

Use the name from **`ls /sys/class/backlight/`** (often **`intel_backlight`** on T410 with integrated graphics).

### Step 4 — still no key events or no physical change

Check backlight device:

```bash
ls -1 /sys/class/backlight/
cat /sys/class/backlight/intel_backlight/max_brightness
echo 4000 | sudo tee /sys/class/backlight/intel_backlight/brightness
```

If **`echo`** changes the screen but keys do not, it is a keybinding/script issue (Steps 2–3).

If **`intel_backlight`** is missing or **`echo`** does nothing, try kernel cmdline in **`/etc/default/grub`**:

```text
GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=video thinkpad-acpi.brightness_enable=1"
```

Then:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
reboot
```

**NVIDIA discrete BIOS:** brightness in X is notoriously broken on T410 with the NVS chip; use **BIOS → Integrated** graphics for sane backlight, or adjust brightness from a VT and accept limitations ([ThinkWiki T410/T510](https://www.thinkwiki.org/wiki/Category:T410)).

---

## 3. Polybar text overlaps oval “pills” (workspaces, date/time)

The **`LD`** / **`RD`** modules draw the curved ends (`` `` via **font-3**). Content between them (**`i3`**, **`date`**, **`tray`**) uses **`format-background`**. If inner text/icons are **taller** than the brackets, they **bleed over the ovals** — common on the **workspace switcher** and **clock**.

Bar **`height = 26`** is tight for Archcraft’s default fonts (**font-2** size 20 clock icon, **font-4** date label, large Nerd icons on workspaces).

### Fix — align heights (do all of 1–3)

**1. `config.ini`** — bar height + global fonts:

```bash
nano ~/.config/i3/theme/polybar/config.ini
```

```ini
height = 28

font-0 = "JetBrains Mono:bold:size=10;2"
font-1 = "Symbols Nerd Font:size=11;2"
font-2 = "Symbols Nerd Font:size=12;2"
font-3 = "Iosevka Nerd Font:bold:size=11;2"
font-4 = "archcraft:size=10;2"
```

The trailing **`;2`** is vertical offset — keeps glyphs centered in the bar. Match **font-3** (brackets) to the size of icons/text inside pills.

**2. `modules.ini`** — **date** pill (`[module/date]`):

```ini
format-prefix-font = 1
label-font = 0
format-padding = 1
label-padding = 1
```

Optional shorter time (less horizontal overflow): `time = %H:%M` instead of `%I:%M %p`.

**3. `modules.ini`** — **workspace** pill (`[module/i3]`):

Add (or adjust) after the existing `label-*-padding` lines:

```ini
label-focused-font = 1
label-unfocused-font = 1
label-visible-font = 1
label-urgent-font = 1

label-focused-padding = 2
label-unfocused-padding = 2
label-visible-padding = 2
label-urgent-padding = 2

format-padding = 1
```

Workspace icons (`ws-icon-*`) are Nerd Font glyphs — **font-1** at size 11 aligns them with the **`LD`/`RD`** caps better than the default **font-0**.

If **`label-mode`** (i3 mode text like “resize”) makes the pill too tall when it appears, hide it:

```ini
; label-mode = %mode%
label-mode =
```

**4. Reload**

```bash
~/.config/i3/scripts/i3_bar
```

### If it still overlaps

- Bump **`height = 30`** one step at a time.
- Lower **`font-3`** to **`size=10;2`** (brackets) without shrinking workspace icons further.
- **Tray** pill (`LD tray RD`): same idea — if tray icons overlap, they’re often oversized; reduce **`tray-size`** in **`[module/tray]`** (default **65%** → try **55%**).

### Optional — drop the oval wrappers

If tuning fonts is fiddly, remove **`LD`** / **`RD`** around the worst offender only:

```ini
; was: modules-left = menu dot LD i3 RD dot LD tray RD ...
modules-left = menu dot i3 dot tray
; was: ... network dot LD date RD dot sysmenu
modules-right = volume dot brightness dot battery dot bluetooth dot network dot date dot sysmenu
```

You lose the curved ends but get a flat pill (`format-background` only) with no overlap.

---

## 3b. Polybar text too big (Offline / network pill)

```bash
nano ~/.config/i3/theme/polybar/config.ini
```

Change the **`font-*`** lines near the top of **`[bar/main]`**:

```ini
font-0 = "JetBrains Mono:bold:size=10;3"
font-1 = "Symbols Nerd Font:size=11;3"
font-2 = "Symbols Nerd Font:size=13;3"
font-3 = "Iosevka Nerd Font:bold:size=10;3"
font-4 = "archcraft:size=10;3"
```

Then edit modules:

```bash
nano ~/.config/i3/theme/polybar/modules.ini
```

**Date module** — find **`[module/date]`** and change:

```ini
format-prefix-font = 1
label-font = 0
```

(was **`format-prefix-font = 2`** and **`label-font = 4`**)

**Network disconnected** — find **`[module/network]`** and add or change:

```ini
format-disconnected-prefix-font = 1
label-disconnected-font = 0
```

Reload the bar:

```bash
~/.config/i3/scripts/i3_bar
```

If **Offline** or the clock still clip, lower **`font-2`** to **size=11** in **`config.ini`** or shorten the label in **`modules.ini`**:

```ini
label-disconnected = "%{A1:~/.config/i3/scripts/network_menu &:}off%{A}"
```

---

## 4. Polybar `module/mpd` / `module/song` — connection refused

Polybar’s left side includes **`mpd`** (play/pause/prev/next buttons) and **`song`** (now playing text). Both are **`type = internal/mpd`** and connect to **MPD** on **`127.0.0.1:6600`** every **2 seconds**.

If **MPD is not installed or not running**, polybar logs **`connection refused`** over and over (often visible in **`~/.config/i3/scripts/i3_bar`** output or **`polybar -l info`**).

Archcraft also uses **`mpc`** for media keys (**XF86AudioPlay**, etc.) and in the power-menu suspend chain — same dependency.

Pick **one** path:

### Option A — you do not use MPD (simplest; stops the errors)

Remove the modules from the bar:

```bash
nano ~/.config/i3/theme/polybar/config.ini
```

Find **`modules-left=`** and delete **`mpd`**, **`sep`**, and **`song`**. Example:

```ini
; was:
; modules-left = menu dot LD i3 RD dot LD tray RD dot LD mpd RD sep song

modules-left = menu dot LD i3 RD dot LD tray RD
```

Reload:

```bash
~/.config/i3/scripts/i3_bar
```

Errors should stop immediately. Media keys (**XF86Audio\***) will do nothing until you install MPD or rebind them to something else.

### Option B — run MPD (keep the bar widgets)

**1. Install and create config:**

```bash
sudo pacman -S mpd mpc
mkdir -p ~/.config/mpd/playlists ~/Music
```

**2. Minimal user config** — **`~/.config/mpd/mpd.conf`**:

```ini
music_directory     "~/Music"
playlist_directory  "~/.config/mpd/playlists"
db_file             "~/.config/mpd/database"
log_file            "syslog"
pid_file            "~/.config/mpd/pid"
state_file          "~/.config/mpd/state"
sticker_database    "~/.config/mpd/sticker.sql"

bind_to_address     "127.0.0.1"
port                "6600"

audio_output {
    type    "pulse"
    name    "PulseAudio Output"
}
```

Pipewire’s **`pipewire-pulse`** presents a Pulse-compatible sink — this works with your existing Archcraft audio stack.

**3. Enable user service** (after login, not as root):

```bash
systemctl --user enable --now mpd.service
mpc status
```

Expected: **`volume:`** line and state **`stop`** or **`play`** — not *connection refused*.

**4. Reload polybar:**

```bash
~/.config/i3/scripts/i3_bar
```

**5. Test playback:**

```bash
mpc update
mpc play
# or add files under ~/Music first, then mpc update && mpc play
```

**If `systemctl --user` fails** (“no bus”): you must be in a full user session (log in via LightDM, not only SSH). Run **`loginctl show-session $XDG_SESSION_ID -p Type`** — should include **`x11`**.

**Optional — terminal UI:** Archcraft’s music keybinding expects **`ncmpcpp`** + extra scripts; not required for polybar MPD widgets. Plain **`mpc`** is enough for the bar.

---

## 5. Optional polybar modules (CPU temp, load, RAM, disk)

Archcraft **`modules.ini`** already defines modules that are **not** on the bar by default. You only need to **enable** them in **`config.ini`** and tune **`modules.ini`** if needed.

| Module | Shows | Already in `modules.ini` |
|--------|--------|---------------------------|
| **`temperature`** | CPU (or zone) temp °C | Yes |
| **`cpu`** | CPU load % | Yes |
| **`memory`** | RAM used % | Yes |
| **`filesystem`** | `/` disk use | Yes |
| **`spotify`** | Spotify track (script) | Yes — needs Spotify + script deps |
| **`ethernet`** | Wired link (replaces **`network`** on eth) | Yes |

### CPU temperature (what you want)

**1. Find the sensor on the T410** (logged in, i3 session):

```bash
for i in /sys/class/thermal/thermal_zone*; do echo "$i: $(cat $i/type 2>/dev/null)"; done
```

On Intel T410 you usually want **`x86_pkg_temp`** (CPU package). ThinkPad may also list **`acpitz`**, **`thinkpad`** — those are board/ACPI, not ideal for “CPU hot”.

Optional — stable hwmon path:

```bash
for i in /sys/class/hwmon/hwmon*/temp*_input; do
  echo "$(cat $(dirname $i)/name 2>/dev/null): $(readlink -f $i)"
done | grep -i core
```

**2. Point the module at the right sensor** — **`~/.config/i3/theme/polybar/modules.ini`**, **`[module/temperature]`**:

```ini
zone-type = x86_pkg_temp
; or, if zone-type fails on your polybar version:
; thermal-zone = 0

warn-temperature = 85
format-prefix-font = 1
ramp-font = 1
label-font = 0
```

(`warn-temperature = 60` in the stock config turns red too early — **85** is saner for a laptop CPU.)

**3. Add to the bar** — **`~/.config/i3/theme/polybar/config.ini`**:

```ini
modules-right = volume dot brightness dot battery dot temperature dot cpu dot memory dot bluetooth dot network dot LD date RD dot sysmenu
```

Or grouped in a pill (match your font tweaks from §3):

```ini
modules-right = volume dot brightness dot battery dot LD temperature cpu memory RD dot bluetooth dot network dot LD date RD dot sysmenu
```

**4. Reload**

```bash
~/.config/i3/scripts/i3_bar
```

Test read without polybar:

```bash
cat /sys/class/thermal/thermal_zone*/type
# find zone N where type is x86_pkg_temp, then:
cat /sys/class/thermal/thermal_zoneN/temp   # millidegrees — divide by 1000
```

If the module shows **`N/A`** or errors: install **`lm_sensors`** and run **`sudo sensors-detect`** once (accept defaults) — usually **`coretemp`** is already active on T410 without that.

### CPU load + RAM (same pattern)

Already styled in **`modules.ini`**. Add **`cpu`** and **`memory`** to **`modules-right=`** (see above).

Optional — shrink icons so they fit the bar (§3):

```ini
[module/cpu]
format-prefix-font = 1
label-font = 0

[module/memory]
format-prefix-font = 1
label-font = 0
```

### Disk usage

```ini
modules-right = ... filesystem dot ...
```

**`[module/filesystem]`** defaults to **`mount-0 = /`**. On a 4 GB T410, watching **`/`** free space is useful.

### Packages

No extra pacman packages required for **`internal/temperature`** / **`cpu`** / **`memory`** / **`fs`** — polybar reads **`/sys`**. Optional: **`lm_sensors`** for **`sensors`** in a terminal.

---

## Quick package list

```bash
sudo pacman -S i3lock pulsemixer light brightnessctl
sudo usermod -aG video "$USER"
# only if you want MPD in the bar / media keys:
# sudo pacman -S mpd mpc
```

Then apply script/config edits above and **log out / back in** once.

**See also:** [arch-t410-install-guide.md](./arch-t410-install-guide.md) · [archcraft-polybar-battery.md](./archcraft-polybar-battery.md)
