# Fix missing battery icon in Archcraft polybar

**Target:** Archcraft i3wm on ThinkPad T410 (Arch Linux)  
**Symptoms:** No battery / power icon in the top bar; optionally `acpi: command not found` when running `~/.config/i3/scripts/i3_bar`

Two separate causes — check **A** first if you saw *`acpi: command not found`*.

---

## A. Missing `acpi` package (most common on fresh install)

Archcraft’s **`~/.config/i3/theme/polybar/launch.sh`** runs **`acpi -b`** on the **first** bar start. If the **`acpi`** package is not installed:

1. You get **`acpi: command not found`** (or similar).
2. The script treats that as “no battery” and rewrites **`config.ini`**: `battery` → **`btna`** (empty placeholder module).
3. It creates **`~/.config/i3/theme/polybar/.module`** so this only runs once — the battery slot stays gone until you fix it.

### Fix

```bash
sudo pacman -S acpi upower light
rm -f ~/.config/i3/theme/polybar/.module ~/.config/i3/theme/.system
sed -i 's/btna/battery/g; s/ bna / backlight /g' ~/.config/i3/theme/polybar/config.ini
~/.config/i3/scripts/i3_bar
```

### Verify

```bash
acpi -b                    # e.g. Battery 0: Discharging, 87%, ...
grep modules-right ~/.config/i3/theme/polybar/config.ini   # should contain "battery", not "btna"
```

| Package | Purpose |
|---------|---------|
| **`acpi`** | CLI — `acpi -b` in `launch.sh` (battery detection on first bar start) |
| **`upower`** | Used by `polybar.sh` to auto-fill `system.ini` battery/adapter names |
| **`light`** | Backlight control — used by polybar scripts for brightness module |
| **`acpid`** | Separate ACPI **daemon** — does **not** provide the `acpi` command |

> **`acpi` ≠ `acpid`.** Installing only `acpid` does **not** provide the `acpi` command.

Install all four on a ThinkPad if you follow the full T410 guide:

```bash
sudo pacman -S acpid acpi upower light
sudo systemctl enable --now acpid.service
```

---

## B. Wrong names in `system.ini` (ThinkPad T410)

Even with `acpi` installed, Archcraft’s default **`system.ini`** values (`BAT1`, `ACAD`, `amdgpu_bl1`) often do not match a T410. Polybar’s `internal/battery` module reads `/sys/class/power_supply/` — wrong names → empty module.

### 1. List your power devices

```bash
ls -1 /sys/class/power_supply/
```

On a T410 you usually see **`BAT0`** (battery) and **`ADP0`** or **`ADP1`** (AC adapter). Archcraft defaults to **`BAT1`** / **`ACAD`**, which typically do not exist on this machine.

### 2. Confirm the kernel sees the battery

```bash
cat /sys/class/power_supply/BAT0/capacity    # e.g. 87
cat /sys/class/power_supply/BAT0/status     # Charging, Discharging, or Full
```

If `BAT0` is missing or `capacity` errors out, fix hardware/ACPI first (see **Troubleshooting** below). Polybar cannot show a battery the kernel does not expose.

### 3. Edit Archcraft system variables

```bash
nano ~/.config/i3/theme/system.ini
```

Set names to match step 1. Typical T410 values:

```ini
[system]
sys_adapter = ADP0
sys_battery = BAT0
sys_graphics_card = intel_backlight
sys_network_interface = wlan0
```

Use **`ADP1`** instead of **`ADP0`** if that is what `ls` showed. For **`sys_graphics_card`**, run `ls -1 /sys/class/backlight/` — on integrated Intel graphics it is usually **`intel_backlight`** (fixes the brightness module too; default `amdgpu_bl1` is for AMD laptops).

### 4. Reload polybar

```bash
~/.config/i3/scripts/i3_bar
```

You should see a battery icon (Font Awesome glyphs via Symbols Nerd Font) and **`NN%`** on the right side of the bar.

### Quick test

```bash
polybar -l info main 2>&1 | grep -i battery
```

If polybar logs `Battery 'BAT1' not found` (or similar), `system.ini` names are wrong.

---

## C. `module/backlight` — XCB_NAME (15) / Couldn't get data

Battery percentage works but **`i3_bar`** logs:

```text
error: module/backlight: Couldn't get data (err: XCB_NAME (15))
```

**Cause:** On Intel laptops Archcraft keeps the module name **`backlight`**, which uses **`type = internal/xbacklight`** (XRandR). That API is often broken on T410; sysfs **`intel_backlight`** works fine (same as **`light`** / Fn keys).

**Fix — use the `brightness` module instead** (already in **`modules.ini`**, reads **`/sys/class/backlight/`**):

```bash
ls -1 /sys/class/backlight/          # note name, usually intel_backlight
nano ~/.config/i3/theme/system.ini   # sys_graphics_card = intel_backlight
nano ~/.config/i3/theme/polybar/config.ini
```

In **`config.ini`**, change **`modules-right=`** — swap **`backlight`** for **`brightness`**:

```ini
; was:  ... volume dot backlight dot battery ...
modules-right = volume dot brightness dot battery dot bluetooth dot network dot LD date RD dot sysmenu
```

Reload:

```bash
~/.config/i3/scripts/i3_bar
```

The error should stop and the brightness percentage should appear next to volume.

**Alternative** — edit **`modules.ini`** **`[module/backlight]`** and change **`type = internal/xbacklight`** to **`type = internal/backlight`** with **`card = ${system.sys_graphics_card}`** (keep the name **`backlight`** in **`modules-right`**).

---

