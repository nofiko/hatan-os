#!/usr/bin/env python3
# HATAN OS — اكتشاف مسارات Windows / SteamOS / المشروع

import json
import os
import platform
import re
import subprocess
from pathlib import Path

CONFIG_FILE = Path(__file__).resolve().parent.parent / 'config' / 'os-paths.json'


def _run(cmd, timeout=20):
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


def _load_config():
    if CONFIG_FILE.is_file():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding='utf-8'))
        except (OSError, json.JSONDecodeError):
            pass
    return {}


def _save_config(data):
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def _win_drives():
    drives = []
    for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
        root = Path(f'{letter}:/')
        if root.is_dir():
            drives.append(root)
    return drives


def discover_windows_source():
    cfg = _load_config()
    custom = cfg.get('windows', {}).get('source')
    if custom and Path(custom).is_dir():
        setup = Path(custom) / 'setup.exe'
        if setup.is_file():
            return str(Path(custom))

    env = os.environ.get('HATAN_WINDOWS_SOURCE')
    if env and Path(env).is_dir():
        return str(Path(env))

    for candidate in (
        Path('/var/lib/hatan/iso/windows'),
        Path('/run/media'),
    ):
        if candidate.is_dir() and (candidate / 'setup.exe').is_file():
            return str(candidate)

    if platform.system() == 'Windows':
        for root in _win_drives():
            setup = root / 'setup.exe'
            sources = root / 'sources'
            if setup.is_file() and sources.is_dir():
                return str(root)

    for candidate in (Path('/var/lib/hatan/iso/windows'), Path('/run/media')):
        if candidate.is_dir():
            if (candidate / 'setup.exe').is_file():
                return str(candidate)
            for child in candidate.iterdir():
                if child.is_dir() and (child / 'setup.exe').is_file():
                    return str(child)

    iso = Path(os.environ.get('HATAN_WINDOWS_ISO', '/var/lib/hatan/iso/windows.iso'))
    if iso.is_file():
        return str(iso.parent)

    return ''


def discover_steam_partsets():
    cfg = _load_config()
    custom = cfg.get('steam', {}).get('partsets')
    if custom:
        p = Path(custom)
        if (p / 'self').is_file():
            return str(p)

    env = os.environ.get('HATAN_STEAMOS_PARTSETS')
    if env and Path(env).is_dir():
        return env

    for candidate in (
        Path('/opt/hatan-os/media-ref/steamos/partsets'),
        Path('/var/lib/hatan/steamos/partsets'),
    ):
        if (candidate / 'self').is_file():
            return str(candidate)

    if platform.system() == 'Windows':
        for root in _win_drives():
            p = root / 'SteamOS' / 'partsets'
            if (p / 'self').is_file():
                return str(p)

    for base in ('/boot/efi', '/efi', '/run/media'):
        base_p = Path(base)
        if not base_p.is_dir():
            continue
        direct = base_p / 'SteamOS' / 'partsets'
        if (direct / 'self').is_file():
            return str(direct)
        try:
            for child in base_p.iterdir():
                if not child.is_dir():
                    continue
                p = child / 'SteamOS' / 'partsets'
                if (p / 'self').is_file():
                    return str(p)
                for sub in child.iterdir():
                    if sub.is_dir():
                        p2 = sub / 'SteamOS' / 'partsets'
                        if (p2 / 'self').is_file():
                            return str(p2)
        except OSError:
            continue
    return ''


def discover_steam_efi():
    cfg = _load_config()
    custom = cfg.get('steam', {}).get('efi')
    if custom and Path(custom).is_file():
        return str(Path(custom))

    for candidate in (
        Path('/opt/hatan-os/media-ref/efi-steamos/grubx64.efi'),
        Path('/boot/efi/steamos/grubx64.efi'),
    ):
        if candidate.is_file():
            return str(candidate)

    partsets = discover_steam_partsets()
    if partsets:
        # G:\SteamOS -> G:\EFI\steamos\grubx64.efi
        root = Path(partsets).parent.parent
        efi = root / 'EFI' / 'steamos' / 'grubx64.efi'
        if efi.is_file():
            return str(efi)

    if platform.system() == 'Windows':
        for root in _win_drives():
            efi = root / 'EFI' / 'steamos' / 'grubx64.efi'
            if efi.is_file():
                return str(efi)

    for base in ('/boot/efi', '/efi'):
        efi = Path(base) / 'steamos' / 'grubx64.efi'
        if efi.is_file():
            return str(efi)
    return ''


