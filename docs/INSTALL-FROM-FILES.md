# التثبيت من تطبيق الملفات (Steam Deck)

## الفكرة

بدلاً من Boot Manager وUSB إقلاع، يمكنك:

1. وضع ملفات HATAN على **USB** أو مجلد في الجهاز
2. فتح **وضع سطح المكتب** على Steam Deck
3. فتح تطبيق **الملفات** (Dolphin)
4. النقر على **«تثبيت HATAN OS»**
5. إدخال كلمة مرور Steam عند الطلب
6. متابعة المثبّت الرسومي حتى النهاية

## ما على USB

```
USB:\
├── تثبيت-HATAN-OS.desktop    ← انقر هنا من تطبيق الملفات
├── hatan-install-from-files.sh
├── hatan-os\                   ← المشروع كاملاً
│   └── installer\
│       └── live-install.sh
└── ابدأ-هنا.txt
```

## أول مرة — السماح بالتشغيل

KDE قد يطلب:

- **السماح بالتشغيل** / **Allow Launching** (نقرة يمين على الملف)
- أو: خصائص → صلاحيات → «تنفيذ» / Execute

## Dual Boot مع SteamOS

من SteamOS، التثبيت الافتراضي **يحافظ على SteamOS** ويضيف قسم HATAN (~20 GB في المساحة الحرة).

للمسح الكامل (خطير):

```bash
HATAN_DUAL_BOOT=0 pkexec bash /path/to/hatan-os/installer/launch-from-files.sh
```

## المتطلبات

- Steam Deck في **وضع سطح المكتب**
- **إنترنت** (واي فاي)
- USB أو مجلد فيه `hatan-os` كاملاً

## إن لم يعمل النقر

افتح **Konsole** من قائمة التطبيقات:

```bash
cd /run/media/deck/Ventoy
bash ./hatan-install-from-files.sh
```

(غيّر `Ventoy` لاسم فلاشتك)

## الفرق عن الإقلاع من USB

| من الملفات | من Boot Manager |
|------------|-----------------|
| تبقى في SteamOS | بيئة Arch live |
| Dual Boot افتراضي | يمكن مسح القرص كاملاً |
| أسهل للمستخدم | أنسب لقرص فارغ |
