#!/usr/bin/env python3
# HATAN OS — واجهة API للإعدادات والنظام

import json
import os
import platform
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Optional

HATAN_DIR = Path(os.environ.get('HATAN_DIR', '/opt/hatan-os'))
if not HATAN_DIR.is_dir():
    HATAN_DIR = Path(__file__).resolve().parent.parent.parent

SETTINGS_FILE = HATAN_DIR / 'config' / 'user-settings.json'
WALLPAPER_DIR = HATAN_DIR / 'themes' / 'wallpapers'

THEMES = {
    'hatan': {'primary': '#2563EB', 'accent': '#22D3EE', 'label': 'HATAN Blue'},
    'aurora': {'primary': '#6366F1', 'accent': '#A78BFA', 'label': 'Aurora'},
    'cyan': {'primary': '#0891B2', 'accent': '#22D3EE', 'label': 'Cyber'},
    'gold': {'primary': '#C9A227', 'accent': '#FFD700', 'label': 'Gold'},
    'crimson': {'primary': '#6366F1', 'accent': '#A78BFA', 'label': 'Aurora'},
}


def _run(cmd, default=''):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
        return r.stdout.strip() if r.returncode == 0 else default
    except Exception:
        return default


def load_settings():
    defaults = {
        'deviceName': 'Steam Deck',
        'wallpaper': 'default',
        'volume': 75,
        'brightness': 80,
        'theme': 'hatan',
        'language': 'ar',
        'keyboard': 'ar',
        'showClock': True,
        'showBattery': True,
        'buttonMap': {
            'A': 'confirm', 'B': 'back', 'X': 'options', 'Y': 'toggle-wifi',
            'L1': 'volume-down', 'R1': 'volume-up',
            'L2': 'brightness-down', 'R2': 'brightness-up',
            'L3': 'log-usage', 'R3': 'toggle-keyboard',
            'L4': 'log-usage', 'R4': 'screenshot',
            'SELECT': 'none', 'START': 'open-settings',
            'STEAM': 'home', 'QAM': 'options',
            'DPAD_UP': 'none', 'DPAD_DOWN': 'none',
            'DPAD_LEFT': 'none', 'DPAD_RIGHT': 'none',
        },
    }
    if SETTINGS_FILE.is_file():
        try:
            data = json.loads(SETTINGS_FILE.read_text(encoding='utf-8'))
            defaults.update(data)
        except json.JSONDecodeError:
            pass
    return defaults


