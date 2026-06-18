#!/usr/bin/env python3
# HATAN OS — معاينة داخل نافذة التطبيق (بدون متصفح)

import importlib.util
import os
import subprocess
import sys
import threading
import time
from http.server import HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOT_DIR = ROOT / 'ui' / 'boot'
PORT = int(os.environ.get('HATAN_BOOT_PORT', '8765'))


def ensure_webview():
    try:
        import webview
        return webview
    except ImportError:
        print('[HATAN OS] Installing preview window (pywebview)...')
        subprocess.check_call(
            [sys.executable, '-m', 'pip', 'install', 'pywebview', '-q'],
            stdout=subprocess.DEVNULL,
        )
        import webview
        return webview


def load_handler():
    path = BOOT_DIR / 'boot-server.py'
    spec = importlib.util.spec_from_file_location('hatan_boot_server', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.BootHandler


def main():
    if not (BOOT_DIR / 'index.html').is_file():
        print(f'Error: {BOOT_DIR / "index.html"} not found', file=sys.stderr)
        sys.exit(1)

    webview = ensure_webview()
    os.environ['HATAN_BOOT_PORT'] = str(PORT)

    httpd = HTTPServer(('127.0.0.1', PORT), load_handler())
    server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    server_thread.start()
    time.sleep(0.5)

    url = f'http://127.0.0.1:{PORT}/index.html'
    print(f'[HATAN OS] Preview window: {url}')

    webview.create_window(
        title='HATAN OS',
        url=url,
        width=1280,
        height=800,
        resizable=False,
        fullscreen=True,
        background_color='#000000',
        text_select=False,
    )
    webview.start()
    httpd.shutdown()


if __name__ == '__main__':
    main()
