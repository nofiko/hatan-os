// HATAN OS — أزرار Steam Deck والاختصارات

const HATAN_DECK_BUTTONS = [
  { id: 'L1', label: 'L1', group: 'shoulder', gp: 4 },
  { id: 'R1', label: 'R1', group: 'shoulder', gp: 5 },
  { id: 'L2', label: 'L2', group: 'trigger', gp: 6 },
  { id: 'R2', label: 'R2', group: 'trigger', gp: 7 },
  { id: 'L4', label: 'L4', group: 'rear', gp: 16 },
  { id: 'R4', label: 'R4', group: 'rear', gp: 17 },
  { id: 'SELECT', label: '☰', group: 'center', gp: 8, title: 'View' },
  { id: 'STEAM', label: '⬡', group: 'center', gp: null, title: 'Steam' },
  { id: 'QAM', label: '⋯', group: 'center', gp: null, title: 'Quick Access' },
  { id: 'START', label: '☰', group: 'center', gp: 9, title: 'Menu' },
  { id: 'DPAD_UP', label: '▲', group: 'dpad', gp: 12 },
  { id: 'DPAD_LEFT', label: '◀', group: 'dpad', gp: 14 },
  { id: 'DPAD_DOWN', label: '▼', group: 'dpad', gp: 13 },
  { id: 'DPAD_RIGHT', label: '▶', group: 'dpad', gp: 15 },
  { id: 'Y', label: 'Y', group: 'face', gp: 3, color: 'y' },
  { id: 'X', label: 'X', group: 'face', gp: 2, color: 'x' },
  { id: 'B', label: 'B', group: 'face', gp: 1, color: 'b' },
  { id: 'A', label: 'A', group: 'face', gp: 0, color: 'a' },
  { id: 'L3', label: 'L3', group: 'stick', gp: 10 },
  { id: 'R3', label: 'R3', group: 'stick', gp: 11 },
];

const HATAN_SHORTCUT_ACTIONS = [
  { id: 'none', icon: '∅', label: 'لا شيء' },
  { id: 'confirm', icon: '✓', label: 'اختيار / تأكيد' },
  { id: 'back', icon: '↩', label: 'رجوع' },
  { id: 'options', icon: '☰', label: 'إظهار خيارات' },
  { id: 'toggle-keyboard', icon: '⌨', label: 'تبديل لغة الكيبورد' },
  { id: 'toggle-wifi', icon: '📶', label: 'تشغيل / إيقاف WiFi' },
  { id: 'toggle-bluetooth', icon: '🔵', label: 'تشغيل / إيقاف Bluetooth' },
  { id: 'volume-up', icon: '🔊', label: 'رفع الصوت' },
  { id: 'volume-down', icon: '🔉', label: 'خفض الصوت' },
  { id: 'brightness-up', icon: '☀', label: 'رفع السطوع' },
  { id: 'brightness-down', icon: '🌙', label: 'خفض السطوع' },
  { id: 'open-settings', icon: '⚙', label: 'فتح الإعدادات' },
  { id: 'open-files', icon: '📁', label: 'فتح الملفات' },
  { id: 'home', icon: '🏠', label: 'الشاشة الرئيسية' },
  { id: 'screenshot', icon: '📷', label: 'لقطة شاشة' },
  { id: 'log-usage', icon: '📊', label: 'تسجيل الاستخدام' },
  { id: 'open-steam', icon: '🎮', label: 'تشغيل Steam' },
];

const GP_INDEX_TO_BTN = {};
HATAN_DECK_BUTTONS.forEach(b => {
  if (b.gp != null) GP_INDEX_TO_BTN[b.gp] = b.id;
});

const DEFAULT_BUTTON_MAP = {
  A: 'confirm',
  B: 'back',
  X: 'options',
  Y: 'toggle-wifi',
  L1: 'volume-down',
  R1: 'volume-up',
  L2: 'brightness-down',
  R2: 'brightness-up',
  L3: 'log-usage',
  R3: 'toggle-keyboard',
  L4: 'log-usage',
  R4: 'screenshot',
  SELECT: 'none',
  START: 'open-settings',
  STEAM: 'home',
  QAM: 'options',
  DPAD_UP: 'none',
  DPAD_DOWN: 'none',
  DPAD_LEFT: 'none',
  DPAD_RIGHT: 'none',
};

const LEGACY_ACTION_MAP = {
  'تأكيد': 'confirm',
  'رجوع': 'back',
  'قائمة': 'options',
  'بحث': 'toggle-wifi',
};

function normalizeButtonMap(raw) {
  const base = { ...DEFAULT_BUTTON_MAP };
  if (!raw || typeof raw !== 'object') return base;
  for (const btn of HATAN_DECK_BUTTONS) {
    const val = raw[btn.id];
    if (!val) continue;
    base[btn.id] = LEGACY_ACTION_MAP[val] || val;
  }
  return base;
}

function getActionLabel(actionId) {
  const a = HATAN_SHORTCUT_ACTIONS.find(x => x.id === actionId);
  return a ? a.label : 'لا شيء';
}

function getActionIcon(actionId) {
  const a = HATAN_SHORTCUT_ACTIONS.find(x => x.id === actionId);
  return a ? a.icon : '∅';
}

