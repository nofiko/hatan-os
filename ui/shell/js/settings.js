// HATAN OS — تطبيق الإعدادات 3D

const SETTINGS_CATEGORIES = [
  { id: 'appearance', icon: '🎨', title: 'المظهر', desc: 'الخلفية، الألوان والثيمات' },
  { id: 'sound', icon: '🔊', title: 'الصوت', desc: 'الإخراج، الإدخال والأجهزة المتصلة' },
  { id: 'display', icon: '☀️', title: 'الشاشة', desc: 'السطوع والعرض' },
  { id: 'device', icon: '🎮', title: 'الجهاز', desc: 'الاسم واختصارات الأزرار' },
  { id: 'network', icon: '📡', title: 'الاتصالات', desc: 'USB-C، Bluetooth، WiFi و VPN' },
  { id: 'language', icon: '🌐', title: 'اللغة', desc: 'اللغة ولوحة المفاتيح' },
  { id: 'storage', icon: '💾', title: 'التخزين', desc: 'مساحة القرص والأقسام' },
  { id: 'system', icon: '⚡', title: 'النظام', desc: 'الطاقة، التحديثات وشريط الحالة' },
  { id: 'about', icon: 'ℹ️', title: 'معلومات الجهاز', desc: 'المواصفات وإصدار النظام' },
];

const LANG_OPTIONS = [
  { id: 'ar', label: 'العربية' },
  { id: 'en', label: 'English' },
];

const KB_OPTIONS = [
  { id: 'ar', label: 'عربي' },
  { id: 'en-us', label: 'English (US)' },
  { id: 'en-gb', label: 'English (UK)' },
];

class HATANSettings {
  constructor(shell) {
    this.shell = shell;
    this.state = null;
    this.category = 'appearance';
    this.saveTimer = null;
    this.el = null;
  }

  async open() {
    if (this.el && (!this.el.querySelector('.settings-nav-wrap') || !this.el.querySelector('[data-cat="system"]'))) {
      this.el.remove();
      this.el = null;
      this._parallaxOn = false;
    }
    if (!this.el) this.build();
    this.el.classList.add('show');
    await this.load();
    this.renderSection();
    this.updateDock3D();
  }

  close() {
    this.el?.classList.remove('show');
  }

  build() {
    const screen = document.createElement('div');
    screen.className = 'settings-screen';
    screen.id = 'settings-screen';
    screen.innerHTML = `
      <div class="settings-bg">
        <div class="settings-circuit"></div>
        <div class="settings-hex-grid"></div>
        <div class="settings-bg-grid"></div>
        <div class="settings-scanlines"></div>
      </div>
      <header class="settings-header">
        <div class="settings-title-wrap">
          <img class="settings-logo-mini" src="assets/boot.png" alt="">
          <div>
            <div class="settings-hud-tag">SYS · CONFIG</div>
            <div class="settings-title">الإعدادات</div>
            <div class="settings-device-name" id="set-header-device">HATAN OS</div>
          </div>
        </div>
        <div class="settings-header-status">
          <span class="settings-status-dot"></span>
          <span>ONLINE</span>
        </div>
        <button class="settings-close" id="settings-close" aria-label="إغلاق">✕</button>
      </header>
      <div class="settings-scene">
        <aside class="settings-nav-wrap">
          <div class="settings-nav-head">MODULES</div>
          <nav class="settings-nav" id="settings-rail" aria-label="أقسام الإعدادات"></nav>
        </aside>
        <div class="settings-panel-stage">
          <div class="settings-panel settings-panel-h">
            <span class="settings-hud-corner tl" aria-hidden="true"></span>
            <span class="settings-hud-corner tr" aria-hidden="true"></span>
            <span class="settings-hud-corner bl" aria-hidden="true"></span>
            <span class="settings-hud-corner br" aria-hidden="true"></span>
            <div class="settings-panel-rim"></div>
            <div class="settings-panel-head">
              <span class="settings-section-code" id="set-panel-code">MOD.01</span>
              <h2 id="set-panel-title">المظهر</h2>
              <p id="set-panel-desc">الخلفية، الألوان والثيمات</p>
            </div>
            <div id="settings-content" class="settings-content-h"></div>
          </div>
        </div>
      </div>
      <footer class="settings-footer">
        <span>HATAN OS · CONTROL PANEL</span>
        <span id="set-footer-module">MOD.01 / المظهر</span>
      </footer>
    `;
    document.body.appendChild(screen);
    this.el = screen;

    screen.querySelector('#settings-close').addEventListener('click', () => this.close());
    this.renderDock();
    this.setupParallax();
  }

