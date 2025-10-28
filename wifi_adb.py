#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wifi_adb.py — ADB Wi‑Fi Toolbox (all‑in‑one) in Python

Features:
- setup      : enable ADB over Wi‑Fi for USB devices + JSON inventory
- connect    : choose from list / manual IP, then launch scrcpy (presets + extras)
- list       : merge & show devices from JSON + ADB status
- usb-back   : switch all TCP devices back to USB mode
- disconnect : disconnect all ADB TCP endpoints
- pair       : Wireless debugging pairing (Android 11+)

Notes:
- Requires `adb` in PATH. Optional: `scrcpy` for mirroring.
- Data files:
  * wifi_device_setup.json  (dedup by IP; replace existing entry with same IP)
  * wifi_device_connect.json (append only if (device, model) combination not present)
- Tolerates JSON array, single object, or NDJSON (one JSON per line)
"""

import os
import sys
import re
import json
import time
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

# ----------------------------------------------------------------------------
# Config / Globals
# ----------------------------------------------------------------------------
FILE_SETUP = "wifi_device_setup.json"
FILE_CONN = "wifi_device_connect.json"
DEFAULT_IP = "192.168.43.1"
DEFAULT_ADB_PORT = 5555  # NEW: default ADB Wi‑Fi port (customizable)

# ANSI colors (auto-disable if not TTY)
class Colors:
    ESC = "\x1b"
    RST = f"{ESC}[0m"
    TITLE = f"{ESC}[95m"
    H1 = f"{ESC}[96m"
    NUM = f"{ESC}[93m"
    LBL = f"{ESC}[97m"
    DIM = f"{ESC}[90m"
    INFO = f"{ESC}[94m"
    WARN = f"{ESC}[93m"
    ERR = f"{ESC}[91m"
    NOTE = f"{ESC}[92m"
    ASK = f"{ESC}[38;5;219m"
    BAR = f"{ESC}[90m"

    enabled = sys.stdout.isatty()

    @classmethod
    def c(cls, text, color):
        if not cls.enabled:
            return text
        return f"{color}{text}{cls.RST}"

# Try to enable ANSI on Windows
if os.name == "nt":
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_uint32()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
    except Exception:
        pass

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def bar():
    print(Colors.c("="*59, Colors.BAR))

def sep():
    print(Colors.c("-"*59, Colors.BAR))


def run(cmd, input_text=None, check=False, capture=True, shell=False):
    """Run a subprocess and return (code, stdout, stderr)."""
    try:
        if capture:
            proc = subprocess.run(
                cmd,
                input=None if input_text is None else input_text.encode(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=shell,
            )
            out = proc.stdout.decode(errors="ignore")
            err = proc.stderr.decode(errors="ignore")
        else:
            proc = subprocess.run(cmd, shell=shell)
            out = ""
            err = ""
        if check and proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd, out, err)
        return proc.returncode, out, err
    except FileNotFoundError:
        return 127, "", f"Command not found: {cmd}"


def ensure_file_exists(path: Path):
    if not path.exists():
        path.write_text("[]", encoding="utf-8")


def timestamp_now():
    # Match the batch style a bit: Mon 10/13/2025 16:45:28.54
    return datetime.now().strftime("%a %m/%d/%Y %H:%M:%S.%f")[:-4]


def which(name):
    return shutil.which(name)


def ask(prompt: str, default: str | None = None):
    try:
        s = input(prompt)
    except EOFError:
        s = ""
    if not s and default is not None:
        return default
    return s

def ask_int(prompt: str, default: int | None = None) -> int | None:
    """Ask for an integer with default; returns None if user pressed Enter without default."""
    s = ask(prompt, "" if default is None else str(default))
    if not s.strip():
        return default
    try:
        return int(s.strip())
    except ValueError:
        return default


def press_enter(msg="Press Enter to continue..."):
    try:
        input(msg)
    except EOFError:
        pass

def normalize_dest(ip_or_dest: str, port: int | None) -> str:
    """Return 'ip:port' if port provided and ip has no port; otherwise return ip_or_dest as-is."""
    ip_or_dest = (ip_or_dest or "").strip()
    if ":" in ip_or_dest:
        return ip_or_dest
    p = port if port is not None else DEFAULT_ADB_PORT
    return f"{ip_or_dest}:{p}"


# ----------------------------------------------------------------------------
# JSON tolerant loading/saving
# ----------------------------------------------------------------------------

def load_json_flexible(path: Path) -> list[dict]:
    if not path.exists():
        return []
    raw = path.read_text(encoding="utf-8", errors="ignore").strip()
    if not raw:
        return []
    # Try array/dict first
    try:
        obj = json.loads(raw)
        if isinstance(obj, list):
            return [x for x in obj if isinstance(x, dict)]
        elif isinstance(obj, dict):
            return [obj]
    except json.JSONDecodeError:
        pass
    # Try NDJSON (one JSON object per line)
    items: list[dict] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
            if isinstance(o, dict):
                items.append(o)
        except json.JSONDecodeError:
            continue
    return items


def save_json_array(path: Path, items: list[dict]):
    # Pretty enough but compact
    path.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")


def append_or_replace_by_ip(path: Path, entry: dict):
    items = load_json_flexible(path)
    ip = entry.get("ip")
    if ip:
        for i, obj in enumerate(items):
            if obj.get("ip") == ip:
                items[i] = entry
                save_json_array(path, items)
                return
    items.append(entry)
    save_json_array(path, items)


def append_if_device_model_missing(path: Path, entry: dict):
    items = load_json_flexible(path)
    dev = entry.get("device") or ""
    mod = entry.get("model") or ""
    for obj in items:
        if (obj.get("device") or "") == dev and (obj.get("model") or "") == mod:
            # Exists — skip
            save_json_array(path, items)  # normalize format
            return False
    items.append(entry)
    save_json_array(path, items)
    return True


# ----------------------------------------------------------------------------
# ADB helpers
# ----------------------------------------------------------------------------

def ensure_adb():
    while not which("adb"):
        print(Colors.c("[ERROR]", Colors.ERR), "adb not found in PATH")
        print("Install Android Platform Tools and add adb to PATH")
        print("Retrying in 5 seconds - Press Ctrl+C to cancel")
        try:
            time.sleep(5)
        except KeyboardInterrupt:
            sys.exit(1)
    run(["adb", "start-server"])  # best effort


def adb_devices() -> list[tuple[str, str]]:
    code, out, _ = run(["adb", "devices"])
    lines = out.splitlines()[1:]  # skip header
    pairs = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        parts = re.split(r"\s+", ln)
        if len(parts) >= 2:
            pairs.append((parts[0], parts[1]))
    return pairs


def usb_serials_only() -> list[str]:
    # Exclude endpoints like host:port
    ser = []
    for s, state in adb_devices():
        if state == "device" and ":" not in s:
            ser.append(s)
    return ser


def adb_get_state(serial: str) -> str:
    _, out, _ = run(["adb", "-s", serial, "get-state"])  # returns "device" on success
    return out.strip()


def adb_shell(serial: str, *args: str) -> str:
    cmd = ["adb", "-s", serial, "shell", *args]
    _, out, _ = run(cmd)
    return out


def parse_first(out: str) -> str:
    for line in out.splitlines():
        line = line.strip()
        if line:
            return line
    return ""


def get_wifi_ip(serial: str) -> str:
    ip_regex = re.compile(r"\b(\d{1,3})(?:\.(\d{1,3})){3}\b")

    # 1) ip -o -4 addr show wlan0
    out = adb_shell(serial, "ip", "-o", "-4", "addr", "show", "wlan0")
    m = ip_regex.search(out)
    if m:
        return m.group(0)

    # 2) ip -f inet addr show wlan0 | grep inet
    out = adb_shell(serial, "sh", "-c", "ip -f inet addr show wlan0 | grep 'inet '")
    m = ip_regex.search(out)
    if m:
        return m.group(0)

    # 3) ip -o -4 addr show (wlan/p2p/ap/softap)
    out = adb_shell(serial, "ip", "-o", "-4", "addr", "show")
    for line in out.splitlines():
        if re.search(r"\b(wlan|p2p|ap|softap)\b", line, re.I):
            m = ip_regex.search(line)
            if m:
                return m.group(0)

    # 4) getprop dhcp.wlan0.ipaddress
    out = adb_shell(serial, "getprop", "dhcp.wlan0.ipaddress")
    out = parse_first(out)
    if ip_regex.fullmatch(out):
        return out

    # Fallback: if serial is already host:port, use host part
    if ":" in serial:
        host = serial.split(":", 1)[0]
        if ip_regex.fullmatch(host):
            return host
    return ""


def device_props(serial: str) -> dict:
    props = {}
    props["model"] = parse_first(adb_shell(serial, "getprop", "ro.product.model"))
    props["brand"] = parse_first(adb_shell(serial, "getprop", "ro.product.brand"))
    props["android"] = parse_first(adb_shell(serial, "getprop", "ro.build.version.release"))
    props["sdk"] = parse_first(adb_shell(serial, "getprop", "ro.build.version.sdk"))
    props["device"] = parse_first(adb_shell(serial, "getprop", "ro.product.device"))

    # Resolution / DPI
    size_out = adb_shell(serial, "wm", "size")
    m = re.search(r"Physical size:\s*(\S+)", size_out)
    props["resolution"] = m.group(1) if m else ""

    dens_out = adb_shell(serial, "wm", "density")
    m = re.search(r"Physical density:\s*(\S+)", dens_out)
    props["dpi"] = m.group(1) if m else ""

    # Battery level
    batt_out = adb_shell(serial, "dumpsys", "battery")
    m = re.search(r"^\s*level:\s*(\d+)", batt_out, re.M)
    props["battery"] = m.group(1) if m else ""

    # SSID
    wifi_out = adb_shell(serial, "dumpsys", "wifi")
    ssid = ""
    m = re.search(r"mWifiInfo SSID:\s*(.*)", wifi_out)
    if not m:
        m = re.search(r"\bSSID:\s*(.*)", wifi_out)
    if m:
        ssid = m.group(1).split(",")[0].strip().strip('"')
        if ssid.lower() == "<unknown ssid>" or ssid == "=":
            ssid = ""
    props["ssid"] = ssid or None

    # IP
    ip = get_wifi_ip(serial)
    props["ip"] = ip or None

    # Endpoint (default uses DEFAULT_ADB_PORT; actual connected port may differ)
    if ip:
        props["endpoint"] = f"{ip}:{DEFAULT_ADB_PORT}"
    else:
        props["endpoint"] = serial

    return props


def print_device_info(serial: str) -> dict:
    info = device_props(serial)
    print()
    sep()
    print("BRAND      :", info.get("brand", ""))
    print("MODEL      :", info.get("model", ""))
    print("DEVICE     :", info.get("device", ""))
    print("ANDROID    :", info.get("android", ""), " SDK", info.get("sdk", ""))
    print("RESOLUTION :", info.get("resolution") or "unknown")
    print("DPI        :", info.get("dpi") or "unknown")
    batt = info.get("battery")
    print("BATTERY    :", f"{batt}%" if batt else "unknown")
    ssid = info.get("ssid")
    print("SSID       :", ssid if ssid else "not available")
    ip = info.get("ip")
    if ip:
        print("WIFI_IP    :", ip)
        print("ADB_TCP    :", f"{ip}:{DEFAULT_ADB_PORT}")
    else:
        print("WIFI_IP    : not available")
        print("ADB_TCP    :", serial)
    sep()
    print()
    return info


def check_stay_awake_support(serial: str) -> bool:
    curr = parse_first(adb_shell(serial, "settings", "get", "global", "stay_on_while_plugged_in")) or "0"
    adb_shell(serial, "settings", "put", "global", "stay_on_while_plugged_in", "7")
    now = parse_first(adb_shell(serial, "settings", "get", "global", "stay_on_while_plugged_in"))
    ok = now.strip() == "7"
    # revert
    adb_shell(serial, "settings", "put", "global", "stay_on_while_plugged_in", curr)
    return ok


# ----------------------------------------------------------------------------
# Core commands
# ----------------------------------------------------------------------------

def cmd_setup():
    print(Colors.c("=== Enable ADB over Wi‑Fi for ALL USB devices ===", Colors.H1))
    print(f'Device info will be saved to "{FILE_SETUP}"\n')

    setup_path = Path(FILE_SETUP)
    ensure_file_exists(setup_path)

    # NEW: Ask once for the ADB Wi‑Fi port (default 5555) to be used for all devices
    adb_port = ask_int(f"ADB Wi‑Fi port for tcpip (Press Enter for default {DEFAULT_ADB_PORT}): ", DEFAULT_ADB_PORT)
    port_str = str(adb_port if adb_port else DEFAULT_ADB_PORT)

    # Wait for USB devices
    while True:
        serials = usb_serials_only()
        if serials:
            break
        print(Colors.c("[USB]", Colors.NOTE), 'Waiting for a USB device with state="device" ... make sure USB debugging is ENABLED')
        time.sleep(2)

    seen_ips = set()
    dup_ip = False

    model_a = {}
    ip_a = {}
    ep_a = {}

    for idx, ser in enumerate(serials, start=1):
        print()
        sep()
        print(f"Initializing {idx}/{len(serials)}  SERIAL: {ser}")
        usb_state = adb_get_state(ser)

        brand = model = devname = ver = sdk = size = dpi = batt = ssid_cur = ip_cur = endp_cur = ""

        if usb_state == "device":
            # Use chosen port instead of hardcoded 5555
            run(["adb", "-s", ser, "tcpip", port_str])  # ignore errors
            run(["adb", "-s", ser, "wait-for-device"])  # ignore

            ip_cur = get_wifi_ip(ser)

            # Props
            props = device_props(ser)
            brand = props.get("brand", "")
            model = props.get("model", "")
            devname = props.get("device", "")
            ver = props.get("android", "")
            sdk = props.get("sdk", "")
            size = props.get("resolution", "")
            dpi = props.get("dpi", "")
            batt = props.get("battery", "")
            ssid_cur = props.get("ssid", None) or ""

            if ip_cur:
                endp_cur = f"{ip_cur}:{port_str}"
                if ip_cur in seen_ips:
                    dup_ip = True
                seen_ips.add(ip_cur)
                run(["adb", "disconnect", endp_cur])
                run(["adb", "connect", endp_cur])
        else:
            print(Colors.c("[USB]", Colors.ERR), "Device is not ready over USB right now")

        print("BRAND      :", brand)
        print("MODEL      :", model)
        print("DEVICE     :", devname)
        print("ANDROID    :", ver, " SDK", sdk)
        print("RESOLUTION :", size or "unknown")
        print("DPI        :", dpi or "unknown")
        print("BATTERY    :", (batt + "%") if batt else "unknown")
        print("SSID       :", ssid_cur if ssid_cur else "not available")
        if ip_cur:
            print("WIFI_IP    :", ip_cur)
            print("ADB_TCP    :", endp_cur)
        else:
            print("WIFI_IP    : not available")
            print("ADB_TCP    : not available")

        model_a[idx] = model
        ip_a[idx] = ip_cur
        ep_a[idx] = endp_cur

        entry = {
            "timestamp": timestamp_now(),
            "serial": ser,
            "brand": brand or None,
            "model": model or None,
            "device": devname or None,
            "android": ver or None,
            "sdk": sdk or None,
            "resolution": size or None,
            "dpi": dpi or None,
            "battery": batt or None,
            "ssid": ssid_cur or None,
            "ip": ip_cur or None,
            "endpoint": endp_cur or None,
        }
        append_or_replace_by_ip(setup_path, entry)

    if dup_ip:
        print()
        print(Colors.c("[WARNING]", Colors.WARN), "Duplicate Wi‑Fi IP detected across interfaces/devices.")
        print("Use a single SSID or Windows Mobile Hotspot so each device gets a unique IP.")

    print()
    print(Colors.c("===== SUMMARY =====", Colors.H1))
    print(" No  Serial               Model                  IP              Endpoint          Status")
    print(" --  -------------------- ---------------------- --------------- ----------------- -------")
    for i in range(1, len(serials) + 1):
        ser = serials[i - 1]
        mod = (model_a.get(i) or "")[:22].ljust(22)
        ipx = (ip_a.get(i) or "")[:15].ljust(15)
        epx = (ep_a.get(i) or "")[:17].ljust(17)
        serpad = ser[:20].ljust(20)
        state = "offline"
        if ep_a.get(i):
            state = adb_get_state(ep_a[i]) or state
        print(f" {i:<2}  {serpad} {mod} {ipx} {epx} {state}")

    print()
    print(f'Data saved to "{FILE_SETUP}"')


def pick_scrcpy_opts(stay_awake_ok: bool) -> list[str]:
    print()
    print("Choose scrcpy preset:")
    print("  [1] Low        : --video-bit-rate 2M   --max-size 800")
    print("  [2] Default    : --video-bit-rate 8M   --max-size 1080")
    print("  [3] High       : --video-bit-rate 16M  --max-size 1440")
    print("  [4] Very High  : --video-bit-rate 24M  --max-size 1440")
    print("  [5] Ultra      : --video-bit-rate 32M  --max-size 2160")
    print("  [6] Extreme    : --video-bit-rate 64M  --max-size 2160")
    print("  [7] Insane     : --video-bit-rate 72M  --max-size 2160")

    preset = ask("Enter 1-7: ")
    base = []
    match preset:
        case "1":
            base = ["--video-bit-rate", "2M", "--max-size", "800"]
        case "2":
            base = ["--video-bit-rate", "8M", "--max-size", "1080"]
        case "3":
            base = ["--video-bit-rate", "16M", "--max-size", "1440"]
        case "4":
            base = ["--video-bit-rate", "24M", "--max-size", "1440"]
        case "5":
            base = ["--video-bit-rate", "32M", "--max-size", "2160"]
        case "6":
            base = ["--video-bit-rate", "64M", "--max-size", "2160"]
        case "7":
            base = ["--video-bit-rate", "72M", "--max-size", "2160"]
        case _:
            print("Invalid choice. Using Default.")
            base = ["--video-bit-rate", "8M", "--max-size", "1080"]

    if stay_awake_ok:
        base += ["--stay-awake"]
    else:
        print()
        print(Colors.c("[NOTE]", Colors.NOTE), '"stay-awake" is not permitted on this device/ROM; continuing without it.')

    print()
    print(Colors.c("Extras (optional):", Colors.H1), "Press Enter to skip or answer Y/N")
    if ask("Always on top? (--always-on-top) [y/N]: ", "N").lower().startswith("y"):
        base += ["--always-on-top"]
    if ask("Borderless window? (--window-borderless) [y/N]: ", "N").lower().startswith("y"):
        base += ["--window-borderless"]
    if ask("Fullscreen? (--fullscreen) [y/N]: ", "N").lower().startswith("y"):
        base += ["--fullscreen"]
    if ask("Mute audio? (--no-audio) [y/N]: ", "N").lower().startswith("y"):
        base += ["--no-audio"]
    if ask("Turn device screen off? (-S/--turn-screen-off) [y/N]: ", "N").lower().startswith("y"):
        base += ["-S"]
    if ask("Use H.265/HEVC? (--video-codec=h265) [y/N]: ", "N").lower().startswith("y"):
        base += ["--video-codec=h265"]
    if ask("Limit to 60 fps? (--max-fps 60) [y/N]: ", "N").lower().startswith("y"):
        base += ["--max-fps", "60"]

    ttl = ask("Custom window title? (--window-title) [blank = skip]: ")
    if ttl:
        base += ["--window-title", ttl]

    pos = ask("Set X,Y,Width,Height? (e.g. 100,80,900,1600) [skip=Enter]: ")
    if pos:
        m = re.match(r"\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*", pos)
        if m:
            x, y, w, h = m.groups()
            base += ["--window-x", x, "--window-y", y, "--window-width", w, "--window-height", h]

    if ask("Record to MP4? (--record file.mp4) [y/N]: ", "N").lower().startswith("y"):
        rec = ask("  File name [default record.mp4]: ", "record.mp4")
        base += ["--record", rec]

    return base


def save_connect_json(target_serial: str, last_info: dict):
    # Build entry
    ip_save = last_info.get("ip")
    if not ip_save and ":" in target_serial:
        ip_save = target_serial.split(":", 1)[0]
    serial_real = parse_first(run(["adb", "-s", target_serial, "get-serialno"])[1]) or target_serial

    # NEW: preserve the actual target endpoint if it includes a custom port
    if ":" in target_serial:
        ep_save = target_serial
    else:
        ep_save = f"{ip_save}:{DEFAULT_ADB_PORT}" if ip_save else target_serial

    entry = {
        "timestamp": timestamp_now(),
        "serial": serial_real,
        "brand": last_info.get("brand"),
        "model": last_info.get("model"),
        "device": last_info.get("device"),
        "android": last_info.get("android"),
        "sdk": last_info.get("sdk"),
        "resolution": last_info.get("resolution"),
        "dpi": last_info.get("dpi"),
        "battery": last_info.get("battery"),
        "ssid": last_info.get("ssid"),
        "ip": ip_save,
        "endpoint": ep_save,
    }
    added = append_if_device_model_missing(Path(FILE_CONN), entry)
    if not added:
        print(Colors.c("[SKIP]", Colors.INFO), "device+model combination already exists; not adding a new entry.")
    else:
        sz = Path(FILE_CONN).stat().st_size if Path(FILE_CONN).exists() else 0
        print(Colors.c("[WRITE]", Colors.INFO), f'Saved to "{Path(FILE_CONN).name}" (size={sz})')


def cmd_connect():
    print(Colors.c("=== Connect to Android over ADB Wi‑Fi and launch scrcpy ===", Colors.H1))
    print("1) Make sure the phone and PC are on the same Wi‑Fi/SSID")
    print("2) ADB over Wi‑Fi must be enabled (from Setup or Wireless debugging)\n")

    if not which("scrcpy"):
        print(Colors.c("[WARNING]", Colors.WARN), "scrcpy not found in PATH — you can still adb connect,")
        print("but screen mirroring will not run. Install scrcpy for mirroring.")

    # Offer combined list
    targets = build_combined_list()
    target = None
    if targets:
        print()
        print(Colors.c(f"Available devices (merged from {FILE_SETUP} and {FILE_CONN})", Colors.H1))
        print(" Id  IP               Endpoint           Model                Source")
        print(" --  ---------------  -----------------  --------------------  ---------------------")
        for i, rec in enumerate(targets, start=1):
            mod = (rec["model"] or "")[:20].ljust(20)
            print(f" {i:<2}  {rec['ip']:<15}  {rec['endpoint']:<17}  {mod}  {rec['source']}")
        print("    0   -- manual --      (type a new IP)\n")
        sel = ask("Pick Id (or 0 for manual IP): ", "")
        if sel and sel.isdigit() and int(sel) != 0 and 1 <= int(sel) <= len(targets):
            target = targets[int(sel) - 1]["endpoint"]

    if not target:
        dest = ask(f"Enter Android IP (or IP:PORT) [default {DEFAULT_IP}]: ", DEFAULT_IP)
        if ":" in dest:
            target = dest.strip()
        else:
            port_in = ask_int(f"ADB Wi‑Fi port [default {DEFAULT_ADB_PORT}]: ", DEFAULT_ADB_PORT)
            target = normalize_dest(dest, port_in)

    print()
    print(Colors.c("[ADB]", Colors.LBL), f"connecting to {target} ...")
    run(["adb", "disconnect", target])
    run(["adb", "connect", target])

    state = adb_get_state(target)
    if state.lower() != "device":
        print()
        print(Colors.c("[ERROR]", Colors.ERR), f"Failed to connect as \"device\". Current state: \"{state}\"")
        print("Check Wi‑Fi IP, SSID, and ensure ADB over Wi‑Fi is enabled on the phone.")
        return

    info = print_device_info(target)
    # Also show the actual endpoint in case of custom port
    print(Colors.c("ADB_TCP (connected):", Colors.DIM), target)

    save_connect_json(target, info)
    stay_ok = check_stay_awake_support(target)

    opts = pick_scrcpy_opts(stay_ok)
    print()
    print("Launching scrcpy with:\n  ", " ".join(map(str, opts)))

    if which("scrcpy"):
        # Launch and inherit stdio
        cmd = ["scrcpy", "-s", target, *opts]
        try:
            subprocess.run(cmd)
        except KeyboardInterrupt:
            pass
    else:
        print()
        print(Colors.c("[INFO]", Colors.INFO), "scrcpy is not installed, skipping mirroring launch.")


def build_combined_list() -> list[dict]:
    """Return list of {serial, model, ip, endpoint, source} deduped by IP."""
    out: list[dict] = []
    seen_ips: set[str] = set()

    for path, src in ((Path(FILE_SETUP), Path(FILE_SETUP).name), (Path(FILE_CONN), Path(FILE_CONN).name)):
        items = load_json_flexible(path)
        for it in items:
            serial = it.get("serial") or ""
            model = it.get("model") or ""
            ip = it.get("ip") or ""
            endpoint = it.get("endpoint") or (f"{ip}:{DEFAULT_ADB_PORT}" if ip else "")
            if not ip or ip in seen_ips:
                continue
            seen_ips.add(ip)
            out.append({
                "serial": serial,
                "model": model,
                "ip": ip,
                "endpoint": endpoint,
                "source": src,
            })
    return out


def cmd_list():
    print(Colors.c("=== Reading device list from JSON (read‑only) ===", Colors.H1))
    p1, p2 = Path(FILE_SETUP), Path(FILE_CONN)
    sz1 = p1.stat().st_size if p1.exists() else "?"
    sz2 = p2.stat().st_size if p2.exists() else "?"
    print(Colors.c("File info:", Colors.DIM), f"{FILE_SETUP} (size={sz1}) | {FILE_CONN} (size={sz2})")

    rows = build_combined_list()
    if not rows:
        print()
        print(Colors.c("[INFO]", Colors.WARN), "Could not build the merged list (no data).")
        print(Colors.c("Showing raw JSON file contents for diagnostics:", Colors.DIM))
        for p in (p1, p2):
            print("---", p.name, "---")
            if p.exists():
                print(p.read_text(encoding="utf-8", errors="ignore"))
            else:
                print(f"(file {p.name} does not exist)")
        print(Colors.c("(Run 1:Setup or 2:Connect to populate data if empty)", Colors.DIM))
        press_enter("\nPress Enter to return...")
        return

    print()
    print(Colors.c("===== SUMMARY =====", Colors.H1))
    print(" No  Serial               Model                  IP              Endpoint          Status")
    print(" --  -------------------- ---------------------- --------------- ----------------- -------")

    for i, rec in enumerate(rows, start=1):
        serpad = rec["serial"][:20].ljust(20)
        modpad = (rec["model"] or "")[:22].ljust(22)
        ippad = rec["ip"][:15].ljust(15)
        eppad = rec["endpoint"][:17].ljust(17)
        state = adb_get_state(rec["endpoint"]) or "offline"
        print(f" {i:<2}  {serpad} {modpad} {ippad} {eppad} {state}")

    sel = ask("\nPick No to CONNECT (Enter=Back): ", "")
    if not sel or not sel.isdigit():
        return
    idx = int(sel)
    if not (1 <= idx <= len(rows)):
        print(Colors.c("[ERROR]", Colors.ERR), "Invalid number.")
        press_enter("Press Enter to return...")
        return

    target = rows[idx - 1]["endpoint"]
    connect_from_list(target)


def connect_from_list(target: str):
    print()
    print(Colors.c("[ADB]", Colors.LBL), f"connect to {target} ...")
    run(["adb", "disconnect", target])
    run(["adb", "connect", target])

    state = adb_get_state(target)
    if state.lower() != "device":
        print()
        print(Colors.c("[ERROR]", Colors.ERR), f"Failed to connect as \"device\". Current state: \"{state}\"")
        print("Check the IP/endpoint in JSON and that ADB over Wi‑Fi is enabled on the phone.")
        press_enter("\nPress Enter to return...")
        return

    info = print_device_info(target)
    print(Colors.c("ADB_TCP (connected):", Colors.DIM), target)
    save_connect_json(target, info)
    stay_ok = check_stay_awake_support(target)

    opts = pick_scrcpy_opts(stay_ok)
    print()
    print("Launching scrcpy with:\n  ", " ".join(map(str, opts)))

    if which("scrcpy"):
        try:
            subprocess.run(["scrcpy", "-s", target, *opts])
        except KeyboardInterrupt:
            pass
    else:
        print()
        print(Colors.c("[INFO]", Colors.INFO), "scrcpy is not installed, skipping mirroring launch.")


# usb-back: switch all host:port endpoints back to USB

def cmd_usb_back():
    print("\nSwitching all TCP endpoints back to USB...")
    for serial, _state in adb_devices():
        if ":" in serial:
            print("  -", serial, "> usb")
            run(["adb", "-s", serial, "usb"])  # ignore errors
    print("Done.")


# disconnect all TCP endpoints

def cmd_disconnect_all():
    print("\nDisconnecting all ADB TCP endpoints...")
    run(["adb", "disconnect"])  # no args: disconnect everything
    print("Done.")


# pair (Android 11+ wireless debugging)

def cmd_pair():
    print(Colors.c("=== ADB Wireless debugging (Android 11+) ===", Colors.H1))
    pair_ep = ask("Enter pairing endpoint (e.g. 192.168.1.10:37187): ")
    if not pair_ep:
        print("Endpoint is required.")
        return
    pair_code = ask("Enter pairing code (6 digits): ")

    print(f"\nadb pair {pair_ep}")
    if pair_code:
        # Feed code via stdin
        run(["adb", "pair", pair_ep], input_text=pair_code + "\n")
    else:
        subprocess.run(["adb", "pair", pair_ep])

    print("\nIf pairing succeeds, connect the device endpoint (usually IP:5555).")
    c_ep = ask("Endpoint to connect [default derived from IP:5555]: ")
    if not c_ep:
        host = pair_ep.split(":", 1)[0]
        c_ep = f"{host}:{DEFAULT_ADB_PORT}"
    run(["adb", "connect", c_ep])


# ----------------------------------------------------------------------------
# Menu / CLI
# ----------------------------------------------------------------------------

def main():
    os.chdir(Path(__file__).resolve().parent)
    ensure_adb()

    # Route via CLI arg if present
    arg = sys.argv[1].lower() if len(sys.argv) > 1 else ""
    if arg in ("help", "-h", "--help"):
        arg = ""

    if arg == "setup":
        cmd_setup()
        return
    if arg == "connect":
        cmd_connect()
        return
    if arg == "list":
        cmd_list()
        return
    if arg == "usb-back":
        cmd_usb_back()
        return
    if arg == "disconnect":
        cmd_disconnect_all()
        return
    if arg == "pair":
        cmd_pair()
        return

    # Interactive menu
    while True:
        os.system("cls" if os.name == "nt" else "clear")
        bar()
        print(Colors.c("   A D B   W i - F i   T o o l b o x", Colors.TITLE))
        bar()
        print(f"  {Colors.c('[1]', Colors.NUM)} {Colors.c('Setup            ', Colors.LBL)} {Colors.c(': Enable ADB over Wi‑Fi (USB) + save to ' + FILE_SETUP, Colors.DIM)}")
        print(f"  {Colors.c('[2]', Colors.NUM)} {Colors.c('Connect          ', Colors.LBL)} {Colors.c(': Pick from list / manual IP → scrcpy presets + extras', Colors.DIM)}")
        print(f"  {Colors.c('[3]', Colors.NUM)} {Colors.c('List             ', Colors.LBL)} {Colors.c(': Show known devices (from JSON) + ADB status', Colors.DIM)}")
        print(f"  {Colors.c('[4]', Colors.NUM)} {Colors.c('USB-Back All     ', Colors.LBL)} {Colors.c(': Switch all TCP devices back to USB', Colors.DIM)}")
        print(f"  {Colors.c('[5]', Colors.NUM)} {Colors.c('Disconnect All   ', Colors.LBL)} {Colors.c(': adb disconnect (all endpoints)', Colors.DIM)}")
        print(f"  {Colors.c('[6]', Colors.NUM)} {Colors.c('Pair             ', Colors.LBL)} {Colors.c(': Wireless debugging pairing (Android 11+)', Colors.DIM)}")
        print(f"  {Colors.c('[0]', Colors.NUM)} {Colors.c('Exit             ', Colors.LBL)}")
        bar()
        choice = ask(Colors.c("Choose: ", Colors.ASK))
        if choice == "1":
            cmd_setup()
            press_enter("\nPress Enter to return to the menu...")
        elif choice == "2":
            cmd_connect()
            press_enter("\nPress Enter to return to the menu...")
        elif choice == "3":
            cmd_list()
            # cmd_list has its own return/press
        elif choice == "4":
            cmd_usb_back()
            press_enter("\nPress Enter to return to the menu...")
        elif choice == "5":
            cmd_disconnect_all()
            press_enter("\nPress Enter to return to the menu...")
        elif choice == "6":
            cmd_pair()
            press_enter("\nPress Enter to return to the menu...")
        elif choice == "0":
            break


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.")
