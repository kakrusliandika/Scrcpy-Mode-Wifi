# 📶 Scrcpy Mode over Wi‑Fi — ADB Wi‑Fi Toolbox
[![OS](https://img.shields.io/badge/OS-Windows%20%7C%20macOS%20%7C%20Linux-4c1)](#-requirements--kebutuhan)
[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB)](#-requirements--kebutuhan)
[![ADB](https://img.shields.io/badge/Requires-adb-important)](#-requirements--kebutuhan)
[![Scrcpy](https://img.shields.io/badge/Optional-scrcpy-informational)](#-requirements--kebutuhan)
[![Languages](https://img.shields.io/badge/UI-English%20%2B%20Bahasa%20Indonesia-ff69b4)](#-entrypoints--titik-masuk)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#-license--lisensi)

A cross‑platform toolbox to **enable ADB over Wi‑Fi**, **connect** to your Android devices, and **launch scrcpy** with handy **quality presets & extras**.  
It keeps **JSON inventories** of your devices and connections and performs **smart de‑duplication**.

> **Bilingual / Dwibahasa** — This README provides **English** first, followed by **Bahasa Indonesia**. The scripts’ UIs are available in **English** (`wifi_adb.bat`) and **Bahasa Indonesia** (`wifi_adb_id.bat`).

---

## 🧭 TL;DR — Quick Start (EN)

```bash
# 1) Clone
git clone https://github.com/kakrusliandika/Scrcpy-Mode-Wifi
cd Scrcpy-Mode-Wifi

# 2) Ensure adb (required) & scrcpy (optional) are installed and on PATH
# macOS   : brew install android-platform-tools scrcpy
# Windows : Install Platform Tools + scrcpy, add both to PATH
# Linux   : sudo apt install android-tools-adb scrcpy    # Debian/Ubuntu

# 3) Run the toolbox (pick one)
# Cross-platform (Python):
python3 wifi_adb.py        # macOS/Linux
# or
python wifi_adb.py         # Windows

# Windows (Batch - English UI):
wifi_adb.bat

# Windows (Batch - Indonesian UI):
wifi_adb_id.bat
```

---

## 🔀 Entrypoints — Titik Masuk

- 🐍 **`wifi_adb.py`** — Cross‑platform CLI (Windows/macOS/Linux).  
- 🪟 **`wifi_adb.bat`** — Windows batch, **English UI**.  
- 🪟 **`wifi_adb_id.bat`** — Windows batch, **Bahasa Indonesia UI**.  
  > Commands are identical across languages: `setup`, `connect`, `list`, `usb-back`, `disconnect`, `pair`, `help`. Only the UI strings differ.

---

## ✨ Features — Fitur Utama

- 🔧 **Setup**: Enable **ADB over Wi‑Fi** for all USB‑connected devices.
- 🔗 **Connect**: Pick from the known list or enter an IP; **launch scrcpy** with **presets** + **extras**.
- 📋 **List**: Merge and display devices from both JSON files **with live ADB status**.
- 🔌 **USB‑Back**: Switch **all TCP** devices back to USB mode.
- 🧹 **Disconnect All**: `adb disconnect` all TCP endpoints.
- 🔐 **Pair**: Wireless debugging pairing (Android 11+).
- 🗂️ **Stateful JSON**:
  - `wifi_device_setup.json` — devices from Setup (**de‑dup by IP**).
  - `wifi_device_connect.json` — connection history (**skip if device+model exists**).
- ⚙️ **Custom ADB TCP Port**: choose a non‑default port (not only `5555`) during **Setup** and **Connect**.
- 🧠 **Robust JSON handling** (single object, array, or NDJSON).
- 🖥️ **Cross‑platform** Python + Windows batch.

---

## 📦 Requirements — Kebutuhan

- **Python 3.8+** *(for the Python entrypoint)*  
- **ADB** on PATH *(required)*  
- **scrcpy** on PATH *(optional for mirroring)*  
- Android with **USB debugging** enabled; for Wi‑Fi:
  - classic `adb tcpip <port>` *(Android ≤ 10)*, or
  - **Wireless debugging** *(Android 11+)* with `adb pair <ip:port>`

### Install ADB & scrcpy

- **macOS (Homebrew)**  
  ```bash
  brew install android-platform-tools scrcpy
  ```
- **Windows**
  - Install **Android SDK Platform‑Tools** (Google), add to **PATH**  
  - Install **scrcpy** (e.g., via Chocolatey/Scoop/MSI), add to **PATH**
- **Linux (Debian/Ubuntu)**  
  ```bash
  sudo apt update
  sudo apt install android-tools-adb scrcpy
  ```
- Official scrcpy repository: https://github.com/Genymobile/scrcpy

---

## 🗺️ Project Structure — Struktur Proyek

```
Scrcpy-Mode-Wifi/
├─ wifi_adb.py                   # Cross-platform Python toolbox (menu + subcommands)
├─ wifi_adb.bat                  # Windows batch (English UI)
├─ wifi_adb_id.bat               # Windows batch (Bahasa Indonesia UI)
├─ wifi_device_setup.json        # Generated: setup inventory (de-dup by IP)
├─ wifi_device_connect.json      # Generated: connection history (skip if device+model exists)
├─ README.md
└─ LICENSE
```
![scrcpy-image](https://github.com/user-attachments/assets/386f8699-2a14-434c-8fc8-ce3746aae634)

---

## 🚀 Usage — Penggunaan

### A) Cross‑platform (Python)

Interactive menu:
```bash
python3 wifi_adb.py            # macOS/Linux
python  wifi_adb.py            # Windows
```

Subcommands:
```bash
python3 wifi_adb.py setup
python3 wifi_adb.py connect
python3 wifi_adb.py list
python3 wifi_adb.py usb-back
python3 wifi_adb.py disconnect
python3 wifi_adb.py pair
```

### B) Windows (Batch — English UI)

Interactive:
```bat
wifi_adb.bat
```

Subcommands:
```bat
wifi_adb.bat setup
wifi_adb.bat connect
wifi_adb.bat list
wifi_adb.bat usb-back
wifi_adb.bat disconnect
wifi_adb.bat pair
```

### C) Windows (Batch — Bahasa Indonesia UI)

Interaktif:
```bat
wifi_adb_id.bat
```

Sub‑command:
```bat
wifi_adb_id.bat setup
wifi_adb_id.bat connect
wifi_adb_id.bat list
wifi_adb_id.bat usb-back
wifi_adb_id.bat disconnect
wifi_adb_id.bat pair
```

> 💡 **ANSI colors in Command Prompt** — Batch scripts use ANSI escapes. On most Windows 10/11 systems it “just works”. If not, try running CMD as **Administrator** and:
> ```bat
> REG ADD HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
> ```
> then restart CMD.

---

## 🎛️ scrcpy Presets & Extras

**Presets (bit‑rate + size):**

| No | Name        | Options                                  |
|----|-------------|-------------------------------------------|
| 1  | Low         | `--video-bit-rate 2M --max-size 800`      |
| 2  | Default     | `--video-bit-rate 8M --max-size 1080`     |
| 3  | High        | `--video-bit-rate 16M --max-size 1440`    |
| 4  | Very High   | `--video-bit-rate 24M --max-size 1440`    |
| 5  | Ultra       | `--video-bit-rate 32M --max-size 2160`    |
| 6  | Extreme     | `--video-bit-rate 64M --max-size 2160`    |
| 7  | Insane      | `--video-bit-rate 72M --max-size 2160`    |

**Extras (Y/N prompts):**
- `--always-on-top`
- `--window-borderless`
- `--fullscreen`
- `--no-audio`
- `-S` / `--turn-screen-off`
- `--video-codec=h265`
- `--max-fps 60`
- `--window-title "<title>"`
- `--window-x <x> --window-y <y> --window-width <w> --window-height <h>`
- `--record <file.mp4>`

> ℹ️ The tool auto‑adds `--stay-awake` if your device/ROM allows toggling `stay_on_while_plugged_in`.

---

## 🧾 JSON Files & De‑dup Logic

- **`wifi_device_setup.json`** — created/updated by **Setup**, treats **IP** as the unique key. If the same IP appears again, the entry is **replaced** (no duplicates).  
- **`wifi_device_connect.json`** — updated by **Connect**, **skips** adding when a row with the **same** `"device"` **and** `"model"` already exists.

Example:
```json
[
  {
    "timestamp": "Mon 10/13/2025 16:45:28.54",
    "serial": "192.168.43.1:5555",
    "brand": "OPPO",
    "model": "CPH2015",
    "device": "OP4C7D",
    "android": "9",
    "sdk": "28",
    "resolution": "720x1600",
    "dpi": "320",
    "battery": "300",
    "ssid": null,
    "ip": "192.168.43.1",
    "endpoint": "192.168.43.1:5555"
  }
]
```

---

## 🧪 Typical Flows — Alur Umum

**First‑time via USB → Wi‑Fi + Mirror**
1. Enable **USB debugging**, connect via USB.
2. Run:  
   ```bash
   python3 wifi_adb.py setup
   python3 wifi_adb.py connect
   ```
   or on Windows:  
   ```bat
   wifi_adb.bat setup
   wifi_adb.bat connect
   ```
3. Pick a preset → scrcpy starts 🎉

**Wireless Debugging (Android 11+)**
```bash
python3 wifi_adb.py pair
python3 wifi_adb.py connect
```
*(Windows batch: use `wifi_adb.bat` or `wifi_adb_id.bat` with the same subcommands.)*

---

## 🛠️ Troubleshooting — Pemecahan Masalah

- ❌ **`adb` not found** — install Platform Tools and add to **PATH**.  
- 📶 **Device not detected (USB)** — enable **USB debugging**, use a reliable cable/port, accept the RSA prompt.  
- 🌐 **Cannot connect over Wi‑Fi** — ensure same **SSID**, verify IP, check firewall.  
- 🔁 **Duplicate IP** — you’ll be warned; prefer a single SSID/hotspot so each device gets a unique IP.  
- 💤 **`--stay-awake` missing** — your ROM may block that global setting; the tool continues without it.  

---

## 🤝 Contributing

PRs and issues are welcome. Keep changes **cross‑platform**, avoid heavy dependencies, and preserve **both batch scripts** (EN & ID).

---

## 📜 License — Lisensi

**MIT License** — see `LICENSE`.

---

## 🔗 Clone

```bash
git clone https://github.com/kakrusliandika/Scrcpy-Mode-Wifi
cd Scrcpy-Mode-Wifi
```

---

### References
- scrcpy (official): https://github.com/Genymobile/scrcpy  
- ADB overview & wireless debugging: https://developer.android.com/tools/adb  
- SDK Platform‑Tools: https://developer.android.com/tools/releases/platform-tools  
- Homebrew formula (scrcpy): https://formulae.brew.sh/formula/scrcpy
