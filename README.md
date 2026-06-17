# HATAN OS

نظام Linux مخصص لـ **Steam Deck LCD**.

## جرّب الآن (على PC)

انقر مرتين:
```
preview.bat
```

## المعمارية

```
Linux Kernel (Valve) + تعريفات Steam Deck + واجهة HATAN OS
```

## هيكل المشروع

```
HAT2/
├── preview.bat         ← شغّل هذا للمعاينة
├── ui/shell/           ← الواجهة
├── themes/             ← الثيم وشاشة التشغيل
├── installer/          ← التثبيت على Deck
└── docs/TEST.md        ← دليل التجربة الكامل
```

## التثبيت على Steam Deck

**الطريقة الموصى بها:** بناء ISO HATAN OS → Boot من USB → واجهة تثبيت + لوحة لمس.

```bat
build-iso.bat          ← تعليمات البناء على Windows
docs/ISO.md            ← الدليل الكامل
```

أو Arch موجود مسبقاً: راجع `docs/TEST.md`

## التخصيص

| الملف | الوظيفة |
|-------|---------|
| `themes/splash/boot.png` | شاشة التشغيل |
| `themes/custom/theme.css` | الألوان |
| `ui/shell/` | الواجهة |

بعد التعديل: `.\scripts\sync-assets.ps1`
