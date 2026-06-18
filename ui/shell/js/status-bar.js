// HATAN OS — شريط الحالة (ساعة، بطارية، WiFi)

class HATANStatusBar {
  constructor() {
    this.el = null;
    this.timer = null;
    this.config = { showClock: true, showBattery: true };
  }

  mount() {
    if (this.el) return;
    this.el = document.createElement('div');
    this.el.className = 'hat-status-bar';
    this.el.id = 'hat-status-bar';
    this.el.innerHTML = `
      <div class="hat-status-left">
        <span class="hat-status-wifi" id="hat-st-wifi" title="WiFi">📶 —</span>
      </div>
      <div class="hat-status-right">
        <span class="hat-status-battery" id="hat-st-battery" hidden>🔋 —%</span>
        <span class="hat-status-time" id="hat-st-time" hidden>00:00</span>
      </div>
    `;
    document.body.appendChild(this.el);
    this.tick();
    this.timer = setInterval(() => this.tick(), 15000);
  }

  async tick() {
    let data = {};
    try {
      const res = await fetch('/api/status');
      data = await res.json();
    } catch {
      data = {
        time: new Date().toLocaleTimeString('ar', { hour: '2-digit', minute: '2-digit', hour12: false }),
        showClock: true,
        showBattery: true,
        battery: { percent: 78, charging: false },
        wifi: { enabled: true, connected: '—' },
      };
    }

    this.config.showClock = data.showClock !== false;
    this.config.showBattery = data.showBattery !== false;

    const timeEl = document.getElementById('hat-st-time');
    const batEl = document.getElementById('hat-st-battery');
    const wifiEl = document.getElementById('hat-st-wifi');

    if (timeEl) {
      timeEl.hidden = !this.config.showClock;
      timeEl.textContent = data.time || this.localTime();
    }
    if (batEl) {
      batEl.hidden = !this.config.showBattery;
      const b = data.battery || {};
      const pct = b.percent ?? '—';
      const icon = b.charging ? '⚡' : '🔋';
      batEl.textContent = `${icon} ${pct}%`;
      batEl.classList.toggle('charging', !!b.charging);
      batEl.classList.toggle('low', typeof pct === 'number' && pct < 20);
    }
    if (wifiEl) {
      const w = data.wifi || {};
      const label = w.enabled
        ? (w.connected && w.connected !== '—' ? w.connected : 'WiFi')
        : 'WiFi Off';
      wifiEl.textContent = `📶 ${label}`;
      wifiEl.classList.toggle('live', !!w.enabled);
    }

    if (this.el) {
      this.el.classList.toggle('visible', this.isVisible());
    }
  }

  localTime() {
    return new Date().toLocaleTimeString('ar', { hour: '2-digit', minute: '2-digit', hour12: false });
  }

  isVisible() {
    const home = document.getElementById('home-screen');
    const settings = document.getElementById('settings-screen');
    return !!(home?.classList.contains('show') || settings?.classList.contains('show'));
  }

  show() {
    this.el?.classList.add('visible');
  }

  hide() {
    this.el?.classList.remove('visible');
  }

  destroy() {
    clearInterval(this.timer);
    this.el?.remove();
    this.el = null;
  }
}