def save_settings(data: dict):
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    current = load_settings()
    current.update(data)
    SETTINGS_FILE.write_text(
        json.dumps(current, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )
    return current


def get_volume():
    out = _run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'])
    if out:
        m = re.search(r'([\d.]+)', out)
        if m and ('volume' in out.lower() or '/' in out):
            val = float(m.group(1))
            return int(val * 100) if val <= 1 else int(val)
        m = re.search(r'(\d+)%', out)
        if m:
            return int(m.group(1))
    return load_settings().get('volume', 75)


def set_volume(level: int):
    level = max(0, min(100, level))
    if shutil.which('wpctl'):
        _run(['wpctl', 'set-volume', '@DEFAULT_AUDIO_SINK@', f'{level}%'])
    save_settings({'volume': level})
    return level


def get_brightness():
    out = _run(['brightnessctl', 'get'])
    max_out = _run(['brightnessctl', 'max'])
    try:
        if out and max_out:
            return int(int(out) / int(max_out) * 100)
    except (ValueError, ZeroDivisionError):
        pass
    return load_settings().get('brightness', 80)


def set_brightness(level: int):
    level = max(5, min(100, level))
    if shutil.which('brightnessctl'):
        _run(['brightnessctl', 'set', f'{level}%'])
    save_settings({'brightness': level})
    return level


def get_network():
    wifi_on = 'enabled' in _run(['nmcli', 'radio', 'wifi']).lower() or \
              'yes' in _run(['nmcli', 'radio', 'wifi']).lower()
    bt_on = 'enabled' in _run(['nmcli', 'radio', 'bluetooth']).lower() or \
            'yes' in _run(['nmcli', 'radio', 'bluetooth']).lower()
    ssid = '—'
    for line in _run(['nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi']).splitlines():
        parts = line.split(':')
        if len(parts) >= 2 and parts[0] == 'yes':
            ssid = parts[1] or '—'
            break
    vpn = '—'
    for line in _run(['nmcli', '-t', '-f', 'name,type', 'connection', 'show', '--active']).splitlines():
        if 'vpn' in line.lower():
            vpn = line.split(':')[0]
            break
    devices = get_connected_devices()
    return {
        'wifi': {'enabled': wifi_on, 'connected': ssid},
        'bluetooth': {'enabled': bt_on, 'devices': devices.get('bluetooth', [])},
        'vpn': {'active': vpn},
        'usb': devices.get('usb', []),
        'connected': devices.get('all', []),
    }


def _guess_link_type(name: str, desc: str = '') -> str:
    text = f'{name} {desc}'.lower()
    if any(k in text for k in ('bluez', 'bluetooth', 'bt ', 'headset')):
        return 'bluetooth'
    if 'usb' in text or 'type-c' in text or 'typec' in text:
        return 'usb'
    if 'wifi' in text or 'wlan' in text:
        return 'wifi'
    if 'hdmi' in text or 'displayport' in text:
        return 'display'
    return 'builtin'


def _link_icon(link: str) -> str:
    return {
        'bluetooth': '🔵',
        'usb': '🔌',
        'wifi': '📶',
        'display': '🖥️',
        'builtin': '🔊',
    }.get(link, '📱')


def _pactl_list(kind: str):
    """kind: sinks | sources"""
    items = []
    if not shutil.which('pactl'):
        return items
    raw = _run(['pactl', 'list', kind, 'short'])
    for line in raw.splitlines():
        parts = line.split('\t')
        if len(parts) < 2:
            continue
        node_id = parts[1]
        if kind == 'sources' and '.monitor' in node_id:
            continue
        label = parts[3] if len(parts) > 3 and parts[3] else node_id
        link = _guess_link_type(node_id, label)
        items.append({
            'id': node_id,
            'index': parts[0],
            'label': label,
            'link': link,
            'icon': _link_icon(link),
            'active': False,
        })
    return items


def get_audio_devices():
    outputs = _pactl_list('sinks')
    inputs = _pactl_list('sources')
    default_out = _run(['pactl', 'get-default-sink']) if shutil.which('pactl') else ''
    default_in = _run(['pactl', 'get-default-source']) if shutil.which('pactl') else ''

    if not default_out and shutil.which('wpctl'):
        status = _run(['wpctl', 'status'])
        for line in status.splitlines():
            if 'Default Output' in line or 'Default Audio Sink' in line:
                default_out = line.split(':')[-1].strip().strip('*').strip()
            if 'Default Input' in line or 'Default Audio Source' in line:
                default_in = line.split(':')[-1].strip().strip('*').strip()

    for o in outputs:
        o['active'] = o['id'] == default_out or default_out.endswith(o['id'])
    for i in inputs:
        i['active'] = i['id'] == default_in or default_in.endswith(i['id'])

    settings = load_settings()
    return {
        'outputs': outputs,
        'inputs': inputs,
        'defaultOutput': default_out or settings.get('audioOutput', ''),
        'defaultInput': default_in or settings.get('audioInput', ''),
    }


def set_default_audio(kind: str, device_id: str):
    if kind == 'output':
        if shutil.which('pactl'):
            _run(['pactl', 'set-default-sink', device_id])
        save_settings({'audioOutput': device_id})
    elif kind == 'input':
        if shutil.which('pactl'):
            _run(['pactl', 'set-default-source', device_id])
        save_settings({'audioInput': device_id})
    return get_audio_devices()


def get_usb_devices():
    items = []
    if not shutil.which('lsusb'):
        return items
    for line in _run(['lsusb']).splitlines():
        if not line.strip() or not line.startswith('Bus'):
            continue
        m = re.match(r'Bus (\d+) Device (\d+): ID ([0-9a-f:]+)\s*(.*)', line, re.I)
        if not m:
            continue
        bus, dev, vid, name = m.groups()
        name = name.strip() or 'جهاز USB'
        link = 'usb'
        if any(k in name.lower() for k in ('audio', 'headset', 'speaker', 'mic', 'sound')):
            link = 'usb-audio'
        items.append({
            'id': f'{vid}-{bus}-{dev}',
            'name': name,
            'bus': bus,
            'device': dev,
            'link': 'usb',
            'icon': '🔌',
            'connected': True,
            'type': 'usb',
        })
    return items[:12]


def get_bluetooth_devices():
    items = []
    seen = set()
    if shutil.which('bluetoothctl'):
        for line in _run(['bluetoothctl', 'devices']).splitlines():
            parts = line.split(' ', 2)
            if len(parts) < 3 or parts[0] != 'Device':
                continue
            mac, name = parts[1], parts[2]
            if mac in seen:
                continue
            seen.add(mac)
            info = _run(['bluetoothctl', 'info', mac])
            connected = 'Connected: yes' in info
            paired = 'Paired: yes' in info
            items.append({
                'id': mac,
                'name': name,
                'link': 'bluetooth',
                'icon': '🔵',
                'connected': connected,
                'paired': paired,
                'type': 'bluetooth',
            })
    if not items and shutil.which('nmcli'):
        for line in _run(['nmcli', '-t', '-f', 'NAME,TYPE,STATE', 'device']).splitlines():
            parts = line.split(':')
            if len(parts) >= 3 and 'bluetooth' in parts[1].lower():
                items.append({
                    'id': parts[0],
                    'name': parts[0],
                    'link': 'bluetooth',
                    'icon': '🔵',
                    'connected': parts[2] == 'connected',
                    'type': 'bluetooth',
                })
    return items


def get_wifi_devices():
    items = []
    if not shutil.which('nmcli'):
        return items
    for line in _run(['nmcli', '-t', '-f', 'NAME,TYPE,STATE,CONNECTION', 'device']).splitlines():
        parts = line.split(':')
        if len(parts) < 3:
            continue
        name, dtype, state = parts[0], parts[1], parts[2]
        conn = parts[3] if len(parts) > 3 else ''
        if 'wifi' not in dtype.lower() and 'wlan' not in dtype.lower():
            continue
        items.append({
            'id': name,
            'name': conn or name,
            'link': 'wifi',
            'icon': '📶',
            'connected': state == 'connected',
            'type': 'wifi',
            'state': state,
        })
    return items


def get_connected_devices():
    usb = get_usb_devices()
    bluetooth = get_bluetooth_devices()
    wifi = get_wifi_devices()
    all_items = []
    for group in (usb, bluetooth, wifi):
        all_items.extend(group)
    return {'usb': usb, 'bluetooth': bluetooth, 'wifi': wifi, 'all': all_items}


def connect_device(device_type: str, device_id: str):
    if device_type == 'bluetooth' and shutil.which('bluetoothctl'):
        _run(['bluetoothctl', 'connect', device_id])
        return {'ok': True, 'type': device_type, 'devices': get_connected_devices()}
    if device_type == 'wifi' and shutil.which('nmcli'):
        subprocess.Popen(['nm-connection-editor'],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {'ok': True, 'type': device_type, 'action': 'open-wifi-ui'}
    if device_type == 'usb':
        return {'ok': True, 'type': device_type, 'message': 'وصّل الجهاز عبر USB Type-C'}
    return {'ok': False, 'type': device_type}


def scan_devices(device_type: str):
    if device_type == 'bluetooth' and shutil.which('bluetoothctl'):
        _run(['bluetoothctl', 'scan', 'on'], default='')
        time.sleep(3)
        _run(['bluetoothctl', 'scan', 'off'], default='')
        return {'ok': True, 'devices': get_bluetooth_devices()}
    return {'ok': False, 'devices': []}


def mock_audio_devices():
    return {
        'outputs': [
            {'id': 'deck-speakers', 'label': 'Steam Deck Speakers', 'link': 'builtin', 'icon': '🔊', 'active': True},
            {'id': 'usb-headset', 'label': 'USB-C Headset', 'link': 'usb', 'icon': '🔌', 'active': False},
            {'id': 'bt-earbuds', 'label': 'AirPods (Bluetooth)', 'link': 'bluetooth', 'icon': '🔵', 'active': False},
        ],
        'inputs': [
            {'id': 'deck-mic', 'label': 'Steam Deck Microphone', 'link': 'builtin', 'icon': '🔊', 'active': True},
            {'id': 'usb-mic', 'label': 'USB-C Microphone', 'link': 'usb', 'icon': '🔌', 'active': False},
            {'id': 'bt-mic', 'label': 'Bluetooth Headset Mic', 'link': 'bluetooth', 'icon': '🔵', 'active': False},
        ],
        'defaultOutput': 'deck-speakers',
        'defaultInput': 'deck-mic',
    }


def mock_connected_devices():
    data = {
        'usb': [
            {'id': 'usb-c-dock', 'name': 'USB-C Dock', 'link': 'usb', 'icon': '🔌', 'connected': True, 'type': 'usb'},
            {'id': 'usb-audio', 'name': 'USB Audio Interface', 'link': 'usb', 'icon': '🔌', 'connected': True, 'type': 'usb'},
        ],
        'bluetooth': [
            {'id': 'AA:BB:CC:DD:EE:FF', 'name': 'DualSense Controller', 'link': 'bluetooth', 'icon': '🔵', 'connected': True, 'type': 'bluetooth', 'paired': True},
            {'id': '11:22:33:44:55:66', 'name': 'Bluetooth Headphones', 'link': 'bluetooth', 'icon': '🔵', 'connected': False, 'type': 'bluetooth', 'paired': True},
        ],
        'wifi': [
            {'id': 'wlan0', 'name': 'Home-WiFi-5G', 'link': 'wifi', 'icon': '📶', 'connected': True, 'type': 'wifi', 'state': 'connected'},
        ],
    }
    data['all'] = data['usb'] + data['bluetooth'] + data['wifi']
    return data


def get_storage():
    items = []
    raw = _run(['df', '-h', '--output=target,size,used,avail,pcent'])
    for line in raw.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 5 and parts[0].startswith('/'):
            items.append({
                'mount': parts[0],
                'size': parts[1],
                'used': parts[2],
                'free': parts[3],
                'percent': parts[4].replace('%', ''),
            })
    return items[:4]


def _read_version():
    conf = HATAN_DIR / 'config' / 'hat-os.conf'
    if conf.is_file():
        for line in conf.read_text(encoding='utf-8').splitlines():
            if line.startswith('version='):
                return line.split('=')[1].strip('"')
    return '0.1.0'


def get_system_info():
    settings = load_settings()
    mem_lines = _run(['free', '-h']).splitlines()
    ram = mem_lines[1].split()[1] if len(mem_lines) > 1 else '—'
    disk = get_storage()
    root = next((d for d in disk if d['mount'] == '/'), disk[0] if disk else {})

    cpu_raw = _run(['lscpu'])
    cpu = 'AMD Zen 2 APU'
    if 'Model name' in cpu_raw:
        cpu = cpu_raw.split('Model name:')[-1].split('\n')[0].strip()

    return {
        'deviceName': settings.get('deviceName', 'Steam Deck'),
        'system': 'HATAN OS',
        'version': _read_version(),
        'codename': 'Genesis',
        'kernel': _run(['uname', '-r']) or platform.release(),
        'hostname': _run(['hostname']) or settings.get('deviceName'),
        'cpu': cpu,
        'gpu': 'AMD Van Gogh (Steam Deck)',
        'ram': ram,
        'storage': root,
        'display': '1280 × 800 LCD',
        'platform': platform.system(),
        'arch': platform.machine(),
    }


def get_wallpapers():
    WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    items = [{'id': 'default', 'label': 'افتراضي', 'url': '/assets/boot.png'}]
    for f in sorted(WALLPAPER_DIR.glob('*')):
        if f.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp'):
            items.append({
                'id': f.stem,
                'label': f.stem,
                'url': f'/api/wallpaper/{f.name}',
            })
    return items


def get_full_state():
    settings = load_settings()
    try:
        settings['volume'] = get_volume()
    except Exception:
        pass
    try:
        settings['brightness'] = get_brightness()
    except Exception:
        pass
    return {
        'settings': settings,
        'network': get_network(),
        'audio': get_audio_devices(),
        'devices': get_connected_devices(),
        'storage': get_storage(),
        'system': get_system_info(),
        'themes': THEMES,
        'wallpapers': get_wallpapers(),
        'status': get_status(),
        'updates': check_updates(),
    }


def load_ui_config():
    conf = HATAN_DIR / 'config' / 'hat-os.conf'
    ui = {'show_clock': True, 'show_battery': True}
    if conf.is_file():
        section = ''
        for line in conf.read_text(encoding='utf-8', errors='ignore').splitlines():
            line = line.strip()
            if line.startswith('[') and line.endswith(']'):
                section = line[1:-1].lower()
                continue
            if section == 'ui' and '=' in line:
                k, _, v = line.partition('=')
                k = k.strip().lower()
                v = v.strip().strip('"').lower()
                if k == 'show_clock':
                    ui['show_clock'] = v in ('true', '1', 'yes')
                if k == 'show_battery':
                    ui['show_battery'] = v in ('true', '1', 'yes')
    s = load_settings()
    if 'showClock' in s:
        ui['show_clock'] = bool(s['showClock'])
    if 'showBattery' in s:
        ui['show_battery'] = bool(s['showBattery'])
    return ui


def get_battery():
    for base in ('/sys/class/power_supply/BATT', '/sys/class/power_supply/battery'):
        p = Path(base)
        if not p.is_dir():
            continue
        try:
            status = (p / 'status').read_text().strip().lower()
            cap = (p / 'capacity').read_text().strip()
            pct = int(float(cap))
            charging = status in ('charging', 'full', 'fully charged')
            return {'percent': pct, 'charging': charging, 'present': True}
        except (OSError, ValueError):
            continue
    return {'percent': 78, 'charging': False, 'present': False, 'preview': True}


def get_status():
    ui = load_ui_config()
    net = get_network()
    wifi = net.get('wifi', {})
    from datetime import datetime
    now = datetime.now()
    return {
        'time': now.strftime('%H:%M'),
        'date': now.strftime('%Y-%m-%d'),
        'battery': get_battery(),
        'wifi': {
            'enabled': wifi.get('enabled', False),
            'connected': wifi.get('connected', '—'),
        },
        'showClock': ui['show_clock'],
        'showBattery': ui['show_battery'],
    }


def mock_status():
    return get_status()


KEYBOARD_LAYOUTS = {
    'ar': 'ara',
    'en-us': 'us',
    'en-gb': 'gb',
}

LOCALE_MAP = {
    'ar': 'ar_SA.UTF-8',
    'en': 'en_US.UTF-8',
}


def apply_language(lang: str):
    locale = LOCALE_MAP.get(lang, LOCALE_MAP.get('ar'))
    if shutil.which('localectl'):
        _run(['localectl', 'set-locale', f'LANG={locale}'])
    home = Path.home()
    profile = home / '.profile'
    line = f'export LANG={locale}\n'
    if profile.is_file():
        text = profile.read_text(encoding='utf-8', errors='ignore')
        if 'export LANG=' in text:
            text = re.sub(r'export LANG=.*\n', line, text)
        else:
            text += '\n' + line
        profile.write_text(text, encoding='utf-8')
    os.environ['LANG'] = locale
    return {'ok': True, 'language': lang, 'locale': locale}


def apply_keyboard_setting(kb: str):
    layout = KEYBOARD_LAYOUTS.get(kb, 'us')
    if shutil.which('localectl'):
        _run(['localectl', 'set-x11-keymap', layout])
    if shutil.which('setxkbmap'):
        _run(['setxkbmap', layout])
    return {'ok': True, 'keyboard': kb, 'layout': layout}


def check_updates():
    if not shutil.which('pacman'):
        return {'available': 3, 'preview': True, 'packages': []}
    out = _run(['pacman', '-Qu'])
    lines = [l for l in out.splitlines() if l.strip()] if out else []
    pkgs = []
    for line in lines[:20]:
        parts = line.split()
        if parts:
            pkgs.append(parts[0])
    return {'available': len(lines), 'packages': pkgs, 'preview': False}


def run_system_update():
    if not shutil.which('pacman'):
        return {'ok': False, 'preview': True}
    subprocess.Popen(
        ['pkexec', 'pacman', '-Syu', '--noconfirm'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return {'ok': True, 'started': True}


def system_power(action: str):
    cmds = {
        'suspend': ['systemctl', 'suspend'],
        'reboot': ['systemctl', 'reboot'],
        'shutdown': ['systemctl', 'poweroff'],
    }
    cmd = cmds.get(action)
    if not cmd:
        return {'ok': False, 'error': 'unknown action'}
    if not shutil.which('systemctl'):
        return {'ok': False, 'preview': True, 'action': action}
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {'ok': True, 'action': action}


def get_wifi_networks():
    if not shutil.which('nmcli'):
        return [
            {'ssid': 'Home-WiFi-5G', 'signal': 92, 'active': True, 'security': 'WPA2'},
            {'ssid': 'Guest', 'signal': 64, 'active': False, 'security': 'WPA2'},
        ]
    out = _run(['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'])
    nets = []
    seen = set()
    for line in out.splitlines():
        parts = line.split(':')
        if len(parts) < 4:
            continue
        active, ssid, signal, security = parts[0], parts[1], parts[2], parts[3]
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        try:
            sig = int(signal)
        except ValueError:
            sig = 0
        nets.append({
            'ssid': ssid,
            'signal': sig,
            'active': active == 'yes' or active == '*',
            'security': security or '—',
        })
    nets.sort(key=lambda n: (-n['active'], -n['signal']))
    return nets[:24]


def wifi_connect(ssid: str, password: str = ''):
    if not shutil.which('nmcli'):
        return {'ok': True, 'preview': True, 'ssid': ssid}
    cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid]
    if password:
        cmd += ['password', password]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    return {'ok': r.returncode == 0, 'ssid': ssid, 'message': r.stdout.strip() or r.stderr.strip()}


def get_lutris_games(limit=4):
    games = []
    if shutil.which('lutris'):
        out = _run(['lutris', '--list-games'])
        for line in out.splitlines():
            line = line.strip()
            if not line or line.startswith('lutris'):
                continue
            slug = re.sub(r'[^a-z0-9-]', '', line.lower().replace(' ', '-'))[:40]
            games.append({
                'appid': f'lutris-{slug or len(games)}',
                'name': line,
                'playtime': 0,
                'playtimeLabel': 'Lutris',
                'image': '',
                'source': 'lutris',
                'slug': slug or str(len(games)),
            })
            if len(games) >= limit:
                break
    return games


def apply_settings_patch(patch: dict):
    if 'volume' in patch:
        set_volume(int(patch['volume']))
    if 'brightness' in patch:
        set_brightness(int(patch['brightness']))
    if 'language' in patch:
        apply_language(patch['language'])
    if 'keyboard' in patch:
        apply_keyboard_setting(patch['keyboard'])
    allowed = {'deviceName', 'wallpaper', 'theme', 'language', 'keyboard', 'buttonMap',
               'audioOutput', 'audioInput', 'showClock', 'showBattery'}
    clean = {k: v for k, v in patch.items() if k in allowed}
    if clean:
        save_settings(clean)
    return get_full_state()


def _steam_root():
    home = Path.home()
    for p in (home / '.local/share/Steam', home / '.steam/root', home / '.steam/steam'):
        if (p / 'steamapps').is_dir():
            return p
    return None


def _acf_field(text: str, key: str, default=''):
    m = re.search(rf'"{re.escape(key)}"\s+"([^"]*)"', text)
    return m.group(1) if m else default


def _steam_libraries(root: Path):
    libs = [root / 'steamapps']
    vdf = root / 'steamapps' / 'libraryfolders.vdf'
    if vdf.is_file():
        text = vdf.read_text(encoding='utf-8', errors='ignore')
        for m in re.finditer(r'"path"\s+"([^"]+)"', text):
            p = Path(m.group(1).replace('\\\\', '\\'))
            if (p / 'steamapps').is_dir():
                libs.append(p / 'steamapps')
    seen = set()
    out = []
    for lib in libs:
        key = str(lib.resolve())
        if key not in seen:
            seen.add(key)
            out.append(lib)
    return out


def _game_image_url(appid: str, root: Optional[Path]) -> str:
    if root:
        cache = root / 'appcache' / 'librarycache'
        for name in (f'{appid}_library_600x900.jpg', f'{appid}_header.jpg', f'{appid}_logo.png'):
            f = cache / name
            if f.is_file():
                return f'/api/game-image/{appid}'
    return f'https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/header.jpg'


def _format_playtime(minutes: int) -> str:
    if minutes <= 0:
        return ''
    h = minutes // 60
    m = minutes % 60
    if h and m:
        return f'{h}h {m}m'
    if h:
        return f'{h}h'
    return f'{m}m'


def mock_steam_games():
    items = [
        {'appid': '1245620', 'name': 'ELDEN RING', 'playtime': 2520, 'playtimeLabel': '42h', 'image': 'https://cdn.cloudflare.steamstatic.com/steam/apps/1245620/header.jpg'},
        {'appid': '1174180', 'name': 'Red Dead Redemption 2', 'playtime': 1860, 'playtimeLabel': '31h', 'image': 'https://cdn.cloudflare.steamstatic.com/steam/apps/1174180/header.jpg'},
        {'appid': '1091500', 'name': 'Cyberpunk 2077', 'playtime': 980, 'playtimeLabel': '16h', 'image': 'https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/header.jpg'},
        {'appid': '1817070', 'name': 'Marvel\'s Spider-Man', 'playtime': 540, 'playtimeLabel': '9h', 'image': 'https://cdn.cloudflare.steamstatic.com/steam/apps/1817070/header.jpg'},
        {'appid': '1593500', 'name': 'God of War', 'playtime': 720, 'playtimeLabel': '12h', 'image': 'https://cdn.cloudflare.steamstatic.com/steam/apps/1593500/header.jpg'},
    ]
    return {'games': items, 'source': 'preview', 'count': len(items)}


def get_steam_games(limit=8):
    root = _steam_root()
    if not root:
        data = mock_steam_games()
        lutris = get_lutris_games(2)
        if lutris:
            data['games'] = lutris + data['games']
            data['count'] = len(data['games'])
        return data

    games = []
    for lib in _steam_libraries(root):
        for manifest in lib.glob('appmanifest_*.acf'):
            try:
                text = manifest.read_text(encoding='utf-8', errors='ignore')
            except OSError:
                continue
            appid = _acf_field(text, 'appid')
            name = _acf_field(text, 'name')
            if not appid or not name:
                continue
            if _acf_field(text, 'installdir') == '' and 'Updating' not in text:
                pass
            try:
                last_updated = int(_acf_field(text, 'LastUpdated', '0') or '0')
            except ValueError:
                last_updated = 0
            try:
                playtime = int(_acf_field(text, 'playtime_forever', '0') or '0')
            except ValueError:
                playtime = 0
            games.append({
                'appid': appid,
                'name': name,
                'playtime': playtime,
                'playtimeLabel': _format_playtime(playtime),
                'lastUpdated': last_updated,
                'image': _game_image_url(appid, root),
            })

    games.sort(key=lambda g: (g.get('lastUpdated', 0), g.get('playtime', 0)), reverse=True)
    seen = set()
    unique = []
    for g in games:
        if g['appid'] in seen:
            continue
        seen.add(g['appid'])
        unique.append(g)
    items = unique[:limit]
    lutris = get_lutris_games(3)
    merged = []
    seen_ids = set()
    for g in lutris + items:
        if g['appid'] in seen_ids:
            continue
        seen_ids.add(g['appid'])
        merged.append(g)
    items = merged[:limit]
    return {'games': items, 'source': 'steam', 'count': len(items)}


def launch_steam_game(appid: str):
    appid = re.sub(r'\D', '', str(appid))
    if not appid:
        return {'ok': False, 'error': 'invalid appid'}
    if shutil.which('steam'):
        subprocess.Popen(
            ['steam', '-applaunch', appid],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return {'ok': True, 'appid': appid}
    return {'ok': False, 'error': 'steam not found'}


def launch_game(appid: str, slug: str = ''):
    appid = str(appid)
    if appid.startswith('lutris-'):
        target = slug or appid.replace('lutris-', '')
        if shutil.which('lutris'):
            subprocess.Popen(
                ['lutris', target],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return {'ok': True, 'lutris': target}
        return {'ok': False, 'error': 'lutris not found'}
    return launch_steam_game(appid)


def get_game_image_path(appid: str) -> Optional[Path]:
    appid = re.sub(r'\D', '', str(appid))
    root = _steam_root()
    if not root or not appid:
        return None
    cache = root / 'appcache' / 'librarycache'
    for name in (f'{appid}_library_600x900.jpg', f'{appid}_header.jpg', f'{appid}_logo.png'):
        f = cache / name
        if f.is_file():
            return f
    return None


USAGE_LOG = HATAN_DIR / 'config' / 'usage-log.json'


def _toggle_radio(radio: str):
    import shutil
    if not shutil.which('nmcli'):
        return {'ok': False, 'radio': radio}
    state = _run(['nmcli', 'radio', radio]).lower()
    on = not ('enabled' in state or 'yes' in state)
    _run(['nmcli', 'radio', radio, 'on' if on else 'off'])
    return {'ok': True, 'radio': radio, 'enabled': on}


def toggle_keyboard_layout():
    import shutil
    layouts = load_settings().get('keyboardLayouts', ['ar', 'us'])
    if shutil.which('setxkbmap'):
        current = _run(['setxkbmap', '-query'])
        cur = 'us'
        if 'layout:' in current:
            cur = current.split('layout:')[-1].split('\n')[0].strip()
        nxt = layouts[(layouts.index(cur) + 1) % len(layouts)] if cur in layouts else layouts[0]
        _run(['setxkbmap', nxt])
        save_settings({'keyboard': nxt})
        return {'ok': True, 'layout': nxt}
    return {'ok': False}


def log_usage(event: str = 'button-shortcut'):
    USAGE_LOG.parent.mkdir(parents=True, exist_ok=True)
    from datetime import datetime, timezone
    entries = []
    if USAGE_LOG.is_file():
        try:
            entries = json.loads(USAGE_LOG.read_text(encoding='utf-8'))
        except json.JSONDecodeError:
            entries = []
    entries.append({
        'time': datetime.now(timezone.utc).isoformat(),
        'event': event,
        'device': load_settings().get('deviceName', 'Steam Deck'),
    })
    entries = entries[-500:]
    USAGE_LOG.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding='utf-8')
    return {'ok': True, 'count': len(entries)}


def take_screenshot():
    import shutil
    out_dir = HATAN_DIR / 'screenshots'
    out_dir.mkdir(parents=True, exist_ok=True)
    from datetime import datetime
    fname = out_dir / f"hatan-{datetime.now().strftime('%Y%m%d-%H%M%S')}.png"
    if shutil.which('grim'):
        _run(['grim', str(fname)])
        return {'ok': True, 'path': str(fname)}
    if shutil.which('scrot'):
        _run(['scrot', str(fname)])
        return {'ok': True, 'path': str(fname)}
    return {'ok': False}


def execute_shortcut(action: str):
    action = action.strip().lower()
    settings = load_settings()

    if action == 'toggle-wifi':
        return _toggle_radio('wifi')
    if action == 'toggle-bluetooth':
        return _toggle_radio('bluetooth')
    if action == 'toggle-keyboard':
        return toggle_keyboard_layout()
    if action == 'log-usage':
        return log_usage()
    if action == 'screenshot':
        return take_screenshot()
    if action == 'volume-up':
        return {'ok': True, 'volume': set_volume(settings.get('volume', 75) + 5)}
    if action == 'volume-down':
        return {'ok': True, 'volume': set_volume(settings.get('volume', 75) - 5)}
    if action == 'brightness-up':
        return {'ok': True, 'brightness': set_brightness(settings.get('brightness', 80) + 5)}
    if action == 'brightness-down':
        return {'ok': True, 'brightness': set_brightness(settings.get('brightness', 80) - 5)}
    return {'ok': False, 'action': action}


# ── تصوير الشاشة (فيديو) ─────────────────────────────

CAPTURE_FILE = HATAN_DIR / 'config' / 'capture-settings.json'
CAPTURE_LISTEN_FLAG = Path('/tmp/hatan-capture-listen.flag')
CAPTURE_STATUS_FILE = Path('/tmp/hatan-capture-status.json')
CAPTURE_DAEMON_PID = Path('/tmp/hatan-capture.pid')

DEFAULT_CAPTURE = {
    'enabled': True,
    'recordButton': 'R4',
    'includeAudio': True,
    'quality': 'native',
    'mode': 'video',
    'outputDir': 'Videos/HATAN',
}


def load_capture_settings():
    data = dict(DEFAULT_CAPTURE)
    if CAPTURE_FILE.is_file():
        try:
            data.update(json.loads(CAPTURE_FILE.read_text(encoding='utf-8')))
        except json.JSONDecodeError:
            pass
    return data


def save_capture_settings(patch: dict):
    current = load_capture_settings()
    current.update(patch)
    CAPTURE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CAPTURE_FILE.write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding='utf-8')
    _reload_capture_daemon()
    return current


def _reload_capture_daemon():
    if CAPTURE_DAEMON_PID.is_file():
        try:
            import signal
            pid = int(CAPTURE_DAEMON_PID.read_text().strip())
            os.kill(pid, signal.SIGHUP)
        except (OSError, ValueError):
            pass


def get_capture_status():
    cfg = load_capture_settings()
    status = {
        'daemon': CAPTURE_DAEMON_PID.is_file(),
        'enabled': cfg.get('enabled', True),
        'recordButton': cfg.get('recordButton', 'R4'),
        'listening': CAPTURE_LISTEN_FLAG.is_file(),
        'recording': False,
        'includeAudio': cfg.get('includeAudio', True),
        'quality': cfg.get('quality', 'native'),
    }
    if CAPTURE_STATUS_FILE.is_file():
        try:
            status.update(json.loads(CAPTURE_STATUS_FILE.read_text(encoding='utf-8')))
        except json.JSONDecodeError:
            pass
    pidfile = Path('/tmp/hatan-recording.pid')
    if pidfile.is_file():
        try:
            pid = int(pidfile.read_text().strip())
            os.kill(pid, 0)
            status['recording'] = True
        except (OSError, ValueError):
            pass
    return status


def start_capture_listen():
    CAPTURE_LISTEN_FLAG.write_text('1', encoding='utf-8')
    return get_capture_status()


def stop_capture_listen():
    CAPTURE_LISTEN_FLAG.unlink(missing_ok=True)
    return get_capture_status()


def toggle_capture_recording():
    script = HATAN_DIR / 'scripts' / 'hat-record-toggle.sh'
    cfg = load_capture_settings()
    env = os.environ.copy()
    env['HATAN_CAPTURE_AUDIO'] = '1' if cfg.get('includeAudio', True) else '0'
    env['HATAN_OUTPUT_DIR'] = cfg.get('outputDir', 'Videos/HATAN')
    if script.is_file():
        subprocess.run(['bash', str(script), 'toggle'], env=env, capture_output=True, text=True)
    return get_capture_status()


def list_recordings():
    cfg = load_capture_settings()
    out_dir = Path.home() / cfg.get('outputDir', 'Videos/HATAN')
    hat_dir = HATAN_DIR / 'recordings'
    items = []
    for base in (out_dir, hat_dir):
        if not base.is_dir():
            continue
        for f in sorted(base.glob('hatan-*.mp4'), reverse=True):
            try:
                stat = f.stat()
                items.append({
                    'name': f.name,
                    'path': str(f),
                    'size': _fmt_size(stat.st_size),
                    'mtime': stat.st_mtime,
                })
            except OSError:
                continue
    items.sort(key=lambda x: x['mtime'], reverse=True)
    return items[:20]


def _fmt_size(n: int) -> str:
    for unit in ('B', 'KB', 'MB', 'GB'):
        if n < 1024:
            return f'{n:.0f} {unit}' if unit == 'B' else f'{n:.1f} {unit}'
        n /= 1024
    return f'{n:.1f} TB'


def get_capture_state():
    return {
        'settings': load_capture_settings(),
        'status': get_capture_status(),
        'recordings': list_recordings(),
        'buttons': [b['id'] for b in _deck_button_ids()],
    }


def _deck_button_ids():
    return [
        {'id': 'A'}, {'id': 'B'}, {'id': 'X'}, {'id': 'Y'},
        {'id': 'L1'}, {'id': 'R1'}, {'id': 'L2'}, {'id': 'R2'},
        {'id': 'L3'}, {'id': 'R3'}, {'id': 'L4'}, {'id': 'R4'},
        {'id': 'SELECT'}, {'id': 'START'}, {'id': 'STEAM'}, {'id': 'QAM'},
        {'id': 'DPAD_UP'}, {'id': 'DPAD_DOWN'}, {'id': 'DPAD_LEFT'}, {'id': 'DPAD_RIGHT'},
    ]


def mock_capture_state():
    cfg = load_capture_settings()
    return {
        'settings': cfg,
        'status': {
            'daemon': platform.system() != 'Linux',
            'enabled': cfg.get('enabled', True),
            'recordButton': cfg.get('recordButton', 'R4'),
            'listening': False,
            'recording': False,
            'includeAudio': cfg.get('includeAudio', True),
            'preview': platform.system() != 'Linux',
        },
        'recordings': list_recordings() if list_recordings() else [
            {'name': 'hatan-preview-demo.mp4', 'path': '', 'size': '—', 'mtime': 0},
        ],
        'buttons': [b['id'] for b in _deck_button_ids()],
    }


def mock_state():
    devs = mock_connected_devices()
    return {
        'settings': load_settings(),
        'network': {
            'wifi': {'enabled': True, 'connected': 'Home-WiFi-5G'},
            'bluetooth': {'enabled': True, 'devices': devs['bluetooth']},
            'vpn': {'active': '—'},
            'usb': devs['usb'],
            'connected': devs['all'],
        },
        'audio': mock_audio_devices(),
        'devices': devs,
        'storage': [
            {'mount': '/', 'size': '512G', 'used': '48G', 'free': '440G', 'percent': '10'},
            {'mount': '/home', 'size': '512G', 'used': '32G', 'free': '440G', 'percent': '7'},
        ],
        'system': {
            'deviceName': load_settings().get('deviceName'),
            'system': 'HATAN OS',
            'version': _read_version(),
            'codename': 'Genesis',
            'kernel': 'linux-neptune (preview)',
            'hostname': 'steam-deck',
            'cpu': 'AMD Zen 2 APU',
            'gpu': 'AMD Van Gogh',
            'ram': '16 GB',
            'storage': {'mount': '/', 'size': '512G', 'used': '48G', 'free': '440G', 'percent': '10'},
            'display': '1280 × 800 LCD',
            'platform': 'Linux',
            'arch': 'x86_64',
        },
        'themes': THEMES,
        'wallpapers': get_wallpapers(),
        'status': get_status(),
        'updates': check_updates(),
    }
