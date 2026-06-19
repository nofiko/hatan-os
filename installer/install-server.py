#!/usr/bin/env python3
# HATAN OS — خادم المثبّت الرسومي

import json
import os
import re
import subprocess
import sys
import tempfile
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get('HATAN_INSTALL_PORT', '8766'))
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
UI_DIR = PROJECT_DIR / 'ui' / 'installer'
INSTALL_SCRIPT = SCRIPT_DIR / 'install.sh'
ISO_INSTALL_SCRIPT = SCRIPT_DIR / 'iso-install.sh'
LIVE_INSTALL_SCRIPT = SCRIPT_DIR / 'live-install.sh'
IS_LIVE_ISO = (
    os.environ.get('HATAN_ISO_LIVE') == '1'
    or Path('/etc/hatan/iso-live').is_file()
)
FROM_FILES = os.environ.get('HATAN_FROM_FILES') == '1'
RUNTIME_DIR = Path(os.environ.get('HATAN_RUNTIME_DIR', tempfile.gettempdir()))
LOG_FILE = RUNTIME_DIR / 'hatan-install.log'
PROGRESS_FILE = RUNTIME_DIR / 'hatan-install-progress.json'

install_lock = threading.Lock()
install_running = False
install_process = None


def _run(cmd, timeout=12):
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def prepare_wifi():
    _run(['rfkill', 'unblock', 'wifi'], timeout=5)
    _run(['rfkill', 'unblock', 'all'], timeout=5)
    _run(['systemctl', 'start', 'iwd'], timeout=8)
    _run(['systemctl', 'start', 'NetworkManager'], timeout=8)
    _run(['nmcli', 'radio', 'wifi', 'on'], timeout=5)
    _run(['nmcli', 'device', 'wifi', 'rescan'], timeout=10)


def get_wifi():
    r = _run(['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL', 'dev', 'wifi'])
    if not r or r.returncode != 0:
        return {'connected': False, 'ssid': '', 'strength': 0}
    for line in r.stdout.splitlines():
        parts = line.split(':')
        if len(parts) >= 3 and parts[0] == 'yes':
            try:
                strength = int(parts[2] or 0)
            except ValueError:
                strength = 0
            return {'connected': True, 'ssid': parts[1], 'strength': strength}
    return {'connected': False, 'ssid': '', 'strength': 0}


def wifi_scan():
    prepare_wifi()
    r = _run(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'], timeout=15)
    if not r or r.returncode != 0:
        return []
    seen = set()
    networks = []
    for line in r.stdout.splitlines():
        parts = line.split(':')
        if len(parts) < 4:
            continue
        in_use, ssid, signal, security = parts[0], parts[1], parts[2], parts[3]
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
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


def wifi_connect(ssid: str, password: str):
    prepare_wifi()
    cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid]
    if password:
        cmd += ['password', password]
    r = _run(cmd, timeout=25)
    if not r:
        return False, 'انتهت المهلة'
    if r.returncode != 0:
        err = (r.stderr or r.stdout or '').strip().splitlines()
        return False, err[-1] if err else 'فشل الاتصال'
    return True, ''


def has_internet() -> bool:
    for host in ('steamdeck-packages.steamos.cloud', 'archlinux.org', '1.1.1.1'):
        r = _run(['ping', '-c1', '-W2', host], timeout=5)
        if r and r.returncode == 0:
            return True
    return False


def is_root() -> bool:
    if hasattr(os, 'geteuid'):
        return os.geteuid() == 0
    return False


def write_progress(step: str, percent: int, status: str = 'running', done: bool = False):
    data = {'step': step, 'percent': percent, 'status': status, 'done': done}
    PROGRESS_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')


def classify_line(line: str) -> str:
    if '[خطأ]' in line or 'error' in line.lower():
        return 'err'
    if '[تحذير]' in line or 'warn' in line.lower() or 'فشل' in line:
        return 'warn'
    if '==>' in line or '[HATAN OS]' in line:
        return 'step'
    if '✅' in line or 'اكتمل' in line:
        return 'ok'
    return ''


def strip_ansi(text: str) -> str:
    return re.sub(r'\x1b\[[0-9;]*m', '', text)


