#!/usr/bin/env python3
# HATAN OS — خادم الواجهة + API

import json
import os
import platform
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import hat_api

PORT = int(os.environ.get('HATAN_SHELL_PORT', '8765'))
SHELL_DIR = Path(__file__).resolve().parent
HAT_SHELL = Path('/usr/local/bin/hatan-shell')
HATAN_DIR = Path(os.environ.get('HATAN_DIR', SHELL_DIR.parent.parent))
hat_api.HATAN_DIR = HATAN_DIR if HATAN_DIR.is_dir() else hat_api.HATAN_DIR
hat_api.SETTINGS_FILE = hat_api.HATAN_DIR / 'config' / 'user-settings.json'
hat_api.WALLPAPER_DIR = hat_api.HATAN_DIR / 'themes' / 'wallpapers'


class ShellHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(SHELL_DIR), **kwargs)

    def log_message(self, fmt, *args):
        pass

    def send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json_body(self):
        length = int(self.headers.get('Content-Length', 0))
        if not length:
            return {}
        return json.loads(self.rfile.read(length).decode('utf-8'))

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/games':
            try:
                self.send_json(hat_api.get_steam_games())
            except Exception:
                self.send_json(hat_api.mock_steam_games())
            return

        if path == '/api/status':
            try:
                self.send_json(hat_api.get_status())
            except Exception:
                self.send_json(hat_api.mock_status())
            return

        if path == '/api/wifi/networks':
            try:
                self.send_json({'networks': hat_api.get_wifi_networks()})
            except Exception:
                self.send_json({'networks': hat_api.get_wifi_networks()})
            return

        if path == '/api/updates':
            try:
                self.send_json(hat_api.check_updates())
            except Exception:
                self.send_json({'available': 0, 'preview': True, 'packages': []})
            return

        if path.startswith('/api/game-image/'):
            appid = path.split('/')[-1]
            fpath = hat_api.get_game_image_path(appid)
            if fpath and fpath.is_file():
                data = fpath.read_bytes()
                ext = fpath.suffix.lower()
                ctype = 'image/jpeg' if ext in ('.jpg', '.jpeg') else 'image/png'
                self.send_response(200)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            self.send_error(404)
            return

        if path == '/api/launch':
            qs = parse_qs(parsed.query)
            app_id = qs.get('app', [''])[0]
            steam_id = qs.get('steam', [''])[0]
            game_id = qs.get('game', [''])[0]
            lutris_slug = qs.get('slug', [''])[0]
            if game_id:
                hat_api.launch_game(game_id, lutris_slug)
            elif steam_id:
                hat_api.launch_steam_game(steam_id)
            elif app_id and app_id not in ('settings', 'capture'):
                self.launch_app(app_id)
            self.send_response(204)
            self.end_headers()
            return

        if path == '/api/settings':
            if platform.system() != 'Linux':
                self.send_json(hat_api.mock_state())
            else:
                try:
                    self.send_json(hat_api.get_full_state())
                except Exception:
                    self.send_json(hat_api.mock_state())
            return

        if path == '/api/capture':
            try:
                self.send_json(hat_api.get_capture_state())
            except Exception:
                self.send_json(hat_api.mock_capture_state())
            return

        if path.startswith('/api/wallpaper/'):
            name = path.split('/')[-1]
            fpath = hat_api.WALLPAPER_DIR / name
            if fpath.is_file():
                data = fpath.read_bytes()
                ext = fpath.suffix.lower()
                ctype = 'image/png' if ext == '.png' else 'image/jpeg'
                self.send_response(200)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            self.send_error(404)
            return

        super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == '/api/system':
            body = self.read_json_body()
            action = body.get('action', '')
            try:
                if action in ('suspend', 'reboot', 'shutdown'):
                    result = hat_api.system_power(action)
                elif action == 'update':
                    result = hat_api.run_system_update()
                elif action == 'update-check':
                    result = hat_api.check_updates()
                else:
                    result = {'ok': False, 'error': 'unknown action'}
            except Exception:
                result = {'ok': True, 'preview': True, 'action': action}
            self.send_json(result)
            return

        if parsed.path == '/api/wifi/connect':
            body = self.read_json_body()
            try:
                result = hat_api.wifi_connect(body.get('ssid', ''), body.get('password', ''))
            except Exception:
                result = {'ok': True, 'preview': True}
            self.send_json(result)
            return

        if parsed.path == '/api/settings':
            try:
                patch = self.read_json_body()
                state = hat_api.apply_settings_patch(patch)
            except Exception:
                patch = self.read_json_body()
                hat_api.save_settings(patch)
                state = hat_api.mock_state()
            self.send_json(state)
            return

        if parsed.path == '/api/capture':
            body = self.read_json_body()
            action = body.get('action', 'save')
            try:
                if action == 'save':
                    patch = body.get('settings', body)
                    patch = {k: v for k, v in patch.items() if k not in ('action', 'settings')}
                    hat_api.save_capture_settings(patch)
                    result = hat_api.get_capture_state()
                elif action == 'listen':
                    result = {'status': hat_api.start_capture_listen()}
                elif action == 'listen-stop':
                    result = {'status': hat_api.stop_capture_listen()}
                elif action == 'toggle':
                    result = {'status': hat_api.toggle_capture_recording()}
                elif action == 'status':
                    result = {'status': hat_api.get_capture_status()}
                else:
                    result = hat_api.get_capture_state()
            except Exception:
                patch = body.get('settings', body)
                if patch:
                    hat_api.save_capture_settings(patch)
                result = hat_api.mock_capture_state()
            self.send_json(result)
            return

        if parsed.path == '/api/shortcut':
            body = self.read_json_body()
            action = body.get('action', '')
            try:
                result = hat_api.execute_shortcut(action)
            except Exception:
                result = {'ok': True, 'preview': True, 'action': action}
            self.send_json(result)
            return

        if parsed.path == '/api/audio/default':
            body = self.read_json_body()
            try:
                result = hat_api.set_default_audio(body.get('kind', 'output'), body.get('id', ''))
            except Exception:
                result = hat_api.mock_audio_devices()
            self.send_json(result)
            return

        if parsed.path == '/api/devices/connect':
            body = self.read_json_body()
            try:
                result = hat_api.connect_device(body.get('type', ''), body.get('id', ''))
                result['devices'] = hat_api.get_connected_devices()
                result['network'] = hat_api.get_network()
                result['audio'] = hat_api.get_audio_devices()
            except Exception:
                result = {'ok': True, 'preview': True}
            self.send_json(result)
            return

        if parsed.path == '/api/devices/scan':
            body = self.read_json_body()
            try:
                result = hat_api.scan_devices(body.get('type', 'bluetooth'))
            except Exception:
                result = {'ok': True, 'devices': hat_api.mock_connected_devices()['bluetooth']}
            self.send_json(result)
            return

        if parsed.path == '/api/network/toggle':
            body = self.read_json_body()
            radio = body.get('radio', 'wifi')
            import subprocess
            import shutil
            if shutil.which('nmcli'):
                subprocess.run(['nmcli', 'radio', radio, 'on' if body.get('on') else 'off'],
                               capture_output=True)
            self.send_json(hat_api.get_network())
            return

        if parsed.path == '/api/network/open':
            body = self.read_json_body()
            tool = body.get('tool', 'wifi')
            cmds = {
                'wifi': ['nm-connection-editor'],
                'bluetooth': ['blueman-manager'],
                'vpn': ['nm-connection-editor'],
            }
            import subprocess
            for cmd in cmds.get(tool, ['nm-connection-editor']):
                try:
                    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    break
                except Exception:
                    continue
            self.send_response(204)
            self.end_headers()
            return

        self.send_error(404)

    def launch_app(self, app_id: str):
        import subprocess
        if HAT_SHELL.is_file():
            subprocess.Popen([str(HAT_SHELL), 'launch', app_id],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            local = SHELL_DIR / 'hat-shell.sh'
            if local.is_file():
                subprocess.Popen(['bash', str(local), 'launch', app_id],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    os.environ.setdefault('HATAN_DIR', str(HATAN_DIR))
    print(f'[HATAN OS] Shell: http://127.0.0.1:{PORT}')
    HTTPServer(('127.0.0.1', PORT), ShellHandler).serve_forever()


if __name__ == '__main__':
    main()
