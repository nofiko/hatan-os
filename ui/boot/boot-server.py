#!/usr/bin/env python3
# HATAN OS — خادم معاينة شاشة الإقلاع

import importlib.util
import json
import os
import platform
import re
import subprocess
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get('HATAN_BOOT_PORT', '8765'))
BOOT_DIR = Path(__file__).resolve().parent
BATTERY_LOW = 20


def _load_os_manager():
    path = BOOT_DIR / 'scripts' / 'os_manager.py'
    spec = importlib.util.spec_from_file_location('hatan_os_manager', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


OS_MANAGER = None


def os_manager():
    global OS_MANAGER
    if OS_MANAGER is None:
        OS_MANAGER = _load_os_manager()
    return OS_MANAGER


def _run(cmd, timeout=8):
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def get_battery_linux():
    supply = Path('/sys/class/power_supply')
    if not supply.is_dir():
        return None
    for bat in sorted(supply.glob('BAT*')):
        try:
            cap_path = bat / 'capacity'
            if not cap_path.is_file():
                continue
            level = int(cap_path.read_text().strip())
            status = (bat / 'status').read_text().strip() if (bat / 'status').is_file() else ''
            charging = status.lower() in ('charging', 'full')
            return {
                'level': level,
                'charging': charging,
                'low': level <= BATTERY_LOW,
            }
        except (OSError, ValueError):
            continue
    return None


def get_battery_windows():
    r = _run([
        'wmic', 'path', 'Win32_Battery',
        'get', 'EstimatedChargeRemaining,BatteryStatus', '/format:list',
    ])
    if not r or r.returncode != 0:
        return None
    level = None
    charging = False
    for line in r.stdout.splitlines():
        if 'EstimatedChargeRemaining=' in line:
            val = line.split('=', 1)[1].strip()
            if val.isdigit():
                level = int(val)
        if 'BatteryStatus=' in line:
            val = line.split('=', 1)[1].strip()
            if val.isdigit():
                charging = int(val) in (2, 6, 7, 8, 9)
    if level is None:
        return None
    return {
        'level': level,
        'charging': charging,
        'low': level <= BATTERY_LOW,
    }


def get_battery():
    if platform.system() == 'Windows':
        return get_battery_windows()
    return get_battery_linux()


def get_wifi_linux():
    r = _run(['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL', 'dev', 'wifi'])
    if not r or r.returncode != 0:
        return {'connected': False, 'ssid': '', 'strength': 0}
    for line in r.stdout.splitlines():
        parts = line.split(':')
        if len(parts) >= 3 and parts[0] == 'yes':
            ssid = parts[1]
            try:
                strength = int(parts[2] or 0)
            except ValueError:
                strength = 0
            return {'connected': True, 'ssid': ssid, 'strength': strength}
    return {'connected': False, 'ssid': '', 'strength': 0}


def get_wifi_windows():
    r = _run(['netsh', 'wlan', 'show', 'interfaces'])
    if not r or r.returncode != 0:
        return {'connected': False, 'ssid': '', 'strength': 0}
    ssid = ''
    strength = 0
    state = ''
    for line in r.stdout.splitlines():
        line = line.strip()
        low = line.lower()
        if low.startswith('state') or 'الحالة' in line:
            state = line.split(':', 1)[-1].strip().lower()
        if low.startswith('ssid') and 'bssid' not in low:
            ssid = line.split(':', 1)[-1].strip()
        if 'signal' in low or 'إشارة' in line:
            m = re.search(r'(\d+)\s*%', line)
            if m:
                strength = int(m.group(1))
    connected = 'connected' in state or 'متصل' in state
    if connected and not ssid:
        connected = False
    return {'connected': connected, 'ssid': ssid, 'strength': strength}


def get_wifi():
    if platform.system() == 'Windows':
        return get_wifi_windows()
    return get_wifi_linux()


def wifi_scan_linux():
    r = _run(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'])
    if not r or r.returncode != 0:
        return []
    networks = []
    for line in r.stdout.splitlines():
        parts = line.split(':')
        if len(parts) < 4:
            continue
        in_use, ssid, signal, security = parts[0], parts[1], parts[2], parts[3]
        if not ssid:
            continue
        try:
            sig = int(signal or 0)
        except ValueError:
            sig = 0
        networks.append({
            'ssid': ssid,
            'signal': sig,
            'secured': security not in ('', '--'),
            'active': in_use == '*',
        })
    networks.sort(key=lambda n: (-n['signal'], n['ssid']))
    return networks


def wifi_scan_windows():
    r = _run(['netsh', 'wlan', 'show', 'networks', 'mode=bssid'])
    if not r or r.returncode != 0:
        return []
    networks = []
    current = None
    for line in r.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith('SSID') and 'BSSID' not in line:
            if current and current.get('ssid'):
                networks.append(current)
            ssid = line.split(':', 1)[-1].strip()
            current = {'ssid': ssid, 'signal': 0, 'secured': True, 'active': False}
            continue
        if current is None:
            continue
        low = line.lower()
        if 'signal' in low or 'إشارة' in line:
            m = re.search(r'(\d+)\s*%', line)
            if m:
                current['signal'] = max(current['signal'], int(m.group(1)))
        if 'authentication' in low or 'مصادقة' in line:
            auth = line.split(':', 1)[-1].strip().lower()
            current['secured'] = auth not in ('open', 'none', 'مفتوح')
    if current and current.get('ssid'):
        networks.append(current)

    by_ssid = {}
    for n in networks:
        s = n['ssid']
        if s not in by_ssid or n['signal'] > by_ssid[s]['signal']:
            by_ssid[s] = n
    networks = list(by_ssid.values())

    active = get_wifi_windows()
    if active['connected']:
        for n in networks:
            if n['ssid'] == active['ssid']:
                n['active'] = True
                n['signal'] = max(n['signal'], active['strength'])
    networks.sort(key=lambda n: (-n['signal'], n['ssid']))
    return networks


def wifi_scan():
    if platform.system() == 'Windows':
        return wifi_scan_windows()
    return wifi_scan_linux()


def wifi_connect_linux(ssid, password):
    cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid]
    if password:
        cmd += ['password', password]
    r = _run(cmd, timeout=20)
    if not r:
        return False, 'timeout'
    if r.returncode != 0:
        err = (r.stderr or r.stdout or '').strip().splitlines()
        return False, err[-1] if err else 'failed'
    return True, ''


def _win_profile_xml(ssid, password):
    if password:
        return f'''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>{ssid}</name>
  <SSIDConfig><SSID><name>{ssid}</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM><security>
    <authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>{password}</keyMaterial></sharedKey>
  </security></MSM>
</WLANProfile>'''
    return f'''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>{ssid}</name>
  <SSIDConfig><SSID><name>{ssid}</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM><security><authEncryption><authentication>open</authentication><encryption>none</encryption><useOneX>false</useOneX></authEncryption></security></MSM>
</WLANProfile>'''


def wifi_connect_windows(ssid, password):
    profile = BOOT_DIR / '.wifi-profile-temp.xml'
    try:
        profile.write_text(_win_profile_xml(ssid, password), encoding='utf-8')
        add = _run(['netsh', 'wlan', 'add', 'profile', f'filename={profile}'], timeout=15)
        if not add or add.returncode != 0:
            err = (add.stderr or add.stdout or '').strip() if add else 'timeout'
            return False, err
        conn = _run(['netsh', 'wlan', 'connect', f'name={ssid}', f'ssid={ssid}'], timeout=20)
        if not conn or conn.returncode != 0:
            err = (conn.stderr or conn.stdout or '').strip() if conn else 'timeout'
            return False, err
        return True, ''
    finally:
        try:
            profile.unlink(missing_ok=True)
        except OSError:
            pass


def wifi_connect(ssid, password):
    ssid = (ssid or '').strip()
    if not ssid:
        return False, 'missing ssid'
    if platform.system() == 'Windows':
        return wifi_connect_windows(ssid, password or '')
    return wifi_connect_linux(ssid, password or '')


class BootHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BOOT_DIR), **kwargs)

    def log_message(self, fmt, *args):
        pass

    def end_headers(self):
        path = self.path.split('?', 1)[0]
        if path.endswith('.mp3'):
            self.send_header('Content-Type', 'audio/mpeg')
        elif path.endswith('.png'):
            self.send_header('Content-Type', 'image/png')
        elif path.endswith('.css'):
            self.send_header('Content-Type', 'text/css; charset=utf-8')
        elif path.endswith('.js'):
            self.send_header('Content-Type', 'application/javascript; charset=utf-8')
        super().end_headers()

    def _json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get('Content-Length', 0))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode('utf-8'))

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/api/status':
            battery = get_battery()
            wifi = get_wifi()
            return self._json(200, {
                'battery': battery,
                'wifi': wifi,
            })
        if path == '/api/wifi/scan':
            return self._json(200, {'networks': wifi_scan()})
        if path == '/api/os/status':
            return self._json(200, os_manager().get_os_status())
        if path == '/api/os/progress':
            return self._json(200, os_manager().get_progress())
        if self.path in ('/', '/index.html'):
            self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        if path == '/api/wifi/connect':
            try:
                data = self._read_json()
            except json.JSONDecodeError:
                return self._json(400, {'ok': False, 'error': 'invalid json'})
            ok, err = wifi_connect(data.get('ssid', ''), data.get('password', ''))
            if ok:
                return self._json(200, {'ok': True, 'wifi': get_wifi()})
            return self._json(500, {'ok': False, 'error': err})
        if path == '/api/os/launch':
            try:
                data = self._read_json()
            except json.JSONDecodeError:
                return self._json(400, {'ok': False, 'error': 'invalid json'})
            result = os_manager().launch_os(data.get('os', ''))
            code = 200 if result.get('ok') else 500
            return self._json(code, result)
        self.send_error(404)


def main():
    print(f'[HATAN OS] Boot preview: http://127.0.0.1:{PORT}/index.html')
    HTTPServer(('127.0.0.1', PORT), BootHandler).serve_forever()


if __name__ == '__main__':
    main()
