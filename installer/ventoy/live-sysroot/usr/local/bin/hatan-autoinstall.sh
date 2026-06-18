#!/bin/bash
# Runs the one-command launcher once in live environment.

set -euo pipefail

[[ -f /tmp/.hatan-autoinstall-done ]] && exit 0
touch /tmp/.hatan-autoinstall-done

exec > >(tee /tmp/hatan-autoinstall.log) 2>&1

echo "[hatan] auto installer started: $(date)"

if [[ ! -f /usr/local/bin/hatan-install-now ]]; then
    echo "[hatan] /usr/local/bin/hatan-install-now not found"
    exit 1
fi

exec bash /usr/local/bin/hatan-install-now