const HATANShortcutActions = {
  async run(action, shell) {
    if (!action || action === 'none') return;

    const local = {
      confirm: () => this._confirm(shell),
      back: () => this._back(shell),
      options: () => this._options(shell),
      home: () => this._home(shell),
      'open-settings': () => shell?.launchApp?.('settings'),
      'open-files': () => shell?.launchApp?.('files'),
      'open-steam': () => shell?.launchApp?.('steam'),
    };

    if (local[action]) {
      local[action]();
      return;
    }

    try {
      await fetch('/api/shortcut', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
    } catch { /* preview */ }

    if (action === 'log-usage') this._toast('تم تسجيل الاستخدام');
    if (action.startsWith('toggle-')) this._toast(getActionLabel(action));
  },

  _confirm(shell) {
    if (shell?.gamepadNav?.confirm()) return;

    const settings = document.getElementById('settings-screen');
    if (settings?.classList.contains('show')) {
      const focused = settings.querySelector('.hat-focused');
      if (focused) {
        focused.click();
        return;
      }
    }

    const focused = document.querySelector('.home-app-3d.hat-focused, .home-game-card.hat-focused, .home-app-3d:focus');
    if (focused) {
      focused.click();
      return;
    }
    document.activeElement?.click?.();
  },

  _back(shell) {
    const settings = document.getElementById('settings-screen');
    if (settings?.classList.contains('show')) {
      shell?.settings?.close();
      return;
    }
    this._toast('رجوع');
  },

  _options(shell) {
    this._showQuickPanel(shell);
  },

  _home(shell) {
    shell?.settings?.close();
    document.getElementById('home-screen')?.classList.add('show');
    this._toast('الشاشة الرئيسية');
  },

  _showQuickPanel(shell) {
    let panel = document.getElementById('hat-quick-panel');
    if (panel) {
      panel.remove();
      return;
    }
    panel = document.createElement('div');
    panel.id = 'hat-quick-panel';
    panel.className = 'hat-quick-panel';
    panel.innerHTML = `
      <div class="hat-quick-panel-inner">
        <button type="button" data-q="settings">⚙ الإعدادات</button>
        <button type="button" data-q="wifi">📶 WiFi</button>
        <button type="button" data-q="keyboard">⌨ الكيبورد</button>
        <button type="button" data-q="log">📊 تسجيل استخدام</button>
      </div>
    `;
    document.body.appendChild(panel);
    requestAnimationFrame(() => panel.classList.add('show'));
    panel.querySelectorAll('[data-q]').forEach(btn => {
      btn.addEventListener('click', () => {
        const q = btn.dataset.q;
        if (q === 'settings') shell?.launchApp?.('settings');
        else if (q === 'wifi') HATANShortcutActions.run('toggle-wifi', shell);
        else if (q === 'keyboard') HATANShortcutActions.run('toggle-keyboard', shell);
        else if (q === 'log') HATANShortcutActions.run('log-usage', shell);
        panel.remove();
      });
    });
    setTimeout(() => {
      if (panel.parentNode) panel.remove();
    }, 5000);
  },

  _toast(msg) {
    let t = document.getElementById('hat-toast');
    if (!t) {
      t = document.createElement('div');
      t.id = 'hat-toast';
      t.className = 'hat-toast';
      document.body.appendChild(t);
    }
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(t._timer);
    t._timer = setTimeout(() => t.classList.remove('show'), 2200);
  },
};

class HATANButtonShortcuts {
  constructor(shell) {
    this.shell = shell;
    this.map = normalizeButtonMap(null);
    this.pressed = new Set();
    this.active = false;
    this.enabled = true;
    if (!shell.gamepadNav) shell.gamepadNav = new HATANGamepadNav(shell);
  }

  async load() {
    try {
      const res = await fetch('/api/settings');
      const data = await res.json();
      this.map = normalizeButtonMap(data.settings?.buttonMap);
    } catch {
      this.map = normalizeButtonMap(null);
    }
  }

  start() {
    if (this.active) return;
    this.active = true;
    window.addEventListener('gamepadconnected', () => this.load());
    this._loop();
  }

  stop() {
    this.active = false;
  }

  isSystemActive() {
    const home = document.getElementById('home-screen');
    const settings = document.getElementById('settings-screen');
    const capture = document.getElementById('capture-screen');
    const welcome = document.querySelector('.welcome-screen:not(.hidden)');
    if (welcome) return false;
    return !!(home?.classList.contains('show') || settings?.classList.contains('show') || capture?.classList.contains('show'));
  }

  _loop() {
    if (!this.active) return;
    if (this.enabled && this.isSystemActive() && navigator.getGamepads) {
      for (const gp of navigator.getGamepads()) {
        if (gp) this._readGamepad(gp);
      }
    }
    requestAnimationFrame(() => this._loop());
  }

  _readGamepad(gp) {
    for (const [idxStr, btnId] of Object.entries(GP_INDEX_TO_BTN)) {
      const idx = parseInt(idxStr, 10);
      const btn = gp.buttons[idx];
      if (!btn) continue;
      const key = `${gp.index}:${btnId}`;
      const down = btn.pressed || btn.value > 0.5;
      if (down && !this.pressed.has(key)) {
        this.pressed.add(key);
        this._trigger(btnId);
      } else if (!down) {
        this.pressed.delete(key);
      }
    }
  }

  _trigger(btnId) {
    const dpad = ['DPAD_UP', 'DPAD_DOWN', 'DPAD_LEFT', 'DPAD_RIGHT'];
    if (dpad.includes(btnId) && this.shell?.gamepadNav?.handleDpad(btnId)) {
      return;
    }
    const action = this.map[btnId] || 'none';
    if (action === 'none') return;
    HATANShortcutActions.run(action, this.shell);
  }

  updateMap(map) {
    this.map = normalizeButtonMap(map);
  }
}