## D. AC plugged in → **0%** + charging animation (no real %)

**Symptom:** On battery, **`BAT0`** shows the correct **NN%**. Plug in the adapter → polybar switches to **charging animation** but shows **`0%`** (or the number never updates).

### Step 1 — compare kernel vs polybar (while charger is plugged in)

```bash
grep -E 'sys_battery|sys_adapter' ~/.config/i3/theme/system.ini
ls -1 /sys/class/power_supply/

cat /sys/class/power_supply/BAT0/status
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/ADP0/online    # use YOUR adapter name from ls
acpi -b
```

| What you see | Meaning |
|--------------|---------|
| **`capacity` and `acpi -b` show correct %**, polybar shows **0%** | Polybar config / animation format — **Step 2** |
| **`capacity` is 0** (or missing) while **`acpi -b`** is correct | Kernel quirk — **Step 4** (custom script) |
| **`adapter/online` fails** (wrong name) | Fix **`sys_adapter`** — must match **`ls`** exactly (**`ADP0`**, **`ADP1`**, or **`AC`** — not **`ACAD`**) |

**Important:** Names must match **`/sys/class/power_supply/`** exactly. T410 often uses **`ADP0`**, but some units show **`AC`** or **`ADP1`**.

Do **not** rely on Archcraft’s one-time **`polybar.sh`** auto-detect — it runs **`grep 'AC'`** on upower devices and can pick the wrong adapter or skip **`ADP0`**. Set **`system.ini` by hand**:

```bash
nano ~/.config/i3/theme/system.ini
```

```ini
[system]
sys_battery = BAT0
sys_adapter = ADP0
```

(Use your actual adapter name from **`ls`**.)

```bash
rm -f ~/.config/i3/theme/.system
~/.config/i3/scripts/i3_bar
```

### Step 2 — fix charging display format (most common polybar fix)

Stock Archcraft uses **`format-charging = <animation-charging> <label-charging>`**. On some ThinkPads the **animation** updates while **`%percentage%`** sticks at **0** or fails to refresh.

Edit **`~/.config/i3/theme/polybar/modules.ini`** — **`[module/battery]`**:

```ini
; was: format-charging = <animation-charging> <label-charging>
format-charging = <ramp-capacity> <label-charging>

format-charging-prefix = " "
format-charging-prefix-font = 1

label-charging = %percentage%%
label-charging-font = 0

format-charging-prefix-foreground = ${color.GREEN}
ramp-capacity-foreground = ${color.GREEN}
ramp-capacity-font = 1
```

Match discharging style (ramp + label) instead of the cycling animation. Reload:

```bash
~/.config/i3/scripts/i3_bar
```

Optional — keep the bolt prefix only if it fits your bar fonts:

```ini
format-charging-prefix = " "
format-charging-prefix-font = 1
```

### Step 3 — polling

If % lags for 1–2 seconds then fixes itself, increase polling:

```ini
poll-interval = 5
```

### Step 4 — fallback: custom module using `acpi` (if sysfs `capacity` lies)

If **`acpi -b`** is always right but polybar **`internal/battery`** is wrong, add a script module.

**`~/.config/i3/scripts/polybar-battery.sh`:**

```bash
#!/usr/bin/env bash
# Prints: icon-ish prefix + percentage from acpi (works when sysfs lies)

read -r line < <(acpi -b 2>/dev/null | head -1)
pct=$(sed -n 's/.*, \([0-9]*\)%.*/\1/p' <<< "$line")

if grep -qi charging <<< "$line"; then
  echo "CHG ${pct}%"
elif grep -qi 'fully-charged\|Full' <<< "$line"; then
  echo "FULL ${pct}%"
else
  echo "${pct}%"
fi
```

```bash
chmod +x ~/.config/i3/scripts/polybar-battery.sh
```

**`modules.ini`:**

```ini
[module/battery-acpi]
type = custom/script
exec = ~/.config/i3/scripts/polybar-battery.sh
interval = 2
format = <label>
format-background = ${color.ALTBACKGROUND}
label = %output%
label-font = 0
```

**`config.ini`** — replace **`battery`** with **`battery-acpi`** in **`modules-right=`**.

### ThinkPad charge threshold (optional)

If you enabled **charge threshold** in BIOS or **`tp-smapi`/`thinkpad_acpi`**, status may read **`Unknown`** while plugged in — polybar can mis-label state. Check:

```bash
cat /sys/class/power_supply/BAT0/status
```

If **`Not charging`** at high % with AC connected, that is normal (battery preservation) — use **Step 2** so it does not look like a broken **0%** charge.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `acpi: command not found` when running `i3_bar` | Section **A** above |
| No battery icon (other bar icons OK) | Section **A**, then **B** |
| `BAT0` missing from `/sys/class/power_supply/` | Check battery seated; `dmesg \| grep -i battery`; try `linux-lts` kernel — [Arch forum T410 battery thread](https://bbs.archlinux.org/viewtopic.php?id=241180) |
| Gibberish icons instead of battery/Wi‑Fi glyphs | Install **`archcraft-fonts`**; `fc-cache -fv`; restart `i3_bar` |
| `module/backlight` XCB_NAME (15) | Section **C** — use **`brightness`** module or **`internal/backlight`** |
| AC plugged → **0%** + charging animation | Section **D** — fix **`sys_adapter`**, change **`format-charging`** to **`<ramp-capacity> <label-charging>`**, or use **`acpi`** script module |

**Related:** full T410 install guide — [arch-t410-install-guide.md](./arch-t410-install-guide.md) (Section 15.10 for menu icon fonts).
