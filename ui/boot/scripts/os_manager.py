#!/usr/bin/env python3
# HATAN OS — كشف الأنظمة / التثبيت الكامل / الإقلاع

import json
import os
import platform
import re
import shutil
import subprocess
import threading
import time
from pathlib import Path

import importlib.util

SCRIPTS = Path(__file__).resolve().parent


def _import_os_paths():
    spec = importlib.util.spec_from_file_location('hatan_os_paths', SCRIPTS / 'os_paths.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


PATHS = _import_os_paths()
ROOT = SCRIPTS.parent

if platform.system() == 'Windows':
    PROGRESS_FILE = Path(os.environ.get('TEMP', '.')) / 'hatan-os-progress.json'
    STATE_FILE = Path(os.environ.get('TEMP', '.')) / 'hatan-os-state.json'
else:
    PROGRESS_FILE = Path(os.environ.get('HATAN_OS_PROGRESS', '/tmp/hatan-os-progress.json'))
    STATE_FILE = Path('/var/lib/hatan/os-state.json')

_lock = threading.Lock()
_worker = None


def _run(cmd, timeout=30, shell=False):
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            timeout=timeout,
            shell=shell,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def _write_progress(data):
    PROGRESS_FILE.parent.mkdir(parents=True, exist_ok=True)
    PROGRESS_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')


def _save_state(data):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')


def get_progress():
    if not PROGRESS_FILE.is_file():
        return {'active': False, 'os': '', 'action': '', 'percent': 0, 'message': '', 'error': ''}
    try:
        return json.loads(PROGRESS_FILE.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError):
        return {'active': False, 'os': '', 'action': '', 'percent': 0, 'message': '', 'error': ''}


def _is_linux():
    return platform.system() == 'Linux'


def _is_windows():
    return platform.system() == 'Windows'


def get_media_paths():
    try:
        return PATHS.refresh_config()
    except Exception:
        return PATHS.get_paths()


def detect_windows():
    reasons = []
    if _is_windows():
        if Path(r'C:\Windows\System32\ntoskrnl.exe').is_file():
            reasons.append('windows-system')
    if _is_linux():
        efi = Path('/boot/efi/EFI/Microsoft/Boot/bootmgfw.efi')
        if efi.is_file():
            reasons.append('efi')
        r = _run(['efibootmgr'], timeout=5)
        if r and r.returncode == 0 and re.search(r'windows', r.stdout, re.I):
            reasons.append('efibootmgr')
        r = _run(['lsblk', '-rno', 'LABEL,FSTYPE'], timeout=5)
        if r and r.returncode == 0:
            for line in r.stdout.splitlines():
                if 'ntfs' in line.lower() and re.search(r'windows', line, re.I):
                    reasons.append('partition')
                    break
    return bool(reasons), reasons


def detect_steam():
    reasons = []
    paths = get_media_paths()
    partsets = paths.get('steam_partsets', '')
    if partsets:
        ok, found = PATHS.steam_partitions_present(partsets)
        if ok:
            reasons.extend([f'part:{x}' for x in found])
    if paths.get('steam_efi') and Path(paths['steam_efi']).is_file():
        reasons.append('efi')
    if _is_linux():
        rel = Path('/etc/os-release')
        if rel.is_file():
            txt = rel.read_text(encoding='utf-8', errors='replace').lower()
            if 'steamos' in txt:
                reasons.append('os-release')
        r = _run(['efibootmgr'], timeout=5)
        if r and r.returncode == 0 and re.search(r'steam', r.stdout, re.I):
            reasons.append('efibootmgr')
    return bool(reasons), reasons


def get_os_status():
    paths = get_media_paths()
    win_ok, win_r = detect_windows()
    steam_ok, steam_r = detect_steam()
    return {
        'windows': {'installed': win_ok, 'details': win_r},
        'steam': {'installed': steam_ok, 'details': steam_r},
        'host': platform.system().lower(),
        'paths': paths,
    }


def _find_efi_entry(pattern):
    r = _run(['efibootmgr'], timeout=8)
    if not r or r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        m = re.match(r'Boot([0-9A-Fa-f]{4})\*?\s+(.*)', line.strip())
        if not m:
            continue
        if re.search(pattern, m.group(2), re.I):
            return m.group(1)
    return None


def _boot_firmware_entry_windows(name_pattern, efi_path):
    ps = f'''
$pattern = "{name_pattern}"
$efi = "{efi_path.replace(chr(92), chr(92)+chr(92))}"
$out = bcdedit /enum firmware 2>&1 | Out-String
$guid = $null
foreach ($line in $out -split "`n") {{
    if ($line -match '^\\{{[0-9a-fA-F-]+\\}}') {{ $cur = $matches[0] }}
    if ($cur -and $line -match $pattern) {{ $guid = $cur; break }}
}}
if (-not $guid -and (Test-Path -LiteralPath $efi)) {{
    bcdedit /copy {{00000000-0000-0000-0000-000000000000}} /d "HATAN-SteamOS" | Out-Null
    $created = bcdedit /enum firmware 2>&1 | Out-String
    foreach ($line in $created -split "`n") {{
        if ($line -match 'HATAN-SteamOS' -and $prev -match '^\\{{') {{ $guid = $matches[0] }}
        $prev = $line
    }}
}}
if ($guid) {{
    bcdedit /set "{{fwbootmgr}}" bootsequence $guid /addfirst | Out-Null
    exit 0
}}
exit 1
'''
    r = _run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps], timeout=25)
    if not r or r.returncode != 0:
        return False, 'يتطلب صلاحيات المسؤول لإقلاع SteamOS (شغّل كمسؤول)'
    _run(['shutdown', '/r', '/t', '8', '/c', 'HATAN OS — إقلاع SteamOS'], timeout=5)
    return True, ''


