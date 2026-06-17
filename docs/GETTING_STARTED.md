# HATAN OS - دليل البدء

## ما بنيناه

مشروع **HATAN OS** — توزيعة Linux مخصصة لـ Steam Deck LCD:

| المكوّن | المصدر | ملاحظات |
|---------|--------|---------|
| Kernel | `linux-neptune` من Valve | محسّن للـ Deck |
| التعريفات | `jupiter-main` + `holo-main` | أزرار، صوت، مروحة |
| الواجهة | **HATAN Shell** (تصميمك) | HTML/CSS/JS |
| الأساس | Arch Linux | |

---

## معاينة الواجهة على PC

قبل التثبيت على Steam Deck، جرّب الواجهة على جهازك:

```bash
cd ui/shell
python -m http.server 8765
```

ثم افتح: http://localhost:8765

- الأسهم للتنقل
- Enter للاختيار
- 1/2/3 للتبويبات

---

## تخصيص التصميم

### الألوان
عدّل `themes/custom/theme.css`:

```css
:root {
  --primary: #YOUR_COLOR;
  --background: #YOUR_BG;
}
```

### الشعار
استبدل `themes/icons/logo.svg` بشعارك.

### شاشة التشغيل
الصورة في `themes/splash/boot.png` — تظهر عند إقلاع الجهاز وعند فتح الواجهة.

### الإعدادات
عدّل `config/hat-os.conf` — اسم النظام، اللغة، إلخ.

### الواجهة
- `ui/shell/index.html` — الهيكل
- `ui/shell/css/style.css` — التصميم
- `ui/shell/js/shell.js` — السلوك

---

## التثبيت على Steam Deck LCD

### الطريقة الموصى بها: ISO HATAN OS

```bash
sudo ./build/build-iso.sh    # على Arch Linux
```

ثم اكتب ISO على USB و Boot من Deck — **واجهة التثبيت + لوحة لمس تلقائياً**.

راجع **`docs/ISO.md`** للتفاصيل الكاملة.

### الطريقة 1: Arch موجود مسبقاً

```bash
sudo ./installer/install.sh
reboot
```

### الطريقة 2: استبدال Windows

1. جهّز USB بـ Arch Linux ISO
2. Boot من USB على Steam Deck (Volume+ + Power)
3. ثبّت Arch Linux
4. انسخ ملفات HATAN OS
5. شغّل `installer/install.sh`

راجع `installer/manual-install-guide.sh` للتفاصيل.

---

## الخطوات التالية (معاً)

- [ ] اختيار اسم نهائي وشعار
- [ ] تخصيص الألوان والثيم
- [ ] إضافة شاشة إقلاع
- [ ] ربط قائمة الألعاب بـ Steam API
- [ ] اختبار على Steam Deck LCD
- [ ] إضافة دعم يد التحكم الكامل
- [x] بناء صورة ISO للتثبيت السهل — راجع `docs/ISO.md` و `build/build-iso.sh`

---

## هيكل الملفات

```
HAT2/
├── base/
│   ├── pacman.conf          ← مستودعات Arch + Valve
│   └── packages/
│       ├── essential.txt    ← حزم ضرورية
│       └── recommended.txt  ← حزم إضافية
├── ui/shell/
│   ├── index.html           ← الواجهة الرئيسية
│   ├── css/style.css        ← التصميم
│   ├── js/shell.js          ← المنطق
│   └── hat-shell.sh         ← مشغّل الواجهة
├── themes/
│   ├── custom/theme.css     ← ثيمك
│   ├── icons/logo.svg       ← الشعار
│   └── splash/              ← شاشة الإقلاع
├── config/hat-os.conf       ← إعدادات النظام
├── installer/install.sh     ← سكربت التثبيت
└── build/build-package.sh   ← بناء الحزمة
```
