// HATAN OS — إعدادات

const HATAN_CONFIG = {
  name: 'HATAN OS',
  version: '0.1.0',
  welcome: {
    text: 'مرحباً',
    openText: 'اضغط هنا لفتح النظام'
  },
  audio: {
    startup: 'assets/audio/startup-sound.mp3',
    welcome: 'assets/audio/welcom.mp3',
    press: 'assets/audio/press-music.mp3',
    select: 'assets/audio/select.mp3',
    dis: 'assets/audio/DIS.mp3'
  },
  apps: [
    { id: 'steam', name: 'Steam', icon: '🎮' },
    { id: 'xbox', name: 'Xbox', icon: '🟢' },
    { id: 'microsoft-store', name: 'Microsoft Store', icon: '🛒' },
    { id: 'brave', name: 'Brave', icon: '🦁' },
    { id: 'files', name: 'الملفات', icon: '📁' },
    { id: 'capture', name: 'تصوير الشاشة', icon: '🎬' },
    { id: 'settings', name: 'الإعدادات', icon: '⚙️' },
    { id: 'exe', name: 'ملفات EXE', icon: '🪟' }
  ]
};

const HAT_CONFIG = HATAN_CONFIG;
