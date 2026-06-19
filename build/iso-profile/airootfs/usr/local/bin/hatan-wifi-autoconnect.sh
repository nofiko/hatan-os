#!/bin/bash
# HATAN OS — اتصال تلقائي بالشبكات الافتراضية (بالترتيب)
set -uo pipefail

if ping -c1 -W2 steamdeck-packages.steamos.cloud &>/dev/null; then
    exit 0
fi

if command -v rfkill &>/dev/null; then
    rfkill unblock wifi 2>/dev/null || rfkill unblock all 2>/dev/null || true
fi

systemctl start iwd 2>/dev/null || true
systemctl start NetworkManager 2>/dev/null || true
sleep 2

nmcli radio wifi on 2>/dev/null || true
nmcli device wifi rescan 2>/dev/null || true
sleep 2

if ping -c1 -W2 steamdeck-packages.steamos.cloud &>/dev/null; then
    exit 0
fi

# الأولوية: Nasser5G → Nasser4G → HHS12
for conn in Nasser5G Nasser4G HHS12; do
    nmcli connection up "$conn" 2>/dev/null || continue
    sleep 3
    if ping -c1 -W3 steamdeck-packages.steamos.cloud &>/dev/null; then
        echo "[hatan-wifi] connected via $conn"
        exit 0
    fi
    nmcli connection down "$conn" 2>/dev/null || true
done

exit 1
