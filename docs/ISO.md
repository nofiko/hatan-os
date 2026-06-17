# HATAN OS — بناء واستخدام ISO

## لماذا ISO؟

| Arch ISO العادي | HATAN OS ISO |
|-----------------|--------------|
| طرفية فقط | واجهة تثبيت HATAN |
| لا لوحة لمس | **wvkbd** لوحة لمسية |
| تثبيت يدوي | تثبيت تلقائي كامل |
| لا يثبت HATAN | Arch + Valve + HATAN |

---

## بناء ISO

### على Arch Linux (أو WSL Arch)

```bash
cd HAT2
sudo ./build/build-iso.sh
```

الملف الناتج: `build/output/hatan-os-YYYY.MM.DD-x86_64.iso`

### على Windows

```bat
build-iso.bat
```

يعرض الخيارات (WSL / GitHub Actions).

### GitHub Actions

1. ارفع المشروع إلى GitHub
2. **Actions** → **Build HATAN OS ISO** → **Run workflow**
3. حمّل `hatan-os-iso` من **Artifacts**

---

## كتابة ISO على USB (Rufus)

| الإعداد | القيمة |
|---------|--------|
| Partition scheme | **GPT** |
| Target system | **UEFI** |
| File system | **FAT32** |
| Image mode | **ISO** (ليس DD) |

---

## التثبيت على Steam Deck

1. أطفئ Deck → **Volume+ + Power** → Boot Manager
2. اختر USB
3. **تظهر واجهة HATAN OS تلقائياً** (1280×800)
4. **لوحة لمس** تظهر تلقائياً (squeekboard) — المس حقل النص
5. **التالي** → **ابدأ التثبيت**
6. انتظر 30–60 دقيقة (لا تُطفئ الجهاز)
7. **إعادة التشغيل** → أزل USB

> **تحذير:** يُمسح القرص الداخلي `/dev/nvme0n1` بالكامل.

---

## WiFi قبل التثبيت

- ISO يفعّل **NetworkManager** تلقائياً
- من إعدادات WiFi في Deck (أو nmcli) — أو استخدم Ethernet USB
- التثبيت يحتاج إنترنت لتحميل حزم Valve

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| لا تظهر الواجهة | انتظر 30 ثانية؛ أو `systemctl status hatan-installer` |
| لا لوحة لمس | المس حقل نص في المتصفح؛ squeekboard يظهر تلقائياً |
| فشل pacstrap | تأكد من WiFi/Ethernet |
| قرص مختلف | `HATAN_TARGET_DISK=/dev/mmcblk0 sudo ...` |

---

## الملفات

```
build/
├── build-iso.sh          ← سكربت البناء
├── iso-profile/          ← ملف archiso
│   ├── profiledef.sh
│   ├── packages.x86_64
│   └── airootfs/         ← systemd + autostart
└── output/               ← ISO الناتج

installer/
├── iso-install.sh        ← تقسيم + Arch + HATAN
└── install-server.py     ← خادم الواجهة

scripts/
└── hatan-live-installer.sh  ← تشغيل تلقائي من ISO
```
