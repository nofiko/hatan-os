# فحص وبناء ISO — Steam Deck UEFI

## فحص قبل البناء (محلي أو CI)

```bash
bash scripts/validate-iso-profile.sh
```

يفحص: GRUB، BOOTX64، linux-neptune، pacman، profiledef.

## بناء ISO

```bash
sudo bash build/build-iso.sh
```

ينتج:
- `build/output/hatan-os-YYYY.MM.DD-x86_64.iso`
- `hatan-os-latest.iso` (نسخة جاهزة)
- `build/iso-build.log`
- `build/iso-validate.log`

## التحقق بعد البناء

```bash
bash scripts/verify-built-iso.sh build/output/hatan-os-*.iso
```

يفحص داخل ISO:
- `EFI/BOOT/BOOTX64.EFI`
- `arch/boot/x86_64/vmlinuz-linux-neptune`
- `arch/boot/x86_64/initramfs-linux-neptune.img`
- `arch/x86_64/airootfs.sfs`

## الإقلاع على Steam Deck

1. **Balena Etcher** أو **Rufus (DD image)** — ليس نسخ الملف كملف عادي
2. **Volume+ + Power** → Boot Manager → USB
3. اختر **HATAN OS — Auto Install (Deck)**
4. Ventoy: **GRUB2 mode** (زر `r`) إن فشل Normal

## أسباب شائعة لفشل الإقلاع (تم إصلاحها)

| المشكلة | الإصلاح |
|---------|---------|
| `archisolabel` ثابت بدل UUID | استخدام `archisosearchuuid=%ARCHISO_UUID%` |
| لا BOOTX64.EFI | `bootmodes=('uefi.grub')` + grub في CI |
| نواة Arch بدل Deck | `linux-neptune` في packages + grub |
| Switch Root / emergency | `rd.systemd.gpt_auto=no` + `amd_iommu=off` |
| بناء ناقص بدون فحص | `validate-iso-profile.sh` + `verify-built-iso.sh` |
