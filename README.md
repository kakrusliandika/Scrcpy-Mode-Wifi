# 📶 Scrcpy Mode over Wi‑Fi — ADB Wi‑Fi Toolbox

[![OS](https://img.shields.io/badge/OS-Windows%20%7C%20macOS%20%7C%20Linux-4c1)](#-requirements)
[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB)](#-requirements)
[![ADB](https://img.shields.io/badge/Requires-adb-important)](#-requirements)
[![Scrcpy](https://img.shields.io/badge/Optional-scrcpy-informational)](#-requirements)
[![Languages](https://img.shields.io/badge/UI-English%20%7C%20Bahasa%20Indonesia-ff69b4)](#-entrypoints)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#-license)

A cross-platform toolbox to **enable ADB over Wi‑Fi**, **connect** to your Android devices, and **launch scrcpy** with handy **quality presets & extras**.  
It keeps **JSON inventories** of your devices and connections and performs **smart de‑duplication**.

---

## 🧭 TL;DR (Quick Start)

```bash
# 1) Clone
git clone https://github.com/kakrusliandika/Scrcpy-Mode-Wifi
cd Scrcpy-Mode-Wifi

# 2) Ensure adb (required) & scrcpy (optional) are installed and on PATH
# macOS   : brew install android-platform-tools scrcpy
# Windows : Install Platform Tools + scrcpy, add both to PATH
# Linux   : sudo apt install android-tools-adb scrcpy    # Debian/Ubuntu

# 3) Run toolbox (pick one of the entrypoints below)
# Cross-platform (Python):
python3 wifi_adb.py        # macOS/Linux
# or
python wifi_adb.py         # Windows

# Windows (Batch - English UI):
wifi_adb.bat

# Windows (Batch - Indonesian UI):
wifi_adb_indonesia.bat
```

---

## 🔀 Entrypoints

- 🐍 **`wifi_adb.py`** — Cross-platform CLI (Windows/macOS/Linux).  
- 🪟 **`wifi_adb.bat`** — Windows batch, **English UI**.  
- 🪟 **`wifi_adb_indonesia.bat`** — Windows batch, **Bahasa Indonesia UI**.  
  > Semua perintah (subcommand) tetap sama: `setup`, `connect`, `list`, `usb-back`, `disconnect`, `pair`, `help`.  
  > Yang berbeda hanya bahasa antarmukanya.

---

## ✨ Features

- 🔧 **Setup**: Enable **ADB over Wi‑Fi** for all USB-connected devices.
- 🔗 **Connect**: Pick a device from your known list or enter an IP; **launch scrcpy** with **presets** + **extras**.
- 📋 **List**: Merge and display devices from both JSON files **with live ADB status**.
- 🔌 **USB-Back**: Switch **all TCP** devices back to USB mode.
- 🧹 **Disconnect All**: `adb disconnect` all TCP endpoints.
- 🔐 **Pair**: Wireless debugging pairing (Android 11+).
- 🗂️ **Stateful JSON**:
  - `wifi_device_setup.json` — devices from Setup (**de-dup by IP**).
  - `wifi_device_connect.json` — connection history (**skip if device+model exists**).
- 🧠 **Robust JSON handling** (single object, array, or NDJSON).
- 🖥️ **Cross-platform**: same Python code on Windows/macOS/Linux; batch files for Windows users.

---

## 📦 Requirements

- **Python 3.8+** (only for the Python entrypoint)
- **ADB** in PATH (required)
- **scrcpy** in PATH (optional for mirroring)
- Android with **USB debugging** enabled; for Wi‑Fi:
  - classic `adb tcpip 5555` (Android ≤10), or
  - **Wireless debugging** pair-mode (Android 11+)

### Install ADB & scrcpy

- **macOS (Homebrew)**  
  ```bash
  brew install android-platform-tools scrcpy
  ```
- **Windows**
  - Install **Android Platform Tools** (Google) → add folder to **PATH**
  - Install **scrcpy** (Chocolatey/Scoop/MSI) → add to **PATH** 
- **Linux (Debian/Ubuntu)**  
  ```bash
  sudo apt update
  sudo apt install android-tools-adb scrcpy
  ```
- or Visit **[https://github.com/Genymobile/scrcpy](https://github.com/Genymobile/scrcpy)**

---

## 🗺️ Project Structure

```
Scrcpy-Mode-Wifi/
├─ wifi_adb.py                   # Cross-platform Python toolbox (menu + subcommands)
├─ wifi_adb.bat                  # Windows batch (English UI)
├─ wifi_adb_indonesia.bat        # Windows batch (Bahasa Indonesia UI)
├─ wifi_device_setup.json        # Generated: setup inventory (de-dup by IP)
├─ wifi_device_connect.json      # Generated: connection history (skip if device+model exists)
├─ README.md
└─ LICENSE
```

---

## 🚀 Usage

### A) Cross-platform (Python)

Interactive menu:

```bash
python3 wifi_adb.py            # macOS/Linux
python wifi_adb.py             # Windows
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
wifi_adb_indonesia.bat
```

Sub-command:

```bat
wifi_adb_indonesia.bat setup
wifi_adb_indonesia.bat connect
wifi_adb_indonesia.bat list
wifi_adb_indonesia.bat usb-back
wifi_adb_indonesia.bat disconnect
wifi_adb_indonesia.bat pair
```

> 💡 **Warna ANSI di Command Prompt**  
> Script `.bat` memakai escape ANSI. Umumnya bekerja langsung di Windows 10/11.  
> Jika warna tidak muncul, coba jalankan Command Prompt sebagai **Administrator** dan:
> ```bat
> REG ADD HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
> ```
> lalu tutup & buka kembali CMD.

---

## 🎛️ scrcpy Presets & Extras

**Presets (bit-rate + size):**

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

> ℹ️ The tool auto-adds `--stay-awake` if your device/ROM allows toggling `stay_on_while_plugged_in`.

---

## 🧾 JSON Files & De-dup Logic

- **`wifi_device_setup.json`** — created/updated by **Setup**, treats **IP** as the unique key.  
  If the same IP is seen again, the entry is **replaced** (not duplicated).

- **`wifi_device_connect.json`** — updated by **Connect**, **skips** adding when a row with the **same** `"device"` **and** `"model"` already exists.

Example (shortened):

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

## 🧪 Typical Flows

**First-time via USB → Wi‑Fi + Mirror**
1. Enable **USB debugging** on phone, plug in USB.
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
(Windows batch: replace the Python commands with `wifi_adb.bat` or `wifi_adb_indonesia.bat`.)

---

## 🛠️ Troubleshooting

- ❌ **`adb` not found** — install Platform Tools and add to **PATH**.
- 📶 **Device not detected (USB)** — enable **USB debugging**, use a solid cable/port, accept RSA prompt.
- 🌐 **Cannot connect over Wi‑Fi** — ensure same **SSID**, verify IP, check firewall.
- 🔁 **Duplicate IP** — you’ll be warned; prefer one SSID/hotspot so each device gets a unique IP.
- 💤 **`--stay-awake` missing** — your ROM may block that global setting; the tool continues without it.

---

## 🧰 Command Icons Cheat-Sheet

- 🔧 `setup` — Enable ADB over Wi‑Fi (USB) → save to `wifi_device_setup.json`  
- 🔗 `connect` — Pick device/IP → scrcpy presets + extras  
- 📋 `list` — Merge JSONs + live `adb get-state`  
- 🔌 `usb-back` — Return all TCP devices to USB mode  
- 🧹 `disconnect` — Disconnect all ADB TCP endpoints  
- 🔐 `pair` — Wireless debugging pairing (Android 11+)

---

## 🤝 Contributing

Pull requests and issues are welcome.  
Keep changes **cross-platform**, avoid heavy dependencies, and preserve **both batch scripts**.

---

## 📜 License

**MIT License** — see `LICENSE`.

---

## 🔗 Clone

```bash
git clone https://github.com/kakrusliandika/Scrcpy-Mode-Wifi
cd Scrcpy-Mode-Wifi
```

---

Happy mirroring! 💻➡️📱