def boot_windows():
    if _is_windows():
        _run(['shutdown', '/r', '/t', '5', '/c', 'HATAN OS — إقلاع Windows'], timeout=5)
        return True, ''
    entry = _find_efi_entry(r'windows')
    if not entry:
        return False, 'لم يُعثر على Windows في قائمة الإقلاع'
    r = _run(['efibootmgr', '-n', entry], timeout=5)
    if not r or r.returncode != 0:
        return False, (r.stderr or r.stdout or 'efibootmgr failed').strip() if r else 'timeout'
    _run(['systemctl', 'reboot'], timeout=5)
    return True, ''


def boot_steam():
    paths = get_media_paths()
    efi = paths.get('steam_efi', '')
    if _is_windows():
        if efi and Path(efi).is_file():
            return _boot_firmware_entry_windows('Steam|steamos', efi)
        return False, 'ملف إقلاع SteamOS غير موجود على G:\\EFI\\steamos'
    entry = _find_efi_entry(r'steam')
    if entry:
        r = _run(['efibootmgr', '-n', entry], timeout=5)
        if r and r.returncode == 0:
            _run(['systemctl', 'reboot'], timeout=5)
            return True, ''
    if efi and Path(efi).is_file():
        disk = os.environ.get('HATAN_STEAM_DISK', '/dev/nvme0n1')
        part = os.environ.get('HATAN_STEAM_EFI_PART', '2')
        r = _run([
            'efibootmgr', '-d', disk, '-p', part, '-c',
            'SteamOS', '-l', r'\EFI\steamos\grubx64.efi',
        ], timeout=10)
        if r and r.returncode == 0:
            boot_num = _find_efi_entry(r'steam')
            if boot_num:
                _run(['efibootmgr', '-n', boot_num], timeout=5)
            _run(['systemctl', 'reboot'], timeout=5)
            return True, ''
    return False, 'تعذّر إقلاع SteamOS — تحقق من قسم EFI'


