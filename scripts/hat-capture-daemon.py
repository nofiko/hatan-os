#!/usr/bin/env python3
# HATAN OS — خدمة اختصار تسجيل الشاشة (يعمل في النظام والألعاب والتطبيقات)

import glob
import json
import os
import select
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path

HATAN_DIR = Path(os.environ.get('HATAN_DIR', '/opt/hatan-os'))
CAPTURE_FILE = HATAN_DIR / 'config' / 'capture-settings.json'
LISTEN_FLAG = Path('/tmp/hatan-capture-listen.flag')
STATUS_FILE = Path('/tmp/hatan-capture-status.json')
PID_FILE = Path('/tmp/hatan-capture.pid')

EV_KEY = 0x01
EVENT_FORMAT = 'llHHi'
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

BTN_CODE_TO_ID = {
    304: 'A', 305: 'B', 307: 'Y', 308: 'X',
    310: 'L1', 311: 'R1', 312: 'L2', 313: 'R2',
    314: 'SELECT', 315: 'START',
    317: 'L3', 318: 'R3',
    544: 'DPAD_UP', 545: 'DPAD_DOWN', 546: 'DPAD_LEFT', 547: 'DPAD_RIGHT',
    704: 'L4', 705: 'R4',
}

DEFAULT_CAPTURE = {
    'enabled': True,
    'recordButton': 'R4',
    'includeAudio': True,
    'quality': 'native',
    'mode': 'video',
}


def load_capture():
    data = dict(DEFAULT_CAPTURE)
    if CAPTURE_FILE.is_file():
        try:
            data.update(json.loads(CAPTURE_FILE.read_text(encoding='utf-8')))
        except json.JSONDecodeError:
            pass
    return data


def save_capture(patch: dict):
    current = load_capture()
    current.update(patch)
    CAPTURE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CAPTURE_FILE.write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding='utf-8')
    return current


def write_status(extra: dict | None = None):
    data = load_capture()
    status = {
        'daemon': True,
        'enabled': data.get('enabled', True),
        'recordButton': data.get('recordButton', 'R4'),
        'listening': LISTEN_FLAG.is_file(),
        'recording': False,
    }
    if STATUS_FILE.is_file():
        try:
            status.update(json.loads(STATUS_FILE.read_text(encoding='utf-8')))
        except json.JSONDecodeError:
            pass
    if extra:
        status.update(extra)
    STATUS_FILE.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding='utf-8')


def device_name(event_path: str) -> str:
    try:
        base = Path(event_path).name
        sysfs = Path(f'/sys/class/input/{base}/device/name')
        if sysfs.is_file():
            return sysfs.read_text(encoding='utf-8').strip()
    except OSError:
        pass
    return ''


def find_gamepad_nodes():
    nodes = []
    for path in sorted(glob.glob('/dev/input/event*')):
        name = device_name(path).lower()
        if not name:
            continue
        skip = ('mouse', 'keyboard', 'touchpad', 'touchscreen', 'power', 'sleep')
        if any(s in name for s in skip):
            continue
        keep = ('steam', 'gamepad', 'xbox', 'generic', 'controller', 'deck', 'js')
        if any(k in name for k in keep) or 'pad' in name:
            nodes.append(path)
    if not nodes:
        for path in sorted(glob.glob('/dev/input/event*')):
            try:
                with open(path, 'rb') as f:
                    pass
                nodes.append(path)
            except OSError:
                continue
            if len(nodes) >= 2:
                break
    return nodes


def toggle_recording(include_audio: bool = True):
    env = os.environ.copy()
    env['HATAN_CAPTURE_AUDIO'] = '1' if include_audio else '0'
    script = HATAN_DIR / 'scripts' / 'hat-record-toggle.sh'
    if script.is_file():
        subprocess.Popen(['bash', str(script), 'toggle'], env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.Popen(['bash', '-c', 'echo toggle'], env=env)


class CaptureDaemon:
    def __init__(self):
        self.fds = {}
        self.pressed = set()
        self.running = True

    def open_devices(self):
        self.close_devices()
        for node in find_gamepad_nodes():
            try:
                fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
                self.fds[fd] = node
            except OSError:
                continue
        write_status({'devices': len(self.fds)})

    def close_devices(self):
        for fd in self.fds:
            try:
                os.close(fd)
            except OSError:
                pass
        self.fds.clear()

    def handle_button(self, btn_id: str):
        cfg = load_capture()

        if LISTEN_FLAG.is_file():
            save_capture({'recordButton': btn_id})
            LISTEN_FLAG.unlink(missing_ok=True)
            write_status({'listening': False, 'recordButton': btn_id})
            self._notify(f'تم تعيين زر {btn_id} للتسجيل')
            return

        if not cfg.get('enabled', True):
            return

        target = cfg.get('recordButton', 'R4')
        if btn_id != target:
            return

        toggle_recording(cfg.get('includeAudio', True))

    def _notify(self, body: str):
        try:
            subprocess.Popen(['notify-send', '-a', 'HATAN OS', 'تصوير الشاشة', body],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def loop(self):
        PID_FILE.write_text(str(os.getpid()))
        write_status({'daemon': True})
        self.open_devices()
        last_reload = time.time()

        while self.running:
            if time.time() - last_reload > 3:
                cfg = load_capture()
                write_status({
                    'enabled': cfg.get('enabled', True),
                    'recordButton': cfg.get('recordButton', 'R4'),
                    'listening': LISTEN_FLAG.is_file(),
                })
                if not self.fds:
                    self.open_devices()
                last_reload = time.time()

            if not self.fds:
                time.sleep(1)
                self.open_devices()
                continue

            readable, _, _ = select.select(list(self.fds.keys()), [], [], 0.5)
            for fd in readable:
                while True:
                    try:
                        data = os.read(fd, EVENT_SIZE * 16)
                    except BlockingIOError:
                        break
                    except OSError:
                        break
                    if not data:
                        break
                    for i in range(0, len(data), EVENT_SIZE):
                        if i + EVENT_SIZE > len(data):
                            break
                        _sec, _usec, ev_type, code, value = struct.unpack(EVENT_FORMAT, data[i:i + EVENT_SIZE])
                        if ev_type != EV_KEY:
                            continue
                        btn_id = BTN_CODE_TO_ID.get(code)
                        if not btn_id:
                            continue
                        key = f'{fd}:{btn_id}'
                        if value == 1 and key not in self.pressed:
                            self.pressed.add(key)
                            self.handle_button(btn_id)
                        elif value == 0:
                            self.pressed.discard(key)

    def stop(self, *_args):
        self.running = False
        self.close_devices()
        PID_FILE.unlink(missing_ok=True)


def main():
    if os.geteuid() == 0:
        print('تحذير: يُفضّل تشغيل الخدمة كمستخدم deck', file=sys.stderr)
    daemon = CaptureDaemon()
    signal.signal(signal.SIGTERM, daemon.stop)
    signal.signal(SIGINT, daemon.stop)
    signal.signal(signal.SIGHUP, lambda *_: daemon.open_devices())
    try:
        daemon.loop()
    finally:
        daemon.close_devices()


if __name__ == '__main__':
    main()
