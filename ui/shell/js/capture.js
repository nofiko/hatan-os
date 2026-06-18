// HATAN OS — تطبيق تصوير الشاشة (فيديو)

const CAPTURE_BUTTONS = [
  { id: 'A', label: 'A', color: 'a' },
  { id: 'B', label: 'B', color: 'b' },
  { id: 'X', label: 'X', color: 'x' },
  { id: 'Y', label: 'Y', color: 'y' },
  { id: 'L1', label: 'L1' }, { id: 'R1', label: 'R1' },
  { id: 'L2', label: 'L2' }, { id: 'R2', label: 'R2' },
  { id: 'L3', label: 'L3' }, { id: 'R3', label: 'R3' },
  { id: 'L4', label: 'L4' }, { id: 'R4', label: 'R4' },
  { id: 'SELECT', label: 'View' },
  { id: 'START', label: 'Menu' },
  { id: 'STEAM', label: 'Steam' },
  { id: 'QAM', label: 'QAM' },
  { id: 'DPAD_UP', label: '▲' },
  { id: 'DPAD_DOWN', label: '▼' },
  { id: 'DPAD_LEFT', label: '◀' },
  { id: 'DPAD_RIGHT', label: '▶' },
];

class HATANCapture {
  constructor(shell) {
    this.shell = shell;
    this.state = null;
    this.el = null;
    this.pollTimer = null;
    this.listenPoll = null;
  }

  async open() {
    if (!this.el) this.build();
    this.el.classList.add('show');
    await this.load();
    this.startPolling();
  }

