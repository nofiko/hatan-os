# HATAN OS

نظام **Steam Deck LCD** يجمع **Windows** و **SteamOS** في تجربة إقلاع واحدة.

## جرّب على PC

```
preview.bat
```

## الفكرة

```
إقلاع → شاشة HATAN → اختيار Windows أو SteamOS
         ↓ غير مثبت          ↓ مثبت
      يثبّته              يدخله كاملاً

اضغط H → الدخول لواجهة HATAN (Steam · Xbox · المتصفح · …)
```

## هيكل المشروع

```
HAT2/
├── preview.bat              ← معاينة الواجهة على Windows
├── install-hatan.bat        ← تجهيز USB من Windows (بدون بناء ISO)
├── build-iso.bat            ← بناء ISO محلياً (WSL)
├── .github/workflows/       ← بناء ISO على GitHub Actions
├── ui/boot/                 ← شاشة الإقلاع + اختيار النظام
├── ui/shell/                ← واجهة HATAN الرئيسية
├── installer/               ← تثبيت على Deck
├── media-ref/               ← نسخة مرجعية من ملفات الفلاش (لا تُعدَّل الفلاشات)
└── docs/GETTING_STARTED.md
```

## التثبيت على Steam Deck

### 1 — على Windows (تجهيز USB)

1. انسخ مجلد `HAT2` بالكامل إلى USB أو استخدمه من الفلاش
2. شغّل **كمسؤول**: `install-hatan.bat`
3. انتظر حتى يجهّز Ventoy + Arch ISO + ملفات HATAN

### 2 — على Steam Deck

1. **Volume+ + Power** → Boot Manager → USB
2. اختر **HATAN OS - Auto Install**
3. انتظر اكتمال التثبيت (30–60 دقيقة)
4. أزل USB → `reboot`

### Dual Boot (مع SteamOS / Windows موجود)

```bash
HATAN_DUAL_BOOT=1 HATAN_TARGET_DISK=/dev/nvme0n1 ./live-install.sh
```

أو عيّن قسمًا جاهزًا:

```bash
HATAN_DUAL_BOOT=1 HATAN_ROOT_PART=/dev/nvme0n1pX HATAN_EFI_PART=/dev/nvme0n1pY ./live-install.sh
```

## ملفات Windows / SteamOS

| الملف | على الجهاز بعد التثبيت |
|-------|-------------------------|
| مرجع SteamOS partsets | `/opt/hatan-os/media-ref/steamos/partsets/` |
| مرجع EFI SteamOS | `/opt/hatan-os/media-ref/efi-steamos/` |
| وسيط تثبيت Windows | `/var/lib/hatan/iso/windows/setup.exe` |

ضع وسيط Windows (مجلد فيه `setup.exe` و `sources`) على USB أو انسخه إلى المسار أعلاه.

## بعد التثبيت

- المستخدم: `deck` / `deck`
- إقلاع يدوي لشاشة الاختيار: `hatan-boot`
- واجهة HATAN: `hatan-shell`

## ملاحظة عن الفلاشات

ملفات `D:\` و `G:\` على PC تُستخدم كمرجع فقط — المشروع **لا يعدّل الفلاشات**، بل يحتفظ بنسخة في `media-ref/`.