  setupParallax() {
    if (this._parallaxOn) return;
    this._parallaxOn = true;
    this.el.addEventListener('mousemove', e => {
      const panel = this.el.querySelector('.settings-panel-h');
      if (!panel) return;
      const rx = ((e.clientY / window.innerHeight) - 0.5) * -1.8;
      const ry = ((e.clientX / window.innerWidth) - 0.5) * 2.5;
      panel.style.transform = `rotateX(${3 + rx}deg) rotateY(${ry}deg)`;
    });
  }

  renderDock() {
    const rail = this.el.querySelector('#settings-rail');
    rail.innerHTML = SETTINGS_CATEGORIES.map((c, i) => `
      <button class="settings-nav-item${c.id === this.category ? ' active' : ''}"
        data-cat="${c.id}" data-i="${i}" type="button">
        <span class="settings-nav-code">${String(i + 1).padStart(2, '0')}</span>
        <span class="settings-nav-icon">${c.icon}</span>
        <span class="settings-nav-text">
          <span class="settings-nav-label">${c.title}</span>
          <span class="settings-nav-desc">${c.desc}</span>
        </span>
        <span class="settings-nav-indicator"></span>
      </button>
    `).join('');

    rail.querySelectorAll('.settings-nav-item').forEach(btn => {
      btn.addEventListener('click', () => this.selectCategory(btn.dataset.cat));
    });
    this.updateDock3D();
  }

  selectCategory(catId) {
    if (catId === this.category) return;
    this.category = catId;
    const cat = SETTINGS_CATEGORIES.find(c => c.id === catId);
    const rail = this.el.querySelector('#settings-rail');
    rail.querySelectorAll('.settings-nav-item').forEach(b => {
      b.classList.toggle('active', b.dataset.cat === catId);
    });
    this.updateDock3D();

    const panel = this.el.querySelector('.settings-panel-h');
    const title = this.el.querySelector('#set-panel-title');
    const desc = this.el.querySelector('#set-panel-desc');
    const code = this.el.querySelector('#set-panel-code');
    const footerMod = this.el.querySelector('#set-footer-module');
    const idx = SETTINGS_CATEGORIES.findIndex(c => c.id === catId);
    const modCode = `MOD.${String(idx + 1).padStart(2, '0')}`;
    if (title) title.textContent = cat.title;
    if (desc) desc.textContent = cat.desc;
    if (code) code.textContent = modCode;
    if (footerMod) footerMod.textContent = `${modCode} / ${cat.title}`;

    if (panel) {
      panel.classList.remove('panel-swap');
      void panel.offsetWidth;
      panel.classList.add('panel-swap');
      setTimeout(() => panel.classList.remove('panel-swap'), 400);
    }
    this.renderSection();
  }