def _install_worker(os_name):
    try:
        if os_name == 'steam':
            _install_steam()
        elif os_name == 'windows':
            _install_windows()
    except Exception as exc:
        _write_progress({
            'active': False, 'os': os_name, 'action': 'install',
            'percent': 0, 'message': '', 'error': str(exc),
        })


def _install_steam():
    paths = get_media_paths()
    partsets = paths.get('steam_partsets', '')
    efi = paths.get('steam_efi', '')

    _write_progress({
        'active': True, 'os': 'steam', 'action': 'install',
        'percent': 10, 'message': 'التحقق من ملفات SteamOS...', 'error': '',
    })

    if not partsets or not Path(partsets).is_dir():
        _write_progress({
            'active': False, 'os': 'steam', 'action': 'install',
            'percent': 10, 'message': '',
            'error': 'لم يُعثر على G:\\SteamOS\\partsets — وصّل قرص SteamOS',
        })
        return

    ok, found = PATHS.steam_partitions_present(partsets)
    if ok:
        _write_progress({
            'active': True, 'os': 'steam', 'action': 'install',
            'percent': 85, 'message': 'SteamOS مثبت — جاري الإقلاع...', 'error': '',
        })
        time.sleep(0.8)
        boot_steam()
        _write_progress({
            'active': False, 'os': 'steam', 'action': 'install',
            'percent': 100, 'message': 'جاري إعادة التشغيل إلى SteamOS', 'error': '',
            'done': True, 'installed': True,
        })
        return

    if _is_windows():
        script = SCRIPTS / 'install-steamos.ps1'
        _write_progress({
            'active': True, 'os': 'steam', 'action': 'install',
            'percent': 35, 'message': 'تشغيل مثبت SteamOS (يتطلب مسؤول)...', 'error': '',
        })
        r = _run([
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(script), '-Partsets', partsets, '-Efi', efi,
        ], timeout=120)
        if not r or r.returncode != 0:
            err = (r.stderr or r.stdout or 'فشل مثبت SteamOS').strip() if r else 'timeout'
            _write_progress({
                'active': False, 'os': 'steam', 'action': 'install',
                'percent': 35, 'message': '', 'error': err,
            })
            return
        _write_progress({
            'active': False, 'os': 'steam', 'action': 'install',
            'percent': 100, 'message': 'سيتم إعادة التشغيل لتثبيت SteamOS', 'error': '',
            'done': True, 'installed': True,
        })
        return

    script = SCRIPTS / 'install-steamos.sh'
    _write_progress({
        'active': True, 'os': 'steam', 'action': 'install',
        'percent': 40, 'message': 'تثبيت SteamOS من partsets...', 'error': '',
    })
    r = _run(['bash', str(script), partsets, efi], timeout=7200)
    if not r or r.returncode != 0:
        err = (r.stderr or r.stdout or 'فشل التثبيت').strip() if r else 'timeout'
        _write_progress({
            'active': False, 'os': 'steam', 'action': 'install',
            'percent': 40, 'message': '', 'error': err,
        })
        return
    _write_progress({
        'active': False, 'os': 'steam', 'action': 'install',
        'percent': 100, 'message': 'اكتمل تثبيت SteamOS', 'error': '',
        'done': True, 'installed': True,
    })
    time.sleep(0.5)
    boot_steam()


