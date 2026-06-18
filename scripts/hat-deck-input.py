#!/usr/bin/env python3
# HATAN OS — أزرار Steam / QAM على مستوى النظام (evdev)

import os
import subprocess
import time
import urllib.request

PORT = os.environ.get('HATAN_SHELL_PORT', '8765')
API = f'http://127.0.0.1:{PORT}/api/shortcut'

STEAM_KEYS = {125, 209, 582}  # KEY_HOMEPAGE / Deck variants
QAM_KEYS = {580, 581}


def post_action(action: str):
    try:
        data = f'{{"action":"{action}"}}'.encode('utf-8')
        req = urllib.request.Request(
            API, data=data,
            headers={'Content-Type': 'application/json'},
            method='POST',
        )
        urllib.request.urlopen(req, timeout=2)
    except Exception:
        pass


def main():
    try:
        import evdev
        from evdev import ecodes, InputDevice, list_devices
    except ImportError:
        print('[hat-deck-input] evdev not installed — skip')
        return

    dev_path = None
    for path in list_devices():
        try:
            d = InputDevice(path)
            name = (d.name or '').lower()
            if 'steam' in name or 'gamepad' in name or 'deck' in name or 'anbernic' in name:
                dev_path = path
                break
        except Exception:
            continue

    if not dev_path:
        for path in list_devices():
            try:
                d = InputDevice(path)
                if ecodes.EV_KEY in d.capabilities():
                    dev_path = path
                    break
            except Exception:
                continue

    if not dev_path:
        print('[hat-deck-input] no input device found')
        return

    dev = InputDevice(dev_path)
    print(f'[hat-deck-input] listening on {dev.name} ({dev_path})')
    pressed = set()

    for event in dev.read_loop():
        if event.type != ecodes.EV_KEY:
            continue
        code, val = event.code, event.value
        if val != 1:
            if val == 0:
                pressed.discard(code)
            continue
        if code in pressed:
            continue
        pressed.add(code)
        if code in STEAM_KEYS:
            post_action('home')
        elif code in QAM_KEYS:
            post_action('options')

        time.sleep(0.05)


if __name__ == '__main__':
    main()
