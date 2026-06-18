# HATAN OS - دليل التجربة

## الطريقة 1: معاينة على PC (الأسهل)

### Windows
انقر مرتين على:
```
preview.bat
```

أو من PowerShell:
```powershell
cd C:\Users\PC-12\Desktop\HAT2
.\preview.bat
```

### ماذا ستشاهد؟
1. شاشة تشغيل بشعار HTAN STUDIO (3 ثوانٍ)
2. واجهة تقنية إلكترونية
3. تطبيق واحد فقط: **Steam**

### التحكم
| المفتاح | الوظيفة |
|---------|---------|
| Enter | تشغيل Steam |
| Ⓐ / زر A | تشغيل Steam |

---

## الطريقة 2: التثبيت على Steam Deck LCD

### المتطلبات
- USB 8GB+
- Arch Linux ISO
- نسخة احتياطية من بياناتك (سيُستبدل Windows)

### الخطوات

**1. جهّز USB**
- حمّل Arch Linux: https://archlinux.org/download/
- اكتبها على USB بـ Rufus

**2. انسخ HATAN OS إلى USB**
```
انسخ مجلد HAT2 كاملاً إلى USB
```

**3. Boot من USB على Steam Deck**
- أطفئ الجهاز
- اضغط **Volume+** + **Power** معاً
- اختر Boot Manager → USB

**4. ثبّت Arch Linux**
```bash
lsblk
cfdisk /dev/nvme0n1
# EFI: 512M | Root: باقي المساحة

mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot
pacstrap /mnt base base-devel linux-firmware networkmanager sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

**5. ثبّت HATAN OS**
```bash
cp -r /path/to/HAT2 /opt/hatan-os
cd /opt/hatan-os/installer
chmod +x install.sh
./install.sh
reboot
```

**6. بعد إعادة التشغيل**
- شاشة Plymouth بشعارك
- واجهة HATAN OS تلقائياً

---

## تخصيص التصميم

| ماذا تغيّر | أين |
|-----------|-----|
| صورة التشغيل | `themes/splash/boot.png` |
| الألوان | `themes/custom/theme.css` |
| الواجهة | `ui/shell/index.html` |
| الإعدادات | `config/hat-os.conf` |

بعد أي تغيير شغّل:
```powershell
.\scripts\sync-assets.ps1
```

---

## حل المشاكل

**الصورة لا تظهر في المعاينة**
```powershell
.\scripts\sync-assets.ps1
.\preview.bat
```

**Python غير موجود**
- ثبّت من: https://www.python.org/downloads/
- فعّل "Add to PATH" أثناء التثبيت

**شاشة الإقلاع لا تظهر على Deck**
```bash
sudo pacman -S plymouth
sudo plymouth-set-default-theme -R hatan-os
# أضف plymouth بعد udev في /etc/mkinitcpio.conf
sudo mkinitcpio -P
sudo reboot
```
