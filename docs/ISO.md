# ملف ISO لـ HATAN OS

## هل ISO أسهل؟

**نعم — للمستخدم النهائي:**

| الطريقة | للمستخدم |
|---------|----------|
| **ISO واحد** | انسخه بـ Etcher/Rufus → جاهز |
| **USB + Ventoy** (الحالي) | عدة ملفات + `install-hatan.bat` |

**لكن على Steam Deck:** ما زلت تحتاج **Boot Manager مرة واحدة** لإقلاع من USB — سواء ISO أو Ventoy.

---

## بناء ISO على GitHub (تلقائي)

1. ارفع المشروع إلى GitHub:
   ```bash
   git init
   git add .
   git commit -m "HATAN OS"
   git remote add origin https://github.com/YOUR_USER/HAT2.git
   git push -u origin main
   ```

2. افتح **Actions** → **Build HATAN OS ISO** → **Run workflow**

3. بعد 15–30 دقيقة: **Artifacts** → حمّل `hatan-os-iso-...`

### إصدار رسمي (Release)

```bash
git tag v0.1.0
git push origin v0.1.0
```

يُرفع ISO تلقائياً في **Releases**.

> **ملاحظة:** GitHub لا يبني ISO على جهازك — يبنيه على سيرفرات GitHub (مجاني للمستودعات العامة).

---

## بناء ISO محلياً

### على Arch Linux

```bash
sudo pacman -S archiso
cd HAT2
sudo bash build/build-iso.sh
```

الناتج:
```
build/output/hatan-os-YYYY.MM.DD-x86_64.iso
```

### على Windows (عبر WSL)

```
build-iso.bat
```

---

## استخدام ISO على Steam Deck

1. انسخ ISO إلى USB بـ **Balena Etcher** (مُفضّل) أو **Rufus**
   - في Rufus: اختر **DD image mode** وليس ISO mode
   - لا تنسخ الملف داخل فلاش كملف عادي — يجب **حرق** الصورة
2. أدخل USB في Deck (يفضّل منفذ USB-C مباشر)
3. **Volume+ + Power** → **Boot Manager** → USB
4. إن ظهر خطأ **Switch Root** اختر **HATAN OS — Safe Boot (USB)**
5. التثبيت يبدأ تلقائياً أو من واجهة HATAN (30–60 دقيقة)
6. أزل USB → `reboot`

---

## ISO مقابل Ventoy

| | ISO | Ventoy (`install-hatan.bat`) |
|--|-----|------------------------------|
| ملف واحد | نعم | لا (مجلدات متعددة) |
| بناء على Windows | يحتاج WSL | نعم مباشرة |
| تثبيت تلقائي | نعم | نعم |
| Boot Manager | مرة واحدة | مرة واحدة |

**الخلاصة:** ISO أنظف للتوزيع؛ Ventoy أسهل للتجهيز من Windows بدون WSL.