  updateDock3D() {
    const activeBtn = this.el?.querySelector('.settings-nav-item.active');
    if (activeBtn) {
      activeBtn.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  async load() {
    try {
      const res = await fetch('/api/settings');
      this.state = await res.json();
    } catch {
      this.state = { settings: {}, network: {}, storage: [], system: {}, themes: {}, wallpapers: [] };
    }
    this.applyTheme(this.state.settings?.theme);
    const name = this.state.settings?.deviceName || this.state.system?.deviceName || 'HATAN OS';
    const hdr = this.el.querySelector('#set-header-device');
    if (hdr) hdr.textContent = name;
  }

  renderSection() {
    const content = this.el.querySelector('#settings-content');
    if (!content || !this.state) return;

    const s = this.state.settings || {};
    const n = this.state.network || {};
    const audio = this.state.audio || {};
    const devices = this.state.devices || {};
    const sys = this.state.system || {};

    const sections = {
      appearance: () => this.renderAppearance(s),
      sound: () => this.renderSound(s, audio, devices),
      display: () => this.renderSlider('brightness', s.brightness ?? 80, '☀️ السطوع', 'ضبط سطوع الشاشة'),
      device: () => this.renderDevice(s),
      network: () => this.renderNetwork(n, devices),
      language: () => this.renderLanguage(s),
      storage: () => this.renderStorage(this.state.storage || []),
      system: () => this.renderSystem(s),
      about: () => this.renderAbout(sys),
    };

    content.innerHTML = `<div class="settings-section active settings-section-slide">${(sections[this.category] || sections.appearance)()}</div>`;
    this.bindControls();
    if (this.category === 'network') this.loadWifiNetworks();
    this.shell?.gamepadNav?.clear();
  }

  renderAppearance(s) {
    const themes = this.state.themes || {};
    const walls = this.state.wallpapers || [];
    const themeCards = Object.entries(themes).map(([id, t]) => `
      <button type="button" class="set-theme-card${s.theme === id ? ' selected' : ''}" data-theme="${id}">
        <div class="set-theme-swatch">
          <span style="background:${t.primary}"></span>
          <span style="background:${t.accent}"></span>
        </div>
        <label>${t.label}</label>
      </button>
    `).join('');

    const wallCards = walls.map(w => `
      <button type="button" class="set-wall-card${s.wallpaper === w.id ? ' selected' : ''}"
        data-wall="${w.id}" style="background-image:url('${w.url}')">
        <span>${w.label}</span>
      </button>
    `).join('');

    return `
      <p class="set-subtitle">الثيمات</p>
      <div class="set-theme-grid">${themeCards}</div>
      <p class="set-subtitle">الخلفية</p>
      <div class="set-wall-grid">${wallCards}</div>
    `;
  }

  renderSlider(key, value, title, desc) {
    return `
      <div class="set-row">
        <div class="set-label">
          <strong>${title}</strong>
          <span>${desc}</span>
        </div>
        <div class="set-control">
          <div class="set-slider-wrap">
            <input type="range" class="set-slider" data-key="${key}"
              min="0" max="100" value="${value}">
            <span class="set-slider-val" data-val="${key}">${value}%</span>
          </div>
        </div>
      </div>
    `;
  }

  linkLabel(link) {
    const map = {
      usb: 'USB Type-C',
      bluetooth: 'Bluetooth',
      wifi: 'WiFi',
      builtin: 'مدمج',
      display: 'شاشة',
    };
    return map[link] || link;
  }

  renderAudioDeviceList(devices, kind) {
    if (!devices?.length) {
      return `<p class="set-dev-empty">لا توجد أجهزة ${kind === 'output' ? 'إخراج' : 'إدخال'} متاحة</p>`;
    }
    return `
      <div class="set-dev-list">
        ${devices.map(d => `
          <button type="button" class="set-dev-item${d.active ? ' active' : ''}"
            data-audio-kind="${kind}" data-audio-id="${this.esc(d.id)}">
            <span class="set-dev-icon">${d.icon || '🔊'}</span>
            <span class="set-dev-info">
              <strong>${this.esc(d.label || d.name)}</strong>
              <span>${this.linkLabel(d.link)}${d.active ? ' · نشط' : ''}</span>
            </span>
            ${d.active ? '<span class="set-dev-check">✓</span>' : ''}
          </button>
        `).join('')}
      </div>
    `;
  }

  renderConnectedDevices(devices, compact = false) {
    const groups = [
      { key: 'usb', title: '🔌 USB / Type-C', items: devices.usb || [] },
      { key: 'bluetooth', title: '🔵 Bluetooth', items: devices.bluetooth || [] },
      { key: 'wifi', title: '📶 WiFi', items: devices.wifi || [] },
    ];
    return groups.map(g => {
      if (!g.items.length && compact) return '';
      return `
        <p class="set-subtitle">${g.title}</p>
        ${g.items.length ? `
          <div class="set-dev-list">
            ${g.items.map(d => `
              <div class="set-dev-item set-dev-static${d.connected ? ' active' : ''}">
                <span class="set-dev-icon">${d.icon || '📱'}</span>
                <span class="set-dev-info">
                  <strong>${this.esc(d.name || d.label)}</strong>
                  <span>${d.connected ? 'متصل' : 'غير متصل'} · ${this.linkLabel(d.link || d.type)}</span>
                </span>
                ${!compact && d.type === 'bluetooth' && !d.connected ? `
                  <button type="button" class="set-btn set-dev-connect" data-connect-type="bluetooth" data-connect-id="${this.esc(d.id)}">اتصال</button>
                ` : ''}
              </div>
            `).join('')}
          </div>
        ` : `<p class="set-dev-empty">لا أجهزة — ${g.key === 'usb' ? 'وصّل عبر USB Type-C' : 'لا يوجد'}</p>`}
      `;
    }).join('');
  }

  renderSound(s, audio, devices) {
    const vol = s.volume ?? 75;
    return `
      ${this.renderSlider('volume', vol, '🔊 مستوى الصوت', 'مستوى الصوت العام للنظام')}

      <p class="set-subtitle">🔈 أجهزة الإخراج (سماعات / سماعة رأس)</p>
      ${this.renderAudioDeviceList(audio.outputs || [], 'output')}

      <p class="set-subtitle">🎤 أجهزة الإدخال (ميكروفون)</p>
      ${this.renderAudioDeviceList(audio.inputs || [], 'input')}

      <div class="set-shortcuts-note" style="margin-top:18px">
        <span>🔌</span>
        <span>
          يدعم HATAN OS اتصال الأجهزة عبر <strong>USB Type-C</strong>،
          <strong>Bluetooth</strong>، و<strong>WiFi</strong>.
          عند توصيل سماعة أو ميكروفون جديد يظهر تلقائياً في القائمة.
        </span>
      </div>

      <p class="set-subtitle">📱 الأجهزة المتصلة</p>
      ${this.renderConnectedDevices(devices, true)}
    `;
  }

  renderDevice(s) {
    const map = normalizeButtonMap(s.buttonMap);
    const slot = (id, pos) => {
      const btn = HATAN_DECK_BUTTONS.find(b => b.id === id);
      return this.renderDeckSlot(btn, map[id] || 'none', pos);
    };

    return `
      <div class="set-row">
        <div class="set-label">
          <strong>اسم الجهاز</strong>
          <span>يظهر في الشاشة الرئيسية والإعدادات</span>
        </div>
        <div class="set-control">
          <input type="text" class="set-input" id="set-device-name" value="${this.esc(s.deviceName || '')}">
        </div>
      </div>

      <div class="set-shortcuts-note">
        <span>ℹ️</span>
        <span>
          <strong>ملاحظة:</strong> الاختصارات تعمل فقط داخل نظام HATAN OS (الشاشة الرئيسية والإعدادات)
          ولا تعمل داخل الألعاب أو التطبيقات الأخرى.
          اضغط على المربع □ بجانب كل زر لاختيار وظيفته.
        </span>
      </div>

      <p class="set-subtitle">خريطة أزرار Steam Deck</p>
      <div class="deck-layout">
        <div class="deck-row shoulders">
          ${slot('L1')}${slot('R1')}
        </div>
        <div class="deck-row triggers">
          ${slot('L2')}${slot('R2')}
        </div>
        <div class="deck-row" style="justify-content:space-between;align-items:flex-start;padding:0 20px">
          <div class="deck-dpad">
            ${slot('DPAD_UP', 'pos-up')}
            ${slot('DPAD_LEFT', 'pos-left')}
            ${slot('DPAD_DOWN', 'pos-down')}
            ${slot('DPAD_RIGHT', 'pos-right')}
          </div>
          <div class="deck-face-grid">
            ${slot('Y', 'pos-y')}
            ${slot('X', 'pos-x')}
            ${slot('B', 'pos-b')}
            ${slot('A', 'pos-a')}
          </div>
          <div style="width:120px"></div>
        </div>
        <div class="deck-row sticks">
          ${slot('L3')}${slot('R3')}
        </div>
        <div class="deck-row center">
          ${slot('SELECT')}${slot('STEAM')}${slot('QAM')}${slot('START')}
        </div>
        <div class="deck-row rear">
          ${slot('L4')}
          <span class="deck-btn-label">أزرار خلفية</span>
          ${slot('R4')}
        </div>
      </div>
    `;
  }

  renderDeckSlot(btn, actionId, posClass = '') {
    if (!btn) return '';
    const colorClass = btn.color ? ` face ${btn.color}` : ` ${btn.group || ''}`;
    const title = btn.title || btn.label;
    return `
      <div class="deck-slot ${posClass}" data-deck-slot="${btn.id}">
        <div class="deck-btn${colorClass}" title="${title}">${btn.label}</div>
        <button type="button" class="deck-action-pick" data-btn="${btn.id}" data-action="${actionId}">
          <span class="pick-icon">${getActionIcon(actionId)}</span>
          <span class="pick-label">${this.esc(getActionLabel(actionId))}</span>
        </button>
      </div>
    `;
  }

  openActionPicker(btnId, currentAction) {
    let modal = document.getElementById('set-action-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'set-action-modal';
      modal.className = 'set-action-modal';
      modal.innerHTML = `
        <div class="set-action-modal-box">
          <div class="set-action-modal-head">
            <h3 id="set-action-modal-title">اختر الوظيفة</h3>
            <button type="button" class="settings-close" id="set-action-modal-close">✕</button>
          </div>
          <div class="set-action-grid" id="set-action-grid"></div>
        </div>
      `;
      document.body.appendChild(modal);
      modal.querySelector('#set-action-modal-close').addEventListener('click', () => modal.classList.remove('show'));
      modal.addEventListener('click', e => {
        if (e.target === modal) modal.classList.remove('show');
      });
    }

    const btn = HATAN_DECK_BUTTONS.find(b => b.id === btnId);
    modal.querySelector('#set-action-modal-title').textContent =
      `زر ${btn?.title || btn?.label || btnId} — اختر الوظيفة`;

    const grid = modal.querySelector('#set-action-grid');
    grid.innerHTML = HATAN_SHORTCUT_ACTIONS.map(a => `
      <button type="button" class="set-action-tile${a.id === currentAction ? ' selected' : ''}"
        data-action="${a.id}">
        <span class="tile-icon">${a.icon}</span>
        <span class="tile-label">${a.label}</span>
      </button>
    `).join('');

    grid.querySelectorAll('.set-action-tile').forEach(tile => {
      tile.addEventListener('click', () => {
        const action = tile.dataset.action;
        const map = normalizeButtonMap(this.state.settings?.buttonMap);
        map[btnId] = action;
        this.save({ buttonMap: map });
        this.shell?.shortcuts?.updateMap(map);
        modal.classList.remove('show');
        this.renderSection();
      });
    });

    modal.classList.add('show');
  }

  renderNetwork(n, devices) {
    const wifi = n.wifi || {};
    const bt = n.bluetooth || {};
    const vpn = n.vpn || {};
    const dev = devices || { usb: n.usb || [], bluetooth: bt.devices || [], wifi: [] };
    return `
      <div class="set-shortcuts-note">
        <span>📡</span>
        <span>
          اتصل بالأجهزة عبر <strong>USB Type-C</strong> (توصيل وشحن)،
          <strong>Bluetooth</strong> (سماعات ووحدات تحكم)،
          أو <strong>WiFi</strong> (شبكة لاسلكية).
        </span>
      </div>

      <div class="set-row">
        <div class="set-label">
          <strong>WiFi</strong>
          <span>${wifi.connected && wifi.connected !== '—' ? wifi.connected : 'غير متصل'}
            <span class="set-net-status${wifi.enabled ? ' live' : ''}">${wifi.enabled ? 'مفعّل' : 'معطّل'}</span>
          </span>
        </div>
        <div class="set-control" style="display:flex;gap:8px;align-items:center">
          <button type="button" class="set-toggle${wifi.enabled ? ' on' : ''}" data-net="wifi"></button>
          <button type="button" class="set-btn set-btn-primary" data-open-net="wifi">إدارة WiFi</button>
        </div>
      </div>
      <div class="set-row">
        <div class="set-label">
          <strong>Bluetooth</strong>
          <span>
            <span class="set-net-status${bt.enabled ? ' live' : ''}">${bt.enabled ? 'مفعّل' : 'معطّل'}</span>
          </span>
        </div>
        <div class="set-control" style="display:flex;gap:8px;align-items:center">
          <button type="button" class="set-toggle${bt.enabled ? ' on' : ''}" data-net="bluetooth"></button>
          <button type="button" class="set-btn" id="set-bt-scan">بحث</button>
          <button type="button" class="set-btn set-btn-primary" data-open-net="bluetooth">إدارة</button>
        </div>
      </div>
      <div class="set-row">
        <div class="set-label">
          <strong>USB Type-C</strong>
          <span>${(dev.usb || []).length ? `${dev.usb.length} جهاز متصل` : 'وصّل جهازاً عبر منفذ USB-C'}</span>
        </div>
        <div class="set-control">
          <button type="button" class="set-btn" data-connect-type="usb" data-connect-id="scan">تحديث</button>
        </div>
      </div>
      <div class="set-row">
        <div class="set-label">
          <strong>VPN</strong>
          <span>${vpn.active && vpn.active !== '—' ? vpn.active : 'لا يوجد اتصال VPN نشط'}</span>
        </div>
        <div class="set-control">
          <button type="button" class="set-btn set-btn-primary" data-open-net="vpn">إعداد VPN</button>
        </div>
      </div>

      <p class="set-subtitle">الأجهزة المتصلة</p>
      ${this.renderConnectedDevices(dev)}

      <p class="set-subtitle">شبكات WiFi المتاحة</p>
      <div class="set-wifi-list" id="set-wifi-list">
        <p class="set-dev-empty">جاري تحميل الشبكات...</p>
      </div>
    `;
  }

  async loadWifiNetworks() {
    const list = this.el?.querySelector('#set-wifi-list');
    if (!list) return;
    try {
      const res = await fetch('/api/wifi/networks');
      const data = await res.json();
      const nets = data.networks || [];
      if (!nets.length) {
        list.innerHTML = '<p class="set-dev-empty">لا توجد شبكات WiFi</p>';
        return;
      }
      list.innerHTML = nets.map(n => `
        <button type="button" class="set-dev-item${n.active ? ' active' : ''}" data-wifi-ssid="${this.esc(n.ssid)}">
          <span class="set-dev-icon">📶</span>
          <span class="set-dev-info">
            <strong>${this.esc(n.ssid)}</strong>
            <span>${n.signal}% · ${this.esc(n.security)}${n.active ? ' · متصل' : ''}</span>
          </span>
          ${n.active ? '<span class="set-dev-check">✓</span>' : ''}
        </button>
      `).join('');
      list.querySelectorAll('[data-wifi-ssid]').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ssid = btn.dataset.wifiSsid;
          const pwd = ssid.includes('Guest') ? '' : prompt(`كلمة مرور "${ssid}":`) || '';
          await fetch('/api/wifi/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ssid, password: pwd }),
          });
          await this.load();
          this.renderSection();
        });
      });
    } catch {
      list.innerHTML = '<p class="set-dev-empty">تعذّر تحميل الشبكات</p>';
    }
  }

  renderSystem(s) {
    const upd = this.state.updates || { available: 0 };
    return `
      <div class="set-row">
        <div class="set-label">
          <strong>إظهار الساعة</strong>
          <span>في شريط الحالة العلوي</span>
        </div>
        <div class="set-control">
          <button type="button" class="set-toggle${s.showClock !== false ? ' on' : ''}" data-key="showClock"></button>
        </div>
      </div>
      <div class="set-row">
        <div class="set-label">
          <strong>إظهار البطارية</strong>
          <span>نسبة الشحن في شريط الحالة</span>
        </div>
        <div class="set-control">
          <button type="button" class="set-toggle${s.showBattery !== false ? ' on' : ''}" data-key="showBattery"></button>
        </div>
      </div>

      <p class="set-subtitle">تحديثات النظام</p>
      <div class="set-row">
        <div class="set-label">
          <strong>حزم متاحة</strong>
          <span>${upd.available || 0} تحديث${upd.preview ? ' (معاينة)' : ''}</span>
        </div>
        <div class="set-control" style="display:flex;gap:8px">
          <button type="button" class="set-btn" id="set-update-check">فحص</button>
          <button type="button" class="set-btn set-btn-primary" id="set-update-run">تحديث</button>
        </div>
      </div>

      <p class="set-subtitle">الطاقة</p>
      <div class="set-power-grid">
        <button type="button" class="set-btn" data-power="suspend">💤 إيقاف مؤقت</button>
        <button type="button" class="set-btn" data-power="reboot">🔄 إعادة تشغيل</button>
        <button type="button" class="set-btn" data-power="shutdown">⏻ إيقاف</button>
      </div>
    `;
  }

  renderLanguage(s) {
    return `
      <div class="set-row">
        <div class="set-label">
          <strong>لغة النظام</strong>
          <span>لغة واجهة HATAN OS</span>
        </div>
        <div class="set-control">
          <select class="set-select" data-key="language">
            ${LANG_OPTIONS.map(o => `<option value="${o.id}"${s.language === o.id ? ' selected' : ''}>${o.label}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="set-row">
        <div class="set-label">
          <strong>لوحة المفاتيح</strong>
          <span>تخطيط لوحة المفاتيح الافتراضي</span>
        </div>
        <div class="set-control">
          <select class="set-select" data-key="keyboard">
            ${KB_OPTIONS.map(o => `<option value="${o.id}"${s.keyboard === o.id ? ' selected' : ''}>${o.label}</option>`).join('')}
          </select>
        </div>
      </div>
    `;
  }

  renderStorage(items) {
    if (!items.length) {
      return '<p style="color:var(--text-muted);padding:20px 0">لا توجد بيانات تخزين</p>';
    }
    return `
      <div class="set-storage-list">
        ${items.map(d => `
          <div class="set-storage-item">
            <div class="set-storage-head">
              <strong>${this.esc(d.mount)}</strong>
              <span>${d.used} / ${d.size} — متبقي ${d.free}</span>
            </div>
            <div class="set-storage-bar">
              <div class="set-storage-fill" style="width:${Math.min(100, parseInt(d.percent, 10) || 0)}%"></div>
            </div>
          </div>
        `).join('')}
      </div>
    `;
  }

  renderAbout(sys) {
    const specs = [
      { icon: '💻', label: 'المعالج', value: sys.cpu },
      { icon: '🎮', label: 'كرت الشاشة', value: sys.gpu },
      { icon: '🧠', label: 'الذاكرة', value: sys.ram },
      { icon: '📺', label: 'الشاشة', value: sys.display },
      { icon: '💾', label: 'التخزين', value: sys.storage ? `${sys.storage.used} / ${sys.storage.size}` : '—' },
      { icon: '🐧', label: 'النواة', value: sys.kernel },
      { icon: '🏷️', label: 'اسم الجهاز', value: sys.hostname || sys.deviceName },
      { icon: '⚙️', label: 'المنصة', value: `${sys.platform || 'Linux'} · ${sys.arch || 'x86_64'}` },
    ];
    return `
      <div class="set-about-hero">
        <img src="assets/boot.png" alt="">
        <h3>${this.esc(sys.system || 'HATAN OS')}</h3>
        <p>${this.esc(sys.version || '0.1.0')} · ${this.esc(sys.codename || 'Genesis')}</p>
      </div>
      <div class="set-spec-grid">
        ${specs.map(sp => `
          <div class="set-spec-card">
            <div class="set-spec-icon">${sp.icon}</div>
            <dt>${sp.label}</dt>
            <dd>${this.esc(sp.value || '—')}</dd>
          </div>
        `).join('')}
      </div>
    `;
  }

  bindControls() {
    const root = this.el.querySelector('#settings-content');

    root.querySelectorAll('.set-slider').forEach(slider => {
      slider.addEventListener('input', () => {
        const key = slider.dataset.key;
        const val = parseInt(slider.value, 10);
        root.querySelector(`[data-val="${key}"]`).textContent = `${val}%`;
        this.debounceSave({ [key]: val });
      });
    });

    root.querySelectorAll('.set-theme-card').forEach(card => {
      card.addEventListener('click', () => {
        const theme = card.dataset.theme;
        root.querySelectorAll('.set-theme-card').forEach(c => c.classList.toggle('selected', c === card));
        this.applyTheme(theme);
        this.save({ theme });
      });
    });

    root.querySelectorAll('.set-wall-card').forEach(card => {
      card.addEventListener('click', () => {
        const wall = card.dataset.wall;
        root.querySelectorAll('.set-wall-card').forEach(c => c.classList.toggle('selected', c === card));
        this.applyWallpaper(wall);
        this.save({ wallpaper: wall });
      });
    });

    const deviceInput = root.querySelector('#set-device-name');
    if (deviceInput) {
      deviceInput.addEventListener('change', () => {
        const name = deviceInput.value.trim() || 'Steam Deck';
        this.save({ deviceName: name });
        const hdr = this.el.querySelector('#set-header-device');
        if (hdr) hdr.textContent = name;
        const brand = document.getElementById('home-brand');
        if (brand) brand.textContent = name;
      });
    }

    root.querySelectorAll('.deck-action-pick').forEach(pick => {
      pick.addEventListener('click', () => {
        this.openActionPicker(pick.dataset.btn, pick.dataset.action);
      });
    });

    root.querySelectorAll('.set-select[data-key]').forEach(sel => {
      sel.addEventListener('change', () => this.save({ [sel.dataset.key]: sel.value }));
    });

    root.querySelectorAll('.set-toggle[data-key]').forEach(tog => {
      tog.addEventListener('click', () => {
        const key = tog.dataset.key;
        const on = !tog.classList.contains('on');
        tog.classList.toggle('on', on);
        this.save({ [key]: on });
        this.shell?.statusBar?.tick();
      });
    });

    root.querySelector('#set-update-check')?.addEventListener('click', async () => {
      try {
        const res = await fetch('/api/updates');
        this.state.updates = await res.json();
        this.renderSection();
      } catch { /* preview */ }
    });

    root.querySelector('#set-update-run')?.addEventListener('click', async () => {
      if (!confirm('تحديث النظام الآن؟')) return;
      await fetch('/api/system', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'update' }),
      }).catch(() => {});
    });

    root.querySelectorAll('[data-power]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const action = btn.dataset.power;
        const labels = { suspend: 'إيقاف مؤقت', reboot: 'إعادة تشغيل', shutdown: 'إيقاف' };
        if (!confirm(`${labels[action]}؟`)) return;
        await fetch('/api/system', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action }),
        }).catch(() => {});
      });
    });

    root.querySelectorAll('.set-toggle[data-net]').forEach(tog => {
      tog.addEventListener('click', async () => {
        const radio = tog.dataset.net;
        const on = !tog.classList.contains('on');
        tog.classList.toggle('on', on);
        try {
          const res = await fetch('/api/network/toggle', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ radio, on }),
          });
          this.state.network = await res.json();
          this.renderSection();
        } catch { /* preview */ }
      });
    });

    root.querySelectorAll('[data-open-net]').forEach(btn => {
      btn.addEventListener('click', () => {
        fetch('/api/network/open', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ tool: btn.dataset.openNet }),
        }).catch(() => {});
      });
    });

    root.querySelectorAll('[data-audio-kind]').forEach(btn => {
      btn.addEventListener('click', async () => {
        try {
          const res = await fetch('/api/audio/default', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kind: btn.dataset.audioKind, id: btn.dataset.audioId }),
          });
          this.state.audio = await res.json();
          this.renderSection();
        } catch { /* preview */ }
      });
    });

    root.querySelectorAll('[data-connect-type]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const type = btn.dataset.connectType;
        if (type === 'usb' && btn.dataset.connectId === 'scan') {
          await this.load();
          this.renderSection();
          return;
        }
        try {
          await fetch('/api/devices/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, id: btn.dataset.connectId }),
          });
          await this.load();
          this.renderSection();
        } catch { /* preview */ }
      });
    });

    root.querySelector('#set-bt-scan')?.addEventListener('click', async () => {
      try {
        await fetch('/api/devices/scan', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ type: 'bluetooth' }),
        });
        await this.load();
        this.renderSection();
      } catch { /* preview */ }
    });
  }

  applyTheme(themeId) {
    const themes = this.state?.themes || {
      hatan: { primary: '#2563EB', accent: '#22D3EE' },
      aurora: { primary: '#6366F1', accent: '#A78BFA' },
      crimson: { primary: '#6366F1', accent: '#A78BFA' },
      cyan: { primary: '#0891B2', accent: '#22D3EE' },
      gold: { primary: '#C9A227', accent: '#FFD700' },
    };
    const t = themes[themeId] || themes.hatan;
    document.documentElement.style.setProperty('--primary', t.primary);
    document.documentElement.style.setProperty('--accent', t.primary);
    document.documentElement.style.setProperty('--electric', t.accent);
    document.documentElement.style.setProperty('--electric-dim', t.accent);
  }

  applyWallpaper(wallId) {
    const walls = this.state?.wallpapers || [];
    const w = walls.find(x => x.id === wallId) || walls[0];
    if (!w) return;
    const bg = document.getElementById('home-bg-image');
    if (bg) bg.style.backgroundImage = `url('${w.url}')`;
  }

  debounceSave(patch) {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.save(patch), 350);
  }

  async save(patch) {
    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(patch),
      });
      this.state = await res.json();
      if (patch.theme) this.applyTheme(patch.theme);
      if (patch.wallpaper) this.applyWallpaper(patch.wallpaper);
      if (patch.buttonMap) this.shell?.shortcuts?.updateMap(this.state.settings?.buttonMap);
    } catch { /* offline preview */ }
  }

  esc(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/"/g, '&quot;');
  }

  static async applySavedTheme() {
    try {
      const res = await fetch('/api/settings');
      const data = await res.json();
      const s = data.settings || {};
      const themes = data.themes || {};
      const t = themes[s.theme] || themes.hatan;
      if (t) {
        document.documentElement.style.setProperty('--primary', t.primary);
        document.documentElement.style.setProperty('--accent', t.primary);
        document.documentElement.style.setProperty('--electric', t.accent);
        document.documentElement.style.setProperty('--electric-dim', t.accent);
      }
      const walls = data.wallpapers || [];
      const w = walls.find(x => x.id === s.wallpaper) || walls[0];
      const bg = document.getElementById('home-bg-image');
      if (bg && w) bg.style.backgroundImage = `url('${w.url}')`;
      const brand = document.getElementById('home-brand');
      if (brand && s.deviceName) brand.textContent = s.deviceName;
      return data;
    } catch {
      return null;
    }
  }
}