def discover_hatan_project():
    cfg = _load_config()
    custom = cfg.get('hatan_project')
    if custom and Path(custom).joinpath('installer', 'install.sh').is_file():
        return str(Path(custom))

    env = os.environ.get('HATAN_PROJECT_DIR')
    if env and Path(env).is_dir():
        return env

    if platform.system() == 'Windows':
        for root in _win_drives():
            p = root / 'hatan-os'
            if (p / 'installer' / 'install.sh').is_file():
                return str(p)

    for p in ('/opt/hatan-os', Path(__file__).resolve().parent.parent.parent):
        pp = Path(p)
        if (pp / 'installer' / 'install.sh').is_file():
            return str(pp)
    return ''


def parse_partsets(partsets_dir):
    result = {}
    self_file = Path(partsets_dir) / 'self'
    if not self_file.is_file():
        return result
    for line in self_file.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) == 2:
            result[parts[0]] = parts[1].strip().lower()
    return result


def _guids_on_windows():
    script = Path(__file__).resolve().parent / 'list-partition-guids.ps1'
    r = _run([
        'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script),
    ])
    if not r or r.returncode != 0:
        return set()
    return {g.strip().lower().strip('{}') for g in r.stdout.splitlines() if g.strip()}


def _guids_on_linux():
    guids = set()
    r = _run(['lsblk', '-rno', 'PARTUUID'], timeout=8)
    if r and r.returncode == 0:
        guids.update(g.strip().lower() for g in r.stdout.splitlines() if g.strip())
    r = _run(['blkid', '-s', 'PARTUUID', '-o', 'value'], timeout=8)
    if r and r.returncode == 0:
        guids.update(g.strip().lower() for g in r.stdout.splitlines() if g.strip())
    return guids


def _steam_disk_partition_count():
    script = Path(__file__).resolve().parent / 'count-steam-disk.ps1'
    if not script.is_file():
        return 0
    r = _run([
        'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script),
    ])
    if not r or r.returncode != 0:
        return 0
    try:
        return int((r.stdout or '0').strip())
    except ValueError:
        return 0


def steam_partitions_present(partsets_dir=None):
    partsets_dir = partsets_dir or discover_steam_partsets()
    if not partsets_dir:
        return False, []
    expected = parse_partsets(partsets_dir)
    if not expected:
        return False, []
    guids = _guids_on_windows() if platform.system() == 'Windows' else _guids_on_linux()
    found = [k for k, v in expected.items() if v in guids]
    need = {'rootfs', 'efi'}
    if need.issubset(set(found)):
        return True, found

    if platform.system() == 'Windows':
        efi = discover_steam_efi()
        if efi and Path(efi).is_file():
            grub = Path(efi).parent / 'grub.cfg'
            if grub.is_file() and 'SteamOS' in grub.read_text(encoding='utf-8', errors='replace'):
                if _steam_disk_partition_count() >= 3:
                    return True, found + ['grub', 'disk-layout']
    return False, found


def get_paths():
    paths = {
        'windows_source': discover_windows_source(),
        'windows_setup': '',
        'steam_partsets': discover_steam_partsets(),
        'steam_efi': discover_steam_efi(),
        'hatan_project': discover_hatan_project(),
    }
    if paths['windows_source']:
        setup = Path(paths['windows_source']) / 'setup.exe'
        if setup.is_file():
            paths['windows_setup'] = str(setup)
    return paths


def refresh_config():
    paths = get_paths()
    data = _load_config()
    data.setdefault('windows', {})['source'] = paths['windows_source']
    data.setdefault('steam', {})['partsets'] = paths['steam_partsets']
    data.setdefault('steam', {})['efi'] = paths['steam_efi']
    data['hatan_project'] = paths['hatan_project']
    _save_config(data)
    return paths