  close() {
    this.el?.classList.remove('show');
    this.stopPolling();
    this.stopListenPoll();
    fetch('/api/capture', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'listen-stop' }),
    }).catch(() => {});
  }

  build() {
    const screen = document.createElement('div');
    screen.className = 'capture-screen';
    screen.id = 'capture-screen';
    screen.innerHTML = `
      <div class="capture-bg"></div>
      <header class="capture-header">
        <div>
          <div class="capture-title">🎬 تصوير الشاشة</div>
          <div class="capture-subtitle">تسجيل فيديو باختصار يعمل في كل مكان</div>
        </div>
        <button class="settings-close" id="capture-close" aria-label="إغلاق">✕</button>
      </header>
      <div class="capture-layout" id="capture-body"></div>
    `;
    document.body.appendChild(screen);
    this.el = screen;
    screen.querySelector('#capture-close').addEventListener('click', () => this.close());
  }

  async load() {
    try {
      const res = await fetch('/api/capture');
      this.state = await res.json();
    } catch {
      this.state = { settings: {}, status: {}, recordings: [] };
    }
    this.render();
  }

  render() {
    const body = this.el.querySelector('#capture-body');
    if (!body || !this.state) return;

    const s = this.state.settings || {};
    const st = this.state.status || {};
    const recs = this.state.recordings || [];
    const btn = s.recordButton || 'R4';
    const recording = !!st.recording;
    const listening = !!st.listening;
    const enabled = s.enabled !== false;
    const daemon = !!st.daemon;

    body.innerHTML = `
      <div class="capture-main">
        <div class="capture-hero">
          <div class="capture-rec-indicator${recording ? ' recording' : ''}${listening ? ' listening' : ''}">
            ${recording ? '⏺' : listening ? '👂' : '🎬'}
          </div>
          <div class="capture-hero-text">
            <h2>${recording ? 'جاري التسجيل...' : listening ? 'اضغط الزر على جهازك لتعيينه' : 'جاهز للتسجيل'}</h2>
            <p>${recording
              ? 'اضغط نفس الزر مرة أخرى لإيقاف التسجيل'
              : 'يُحفظ الفيديو في مجلد Videos/HATAN'}
            </p>
            <div class="capture-assigned">
              زر التسجيل: <strong>${btn}</strong>
              ${enabled ? '· مفعّل' : '· معطّل'}
            </div>
          </div>
        </div>

        <div class="capture-global-note">
          <span>🌐</span>
          <span>
            <strong>يعمل في كل مكان:</strong> هذا الاختصار يعمل داخل نظام HATAN OS
            <strong>وخارجه</strong> — في الألعاب، Steam، المتصفح، وجميع التطبيقات.
            خدمة خلفية تراقب زر الـ Steam Deck على مستوى النظام.
          </span>
        </div>

        <div class="capture-section">
          <h3>□ اختر زر تسجيل الشاشة (فيديو)</h3>
          <div class="capture-btn-grid">
            ${CAPTURE_BUTTONS.map(b => `
              <button type="button" class="cap-btn-chip${btn === b.id ? ' selected' : ''}" data-cap-btn="${b.id}">
                <span class="chip-key ${b.color || 'other'}">${b.label}</span>
                <span class="chip-name">${b.id}</span>
              </button>
            `).join('')}
          </div>
          <div class="capture-actions-row">
            <button type="button" class="cap-action-btn listen${listening ? ' active' : ''}" id="cap-listen-btn">
              ${listening ? '⏹ إلغاء الاستماع' : '🎮 استمع للزر (من الجهاز)'}
            </button>
            <button type="button" class="cap-action-btn primary" id="cap-test-btn">
              ${recording ? '⏹ إيقاف التسجيل' : '⏺ تجربة التسجيل الآن'}
            </button>
          </div>
        </div>
      </div>

      <aside class="capture-side">
        <div class="capture-side-card">
          <h4>الإعدادات</h4>
          <div class="cap-toggle-row">
            <span>تفعيل الاختصار العالمي</span>
            <button type="button" class="set-toggle${enabled ? ' on' : ''}" id="cap-enabled"></button>
          </div>
          <div class="cap-toggle-row">
            <span>تسجيل الصوت</span>
            <button type="button" class="set-toggle${s.includeAudio !== false ? ' on' : ''}" id="cap-audio"></button>
          </div>
          <div class="cap-toggle-row">
            <span>خدمة النظام</span>
            <span class="cap-status-dot${daemon ? ' on' : ' off'}">${daemon ? 'تعمل' : 'متوقفة (Linux)'}</span>
          </div>
        </div>
        <div class="capture-side-card">
          <h4>آخر التسجيلات</h4>
          <div class="cap-record-list">
            ${recs.length ? recs.map(r => `
              <div class="cap-record-item">
                <span>${this.esc(r.name)}</span>
                <span>${this.esc(r.size || '')}</span>
              </div>
            `).join('') : '<p style="color:var(--text-muted);font-size:0.78rem">لا توجد تسجيلات بعد</p>'}
          </div>
        </div>
      </aside>
    `;

    this.bindEvents();
  }

  bindEvents() {
    const root = this.el.querySelector('#capture-body');

    root.querySelectorAll('[data-cap-btn]').forEach(chip => {
      chip.addEventListener('click', () => {
        this.save({ recordButton: chip.dataset.capBtn });
      });
    });

    root.querySelector('#cap-enabled')?.addEventListener('click', (e) => {
      const on = !e.target.classList.contains('on');
      e.target.classList.toggle('on', on);
      this.save({ enabled: on });
    });

    root.querySelector('#cap-audio')?.addEventListener('click', (e) => {
      const on = !e.target.classList.contains('on');
      e.target.classList.toggle('on', on);
      this.save({ includeAudio: on });
    });

    root.querySelector('#cap-listen-btn')?.addEventListener('click', () => this.toggleListen());

    root.querySelector('#cap-test-btn')?.addEventListener('click', () => this.testRecord());
  }

  async save(patch) {
    try {
      const res = await fetch('/api/capture', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'save', settings: patch }),
      });
      this.state = await res.json();
    } catch {
      this.state.settings = { ...this.state.settings, ...patch };
    }
    this.render();
  }

  async toggleListen() {
    const listening = this.state?.status?.listening;
    const action = listening ? 'listen-stop' : 'listen';
    try {
      const res = await fetch('/api/capture', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
      const data = await res.json();
      if (this.state) this.state.status = data.status || data;
    } catch { /* preview */ }

    if (!listening) {
      this.startListenPoll();
      this._gamepadListen();
    } else {
      this.stopListenPoll();
    }
    this.render();
  }

  _gamepadListen() {
    this._gpListenActive = true;
    this._gpPressed = new Set();
    const map = {};
    if (typeof GP_INDEX_TO_BTN !== 'undefined') {
      Object.assign(map, GP_INDEX_TO_BTN);
    }
    const loop = () => {
      if (!this._gpListenActive) return;
      const pads = navigator.getGamepads?.();
      if (pads) {
        for (const gp of pads) {
          if (!gp) continue;
          for (const [idx, btnId] of Object.entries(map)) {
            const btn = gp.buttons[parseInt(idx, 10)];
            if (!btn) continue;
            const key = `${gp.index}:${btnId}`;
            if ((btn.pressed || btn.value > 0.5) && !this._gpPressed.has(key)) {
              this._gpPressed.add(key);
              this.save({ recordButton: btnId });
              fetch('/api/capture', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'listen-stop' }),
              }).catch(() => {});
              this._gpListenActive = false;
              this.stopListenPoll();
              return;
            }
            if (!btn.pressed && btn.value <= 0.5) this._gpPressed.delete(key);
          }
        }
      }
      if (this._gpListenActive) requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  startListenPoll() {
    this.stopListenPoll();
    this.listenPoll = setInterval(async () => {
      try {
        const res = await fetch('/api/capture');
        const data = await res.json();
        const wasListening = this.state?.status?.listening;
        this.state = data;
        if (wasListening && !data.status?.listening && data.settings?.recordButton) {
          this.stopListenPoll();
          this.render();
        }
      } catch { /* ignore */ }
    }, 800);
  }

  stopListenPoll() {
    if (this.listenPoll) clearInterval(this.listenPoll);
    this.listenPoll = null;
    this._gpListenActive = false;
  }

  async testRecord() {
    try {
      const res = await fetch('/api/capture', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'toggle' }),
      });
      const data = await res.json();
      if (this.state) this.state.status = data.status || data;
    } catch { /* preview */ }
    this.render();
  }

  startPolling() {
    this.stopPolling();
    this.pollTimer = setInterval(async () => {
      if (!this.el?.classList.contains('show')) return;
      try {
        const res = await fetch('/api/capture');
        const data = await res.json();
        const wasRec = this.state?.status?.recording;
        this.state = data;
        if (wasRec !== data.status?.recording) this.render();
      } catch { /* ignore */ }
    }, 2000);
  }

  stopPolling() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.pollTimer = null;
  }

  esc(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/"/g, '&quot;');
  }
}