def run_install(options: dict):
    global install_running, install_process

    with install_lock:
        if install_running:
            return
        install_running = True

    LOG_FILE.write_text('', encoding='utf-8')
    write_progress('بدء التثبيت', 0)

    env = os.environ.copy()
    env['HATAN_GUI'] = '1'
    env['HATAN_NONINTERACTIVE'] = '1'
    env['HATAN_INSTALL_RECOMMENDED'] = '1' if options.get('recommended') else '0'
    env['HATAN_USERNAME'] = options.get('username', 'deck')
    env['HATAN_PROGRESS_FILE'] = str(PROGRESS_FILE)
    env['HATAN_LOG_FILE'] = str(LOG_FILE)
    env['HATAN_PROJECT_DIR'] = str(PROJECT_DIR)

    script = INSTALL_SCRIPT
    if FROM_FILES and LIVE_INSTALL_SCRIPT.is_file():
        script = LIVE_INSTALL_SCRIPT
        env['HATAN_PROJECT_DIR'] = str(PROJECT_DIR)
    elif IS_LIVE_ISO and ISO_INSTALL_SCRIPT.is_file():
        script = ISO_INSTALL_SCRIPT

    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as log:
            install_process = subprocess.Popen(
                ['bash', str(script)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=env,
                cwd=str(SCRIPT_DIR),
                text=True,
                bufsize=1,
            )
            for line in install_process.stdout:
                clean = strip_ansi(line.rstrip())
                if clean:
                    log.write(clean + '\n')
                    log.flush()

            code = install_process.wait()
            if code == 0:
                write_progress('اكتمل التثبيت', 100, 'success', True)
            else:
                write_progress('فشل التثبيت', 100, 'error', True)
    except Exception as exc:
        with open(LOG_FILE, 'a', encoding='utf-8') as log:
            log.write(f'خطأ: {exc}\n')
        write_progress(f'خطأ: {exc}', 100, 'error', True)
    finally:
        install_running = False
        install_process = None


class InstallerHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def log_message(self, fmt, *args):
        pass

    def send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == '/api/check':
            live = IS_LIVE_ISO or Path('/etc/hatan/iso-live').is_file()
            wifi = get_wifi()
            self.send_json({
                'root': is_root() or live,
                'liveIso': live,
                'fromFiles': FROM_FILES,
                'dualBoot': os.environ.get('HATAN_DUAL_BOOT', '0') == '1',
                'targetDisk': os.environ.get('HATAN_TARGET_DISK', '/dev/nvme0n1'),
                'wifi': wifi,
                'online': has_internet() if live else True,
            })
            return

        if parsed.path == '/api/wifi/status':
            self.send_json({
                'wifi': get_wifi(),
                'online': has_internet(),
            })
            return

        if parsed.path == '/api/wifi/scan':
            self.send_json({'networks': wifi_scan()})
            return

        if parsed.path == '/api/status':
            if PROGRESS_FILE.exists():
                try:
                    self.send_json(json.loads(PROGRESS_FILE.read_text(encoding='utf-8')))
                except json.JSONDecodeError:
                    self.send_json({'step': '...', 'percent': 0, 'done': False})
            else:
                self.send_json({'step': 'في الانتظار', 'percent': 0, 'done': False})
            return

        if parsed.path == '/api/logs':
            offset = int(parse_qs(parsed.query).get('offset', ['0'])[0])
            lines = []
            if LOG_FILE.exists():
                text = LOG_FILE.read_text(encoding='utf-8', errors='replace')
                all_lines = text.splitlines()
                for i, line in enumerate(all_lines[offset:], start=offset):
                    if line.strip():
                        lines.append({'text': line, 'type': classify_line(line)})
                offset = len(all_lines)
            self.send_json({'lines': lines, 'offset': offset})
            return

        if parsed.path.startswith('/assets/') or parsed.path.startswith('../shell/'):
            rel = parsed.path.lstrip('/')
            if rel.startswith('assets/'):
                target = UI_DIR / rel
            else:
                target = PROJECT_DIR / 'ui' / rel.replace('../', '')
            if target.is_file():
                self.send_response(200)
                ext = target.suffix.lower()
                ctype = 'image/png' if ext == '.png' else 'application/octet-stream'
                self.send_header('Content-Type', ctype)
                data = target.read_bytes()
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return

        super().do_GET()

    def do_POST(self):
        global install_running

        if self.path == '/api/wifi/connect':
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length) if length else b'{}'
            try:
                data = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError:
                self.send_json({'error': 'طلب غير صالح'}, 400)
                return
            ssid = (data.get('ssid') or '').strip()
            if not ssid:
                self.send_json({'error': 'اسم الشبكة مطلوب'}, 400)
                return
            ok, err = wifi_connect(ssid, data.get('password') or '')
            if ok:
                self.send_json({
                    'ok': True,
                    'wifi': get_wifi(),
                    'online': has_internet(),
                })
            else:
                self.send_json({'error': err or 'فشل الاتصال'}, 400)
            return

        if self.path == '/api/install':
            live = IS_LIVE_ISO or Path('/etc/hatan/iso-live').is_file()
            if not is_root() and not live:
                self.send_json({'error': 'يتطلب صلاحيات root'}, 403)
                return
            if live and not has_internet():
                self.send_json({'error': 'يتطلب اتصال إنترنت — اتصل بالواي فاي أولاً'}, 400)
                return
            if install_running:
                self.send_json({'error': 'التثبيت قيد التشغيل'}, 409)
                return

            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length) if length else b'{}'
            try:
                options = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError:
                self.send_json({'error': 'طلب غير صالح'}, 400)
                return

            threading.Thread(target=run_install, args=(options,), daemon=True).start()
            self.send_json({'started': True})
            return

        if self.path == '/api/reboot':
            if not is_root():
                self.send_json({'error': 'يتطلب صلاحيات root'}, 403)
                return
            subprocess.Popen(['reboot'])
            self.send_json({'rebooting': True})
            return

        self.send_json({'error': 'غير موجود'}, 404)


def main():
    if not INSTALL_SCRIPT.is_file():
        print(f'خطأ: {INSTALL_SCRIPT} غير موجود', file=sys.stderr)
        sys.exit(1)

    if not UI_DIR.is_dir():
        print(f'خطأ: {UI_DIR} غير موجود', file=sys.stderr)
        sys.exit(1)

    write_progress('في الانتظار', 0)

    if IS_LIVE_ISO or Path('/etc/hatan/iso-live').is_file():
        prepare_wifi()

    print(f'[HATAN OS] Installer: http://127.0.0.1:{PORT}')
    server = HTTPServer(('127.0.0.1', PORT), InstallerHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[HATAN OS] Installer stopped')


if __name__ == '__main__':
    main()
