# HATAN OS — ISO Boot Audit Report

**Date:** 2026-06-18  
**Symptom:** UEFI → GRUB → kernel → initramfs OK, then:

```
ERROR: device '' not found
Failed to mount real root
Dropped into emergency shell
```

---

## Executive summary

| Area | Status | Notes |
|------|--------|-------|
| archiso profile (`profiledef.sh`) | OK | `uefi.grub`, `HATAN_OS`, `arch/`, squashfs |
| GRUB `grub.cfg` | OK | `archisosearchuuid=%ARCHISO_UUID%` (substituted by mkarchiso) |
| GRUB `loopback.cfg` | OK | Ventoy: `archisolabel` + `img_loop` |
| efiboot | N/A | Profile uses `uefi.grub` only (no separate efiboot/) |
| **initramfs / mkinitcpio** | **FAIL → FIXED** | Missing `archiso` hooks for `linux-neptune` |
| archiso hooks in initramfs | **FAIL → FIXED** | No `archiso.conf` or `archiso` preset |
| airootfs generation | OK | squashfs via mkarchiso |
| squashfs (`airootfs.sfs`) | OK | Verified in CI `verify-built-iso.sh` |
| Root filesystem discovery | **FAIL → FIXED** | Initramfs could not search ISO without `archiso` hook |
| SteamOS/Holo boot params | OK | `rd.systemd.gpt_auto=no`, `amd_iommu=off`, `cow_spacesize=4G` |

**Root cause:** The live initramfs for `linux-neptune` was built with the kernel package’s default mkinitcpio preset (standard `HOOKS`, no `archiso`). Kernel cmdline parameters (`archisobasedir`, `archisosearchuuid`) were correct but **ignored** because the initramfs never ran the archiso discovery hooks.

---

## Failure chain (exact locations)

### 1. Primary cause — missing archiso mkinitcpio configuration

**Absent before fix:**

- `build/iso-profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` — **did not exist**
- `build/iso-profile/airootfs/etc/mkinitcpio.d/linux-neptune.preset` — **did not exist**

**Effect:** During `mkarchiso` pacstrap, `linux-neptune` triggered `mkinitcpio` with default hooks:

```
base → udev → microcode → … → filesystems → fsck
```

No `archiso` or `archiso_loop_mnt` hooks ran at boot. The initramfs attempted a normal disk root mount with an empty `archisodevice` → **`ERROR: device '' not found`**.

**Reference:** [archiso releng archiso.conf](https://github.com/archlinux/archiso/blob/master/configs/releng/airootfs/etc/mkinitcpio.conf.d/archiso.conf)

### 2. Secondary gap — no initramfs rebuild in customize script

**File:** `build/iso-profile/airootfs/root/customize_airootfs.sh`  
**Issue:** Script set locale, passwords, and symlinks but **never ran `mkinitcpio -p linux-neptune`** after packages overwrote the preset.

### 3. Not the cause (verified OK)

| File | Line | Finding |
|------|------|---------|
| `build/iso-profile/grub/grub.cfg` | 32, 38, 44, 50 | `archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID%` — correct; mkarchiso substitutes UUID |
| `build/iso-profile/profiledef.sh` | 5, 9 | `iso_label="HATAN_OS"`, `install_dir="arch"` — matches GRUB |
| `build/iso-profile/packages.x86_64` | 9–10 | `mkinitcpio` + `mkinitcpio-archiso` present (hooks installed, but unused without config) |
| `build/iso-profile/grub/grub.cfg` | 32 | Steam Deck params OK (`rd.systemd.gpt_auto=no`, `amd_iommu=off`, `cow_spacesize=4G`) |

---

## Fixes applied

### New files

1. **`build/iso-profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf`**  
   Releng HOOKS including `archiso`, `archiso_loop_mnt`, block, filesystems.

2. **`build/iso-profile/airootfs/etc/mkinitcpio.d/linux-neptune.preset`**  
   `PRESETS=('archiso')` pointing at `archiso.conf`.

3. **`build/iso-profile/airootfs/etc/pacman.d/hooks/zzzz99-remove-custom-hooks-from-airootfs.hook`**  
   Standard archiso cleanup hook (FS#49347).

### Modified files

4. **`build/iso-profile/airootfs/root/customize_airootfs.sh`**  
   Reinstalls `linux-neptune.preset` and runs `mkinitcpio -p linux-neptune` after pacstrap.

5. **`build/iso-profile/profiledef.sh`**  
   Permissions for new mkinitcpio files.

6. **`scripts/validate-iso-profile.sh`**  
   Pre-build checks for archiso.conf, preset, and mkinitcpio rebuild.

7. **`scripts/verify-built-iso.sh`**  
   Post-build: `lsinitcpio` must list `/hooks/archiso`; grub UUID substitution check.

---

## Component checklist (10-point audit)

### 1. archiso profile
- `buildmodes=('iso')`, `bootmodes=('uefi.grub')`, `airootfs_image_type="squashfs"` — OK

### 2. profiledef.sh
- `iso_label="HATAN_OS"`, `install_dir="arch"`, `arch="x86_64"` — OK

### 3. grub.cfg
- Neptune kernel/initrd paths, `%INSTALL_DIR%`, `%ARCH%`, `%ARCHISO_UUID%` — OK

### 4. efiboot configuration
- Not used; GRUB EFI via `uefi.grub` bootmode — OK for Deck

### 5. initramfs generation
- **Was broken** — fixed with archiso preset + `customize_airootfs.sh` rebuild

### 6. archiso hooks
- **Were missing from HOOKS** — fixed in `archiso.conf`

### 7. airootfs generation
- Overlay + pacstrap + `customize_airootfs.sh` — OK (now includes mkinitcpio)

### 8. squashfs creation
- `airootfs.sfs` at `arch/x86_64/airootfs.sfs` — OK (mkarchiso `_mkairootfs_squashfs`)

### 9. root filesystem discovery
- Requires initramfs `archiso` hook + cmdline `archisobasedir` + `archisosearchuuid` — **fixed**

### 10. SteamOS/Holo live boot parameters
- `linux-neptune`, `cow_spacesize=4G`, `nvme_load=yes`, `amd_iommu=off`, `amdgpu.dc=1`, `rd.systemd.gpt_auto=no` — OK

---

## Rebuild and test

```bash
sudo ./build/build-iso.sh
# or push to GitHub Actions workflow build-iso.yml
```

After build, `verify-built-iso.sh` must report:

- `initramfs يحتوي خطاف archiso`
- `grub.cfg: archisosearchuuid مُستبدَل بـ UUID فعلي`

On Steam Deck: DD image to USB → Boot Manager → **HATAN OS — Auto Install (Deck)**.

---

## Expected boot flow after fix

```mermaid
flowchart LR
  A[UEFI GRUB] --> B[linux-neptune + cmdline]
  B --> C[initramfs archiso hook]
  C --> D[Find ISO by UUID HATAN_OS volume]
  D --> E[Mount arch/x86_64/airootfs.sfs]
  E --> F[overlay + switch_root live system]
```
