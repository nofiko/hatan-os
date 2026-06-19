# البدء — HATAN OS على Steam Deck

## المتطلبات

- Steam Deck LCD
- USB 16GB+ (للتثبيت الأول)
- اتصال إنترنت أثناء التثبيت (مستودعات Valve: `steamdeck-packages.steamos.cloud`)
- (اختياري) وسيط Windows على USB لاحقاً لتثبيت Windows

## مسار التثبيت السريع

### أ) قرص فارغ — HATAN فقط

1. `install-hatan.bat` على Windows (مسؤول)
2. إقلاع Deck من USB → **HATAN OS - Auto Install**
3. `reboot`

### ب) Dual Boot مع SteamOS

```bash
export HATAN_DUAL_BOOT=1
export HATAN_TARGET_DISK=/dev/nvme0n1
sudo ./installer/live-install.sh
```

### ج) بعد التشغيل

| الإجراء | الطريقة |
|---------|---------|
| اختيار Windows | زر Windows في شاشة الإقلاع |
| اختيار SteamOS | زر SteamOS |
| واجهة HATAN | اضغط **H** في شاشة الاختيار |
| واي فاي | أيقونة الواي فاي أعلى الشاشة |

## اختبار على PC

```
preview.bat
```

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| لا إنترنت أثناء التثبيت | `iwctl` → اتصال بالواي فاي |
| Windows لا يُثبت | ضع `setup.exe` في `/var/lib/hatan/iso/windows/` |
| SteamOS لا يُقلع | تحقق من `/opt/hatan-os/media-ref/efi-steamos/grubx64.efi` |
| شاشة سوداء بعد الإقلاع | جرّب خيار GRUB2 في قائمة Ventoy |

راجع `docs/TEST.md` لقائمة اختبار كاملة.