def _install_windows():
    paths = get_media_paths()
    setup = paths.get('windows_setup', '')
    source = paths.get('windows_source', '')

    _write_progress({
        'active': True, 'os': 'windows', 'action': 'install',
        'percent': 8, 'message': 'التحقق من ملفات Windows...', 'error': '',
    })

    installed, _ = detect_windows()
    if installed:
        _write_progress({
            'active': True, 'os': 'windows', 'action': 'install',
            'percent': 80, 'message': 'Windows مثبت — جاري الإقلاع...', 'error': '',
        })
        boot_windows()
        _write_progress({
            'active': False, 'os': 'windows', 'action': 'install',
            'percent': 100, 'message': 'جاري إعادة التشغيل إلى Windows', 'error': '',
            'done': True, 'installed': True,
        })
        return

    if not setup or not Path(setup).is_file():
        _write_progress({
            'active': False, 'os': 'windows', 'action': 'install',
            'percent': 15, 'message': '',
            'error': (
                'لم يُعثر على مثبت Windows على D:\\\n'
                'تأكد من وجود setup.exe ومجلد sources على القرص.'
            ),
        })
        return

    if _is_windows():
        script = SCRIPTS / 'install-windows.ps1'
        _write_progress({
            'active': True, 'os': 'windows', 'action': 'install',
            'percent': 30, 'message': 'تشغيل مثبت Windows 11 من D:\\...', 'error': '',
        })
        r = _run([
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(script), '-Setup', setup, '-Source', source,
        ], timeout=60)
        if not r or r.returncode != 0:
            err = (r.stderr or r.stdout or 'فشل تشغيل المثبت').strip() if r else 'timeout'
            _write_progress({
                'active': False, 'os': 'windows', 'action': 'install',
                'percent': 30, 'message': '', 'error': err,
            })
            return
        _write_progress({
            'active': False, 'os': 'windows', 'action': 'install',
            'percent': 55,
            'message': 'تم فتح مثبت Windows — أكمل الخطوات على الشاشة',
            'error': '', 'done': True, 'installed': False,
        })
        return

    script = SCRIPTS / 'install-windows.sh'
    _write_progress({
        'active': True, 'os': 'windows', 'action': 'install',
        'percent': 35, 'message': 'تحضير تثبيت Windows...', 'error': '',
    })
    r = _run(['bash', str(script), source], timeout=7200)
    if not r or r.returncode != 0:
        err = (r.stderr or r.stdout or 'فشل التثبيت').strip() if r else 'timeout'
        _write_progress({
            'active': False, 'os': 'windows', 'action': 'install',
            'percent': 35, 'message': '', 'error': err,
        })
        return
    _write_progress({
        'active': False, 'os': 'windows', 'action': 'install',
        'percent': 100, 'message': 'اكتمل تحضير Windows', 'error': '',
        'done': True, 'installed': True,
    })
    boot_windows()


def launch_os(os_name):
    global _worker
    os_name = (os_name or '').strip().lower()
    if os_name not in ('windows', 'steam'):
        return {'ok': False, 'error': 'نظام غير معروف'}

    get_media_paths()
    status = get_os_status()
    installed = bool(status.get(os_name, {}).get('installed'))
    label = 'Windows' if os_name == 'windows' else 'SteamOS'

    if installed:
        _write_progress({
            'active': True, 'os': os_name, 'action': 'boot',
            'percent': 35, 'message': f'جاري الدخول إلى {label}...', 'error': '',
        })
        ok, err = boot_windows() if os_name == 'windows' else boot_steam()
        if ok:
            _write_progress({
                'active': False, 'os': os_name, 'action': 'boot',
                'percent': 100, 'message': f'جاري إعادة التشغيل إلى {label}',
                'error': '', 'done': True, 'installed': True,
            })
            return {
                'ok': True, 'os': os_name, 'installed': True,
                'action': 'boot', 'message': f'جاري الدخول إلى {label}...',
            }
        _write_progress({
            'active': False, 'os': os_name, 'action': 'boot',
            'percent': 0, 'message': '', 'error': err,
        })
        return {'ok': False, 'os': os_name, 'installed': True, 'action': 'boot', 'error': err}

    with _lock:
        if _worker and _worker.is_alive():
            return {'ok': False, 'error': 'عملية تثبيت قيد التشغيل'}
        _write_progress({
            'active': True, 'os': os_name, 'action': 'install',
            'percent': 5, 'message': f'جاري تثبيت {label}...', 'error': '',
        })
        _worker = threading.Thread(target=_install_worker, args=(os_name,), daemon=True)
        _worker.start()

    return {
        'ok': True,
        'os': os_name,
        'installed': False,
        'action': 'install',
        'message': f'جاري تثبيت {label}...',
    }
