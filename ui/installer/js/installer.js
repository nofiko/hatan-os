// HATAN OS — المثبّت الرسومي

class HATANInstaller {
  constructor() {
    this.stepIndex = 0;
    this.steps = HATAN_INSTALLER.steps;
    this.isRoot = false;
    this.isLiveIso = false;
    this.isOnline = true;
    this.wifiConnected = false;
    this.installing = false;
    this.pollTimer = null;
    this.selectedSsid = '';

    this.init();
  }

  init() {
    document.getElementById('installer-title').textContent = HATAN_INSTALLER.name;
    document.getElementById('brand-title').textContent = HATAN_INSTALLER.tagline;
    document.getElementById('brand-desc').textContent = HATAN_INSTALLER.description;

    this.renderStepDots();
    this.renderPhases('install-phases-progress', true);
    this.renderCompleteApps();
    this.bindEvents();
    this.checkRoot().then(() => this.maybeAutoInstall());
  }

  async maybeAutoInstall() {
    const params = new URLSearchParams(location.search);
    if (params.get('autoinstall') !== '1') return;
    this.isRoot = true;
    if (this.isLiveIso && !this.isOnline) {
      this.showStep(this.steps.indexOf('wifi'));
      await this.scanNetworks();
      return;
    }
    this.showStep(this.steps.indexOf('confirm'));
    setTimeout(() => this.startInstall(), 2500);
  }

  renderStepDots() {
    const el = document.getElementById('step-indicator');
    el.innerHTML = this.steps.map((_, i) =>
      `<div class="step-dot${i === 0 ? ' active' : ''}" data-i="${i}"></div>`
    ).join('');
  }

  renderPhases(containerId, track = false) {
    const el = document.getElementById(containerId);
    if (!el) return;

    el.innerHTML = HATAN_INSTALLER.installPhases.map(p => `
      <div class="phase-box${track ? '' : ''}" data-phase="${p.id}">
        <span class="phase-num">${p.order}</span>
        <strong class="phase-label">${p.label}</strong>
      </div>
    `).join('');
  }

  setActivePhase(phaseId) {
    document.querySelectorAll('#install-phases-progress .phase-box').forEach(box => {
      const id = box.dataset.phase;
      box.classList.toggle('active', id === phaseId);
      box.classList.toggle('done', id === 'system' && phaseId === 'apps');
    });
  }

  renderCompleteApps() {
    const el = document.getElementById('complete-apps');
    if (!el) return;
    el.innerHTML = HATAN_INSTALLER.defaultApps
      .map(a => `<span class="app-badge">${a.name}</span>`).join('');
  }

  bindEvents() {
    document.getElementById('btn-next').addEventListener('click', () => this.next());
    document.getElementById('btn-back').addEventListener('click', () => this.back());
    document.getElementById('wifi-scan-btn')?.addEventListener('click', () => this.scanNetworks());
    document.getElementById('wifi-connect-btn')?.addEventListener('click', () => this.connectWifi());
    document.getElementById('wifi-connect-back')?.addEventListener('click', () => this.showWifiList());
    document.getElementById('wifi-connect-pass')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') this.connectWifi();
    });
  }

  async checkRoot() {
    try {
      const res = await fetch('/api/check');
      const data = await res.json();
      this.isRoot = data.root;
      this.isLiveIso = !!data.liveIso;
      this.isOnline = data.online !== false;
      this.wifiConnected = !!data.wifi?.connected;
    } catch {
      this.isRoot = false;
    }
  }

  buildSummary() {
    const items = HATAN_INSTALLER.installPhases.map(p => p.label);
    document.getElementById('confirm-summary').innerHTML =
      items.map(t => `<li>${t}</li>`).join('');
  }

  shouldSkipWifi() {
    return !this.isLiveIso;
  }

  showStep(index) {
    let idx = index;
    if (this.steps[idx] === 'wifi' && this.shouldSkipWifi()) {
      idx = index > this.stepIndex ? idx + 1 : idx - 1;
    }

    this.stepIndex = idx;
    this.steps.forEach((name, i) => {
      document.getElementById(`screen-${name}`).classList.toggle('active', i === idx);
      const dot = document.querySelector(`.step-dot[data-i="${i}"]`);
      dot?.classList.toggle('active', i === idx);
      dot?.classList.toggle('done', i < idx);
    });

    const back = document.getElementById('btn-back');
    const next = document.getElementById('btn-next');
    const current = this.steps[idx];
    const isFirst = idx === 0;
    const isWifi = current === 'wifi';
    const isConfirm = current === 'confirm';
    const isProgress = current === 'progress';
    const isComplete = current === 'complete';

    back.disabled = isFirst || isProgress || isComplete;
    next.style.display = isProgress || isComplete ? 'none' : 'inline-block';

    if (isWifi) {
      next.textContent = 'التالي';
      next.disabled = !this.isOnline;
      this.onWifiScreen();
    } else if (isConfirm) {
      next.textContent = 'ابدأ التثبيت';
      next.disabled = this.isLiveIso && !this.isOnline;
    } else if (isComplete) {
      back.style.display = 'none';
      next.disabled = false;
    } else {
      next.textContent = 'التالي';
      next.disabled = false;
    }

    if (isProgress) {
      this.setActivePhase('system');
      document.getElementById('step-indicator').style.visibility = 'hidden';
    } else {
      document.getElementById('step-indicator').style.visibility = 'visible';
    }

    if (isComplete) {
      next.style.display = 'none';
      back.style.display = 'none';
      this.showRebootHint();
    }
  }

  async onWifiScreen() {
    await this.refreshWifiStatus();
    if (!this.wifiConnected) {
      await this.scanNetworks();
    }
  }

  setWifiStatus(text, type = '') {
    const el = document.getElementById('wifi-status');
    if (!el) return;
    el.textContent = text;
    el.className = `wifi-status${type ? ` is-${type}` : ''}`;
  }

  async refreshWifiStatus() {
    try {
      const res = await fetch('/api/wifi/status', { cache: 'no-store' });
      const data = await res.json();
      this.wifiConnected = !!data.wifi?.connected;
      this.isOnline = !!data.online;
      if (this.isOnline) {
        const ssid = data.wifi?.ssid || '';
        this.setWifiStatus(ssid ? `✅ متصل: ${ssid}` : '✅ متصل بالإنترنت', 'ok');
        document.getElementById('btn-next').disabled = false;
      } else if (this.wifiConnected) {
        this.setWifiStatus('متصل بالشبكة — جاري التحقق من الإنترنت...', '');
      } else {
        this.setWifiStatus('اختر شبكة واي فاي للمتابعة', '');
        document.getElementById('btn-next').disabled = true;
      }
    } catch {
      this.setWifiStatus('تعذّر فحص الاتصال', 'error');
    }
  }

  showWifiList() {
    document.getElementById('wifi-connect-form')?.classList.remove('show');
    document.getElementById('wifi-network-list')?.classList.remove('hidden');
    this.selectedSsid = '';
  }

  showWifiForm(ssid, secured) {
    this.selectedSsid = ssid;
    document.getElementById('wifi-connect-ssid').textContent = ssid;
    document.getElementById('wifi-connect-pass').value = '';
    document.getElementById('wifi-network-list')?.classList.add('hidden');
    const form = document.getElementById('wifi-connect-form');
    form?.classList.add('show');
    if (!secured) {
      this.connectWifi();
      return;
    }
    document.getElementById('wifi-connect-pass')?.focus();
  }

  strengthTier(signal) {
    if (signal >= 70) return '3';
    if (signal >= 40) return '2';
    return '1';
  }

  escapeHtml(text) {
    const d = document.createElement('div');
    d.textContent = text;
    return d.innerHTML;
  }

  async scanNetworks() {
    const list = document.getElementById('wifi-network-list');
    if (!list) return;

    this.setWifiStatus('جاري البحث عن شبكات...', '');
    list.innerHTML = '<p class="wifi-empty">جاري البحث...</p>';
    this.showWifiList();

    try {
      const res = await fetch('/api/wifi/scan', { cache: 'no-store' });
      const data = await res.json();
      const networks = data.networks || [];

      if (!networks.length) {
        list.innerHTML = '<p class="wifi-empty">لم تُعثر على شبكات — جرّب مرة أخرى</p>';
        this.setWifiStatus('لا توجد شبكات', 'error');
        return;
      }

      list.innerHTML = '';
      networks.forEach(net => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'wifi-network-item';
        btn.innerHTML = `
          <span class="wifi-network-signal" data-strength="${this.strengthTier(net.signal)}"></span>
          <span class="wifi-network-name">${this.escapeHtml(net.ssid)}</span>
          ${net.secured ? '<span class="wifi-network-lock">🔒</span>' : ''}
          ${net.active ? '<span class="wifi-network-badge">متصل</span>' : ''}
        `;
        btn.addEventListener('click', () => this.showWifiForm(net.ssid, net.secured));
        list.appendChild(btn);
      });

      this.setWifiStatus('اختر شبكة للاتصال', '');
      await this.refreshWifiStatus();
    } catch {
      list.innerHTML = '<p class="wifi-empty">فشل البحث</p>';
      this.setWifiStatus('فشل البحث عن الشبكات', 'error');
    }
  }

  async connectWifi() {
    const ssid = this.selectedSsid;
    if (!ssid) return;

    const pass = document.getElementById('wifi-connect-pass')?.value || '';
    this.setWifiStatus(`جاري الاتصال بـ ${ssid}...`, '');

    try {
      const res = await fetch('/api/wifi/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ssid, password: pass }),
      });
      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        this.setWifiStatus(data.error || 'فشل الاتصال', 'error');
        return;
      }

      this.wifiConnected = true;
      this.isOnline = !!data.online;
      this.showWifiList();
      await this.scanNetworks();
      await this.refreshWifiStatus();

      if (this.isOnline) {
        const params = new URLSearchParams(location.search);
        if (params.get('autoinstall') === '1') {
          setTimeout(() => {
            this.showStep(this.steps.indexOf('confirm'));
            setTimeout(() => this.startInstall(), 1500);
          }, 800);
        }
      }
    } catch {
      this.setWifiStatus('فشل الاتصال', 'error');
    }
  }

  showRebootHint() {
    const footer = document.querySelector('.installer-footer');
    if (document.getElementById('btn-reboot')) return;

    const btn = document.createElement('button');
    btn.className = 'btn btn-primary';
    btn.id = 'btn-reboot';
    btn.textContent = 'إعادة التشغيل';
    btn.addEventListener('click', async () => {
      try {
        await fetch('/api/reboot', { method: 'POST' });
      } catch {
        alert('أعد تشغيل الجهاز يدوياً');
      }
    });
    footer.appendChild(btn);
  }

  async next() {
    const current = this.steps[this.stepIndex];

    if (current === 'welcome' && !this.isRoot) {
      const demo = confirm('هذه معاينة فقط.\nهل تريد المتابعة؟');
      if (!demo) return;
    }

    if (current === 'welcome' && this.isLiveIso && this.isOnline) {
      this.showStep(this.steps.indexOf('confirm'));
      return;
    }

    if (current === 'wifi' && this.isLiveIso && !this.isOnline) {
      this.setWifiStatus('يجب الاتصال بالإنترنت أولاً', 'error');
      return;
    }

    if (current === 'confirm') {
      await this.startInstall();
      return;
    }

    if (this.stepIndex < this.steps.length - 1) {
      this.showStep(this.stepIndex + 1);
    }
  }

  back() {
    if (this.stepIndex > 0 && !this.installing) {
      this.showStep(this.stepIndex - 1);
    }
  }

  async startInstall() {
    if (this.isLiveIso && !this.isOnline) {
      this.setWifiStatus('يتطلب إنترنت — ارجع لخطوة الواي فاي', 'error');
      this.showStep(this.steps.indexOf('wifi'));
      return;
    }

    this.installing = true;
    this.showStep(this.steps.indexOf('progress'));

    try {
      const res = await fetch('/api/install', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ recommended: true, username: 'deck' })
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        if (err.error?.includes('إنترنت')) {
          this.installing = false;
          this.showStep(this.steps.indexOf('wifi'));
          this.setWifiStatus(err.error, 'error');
          return;
        }
        throw new Error(err.error || 'تعذّر بدء التثبيت');
      }
    } catch {
      this.installing = false;
      return;
    }

    this.pollTimer = setInterval(() => this.pollStatus(), 800);
  }

  async pollStatus() {
    try {
      const res = await fetch('/api/status');
      const data = await res.json();
      const pct = data.percent || 0;

      document.getElementById('progress-fill').style.width = `${pct}%`;
      document.getElementById('progress-pct').textContent = `${pct}%`;

      this.setActivePhase(HATAN_INSTALLER.phaseByPercent(pct));

      if (data.done) {
        clearInterval(this.pollTimer);
        this.installing = false;
        if (data.status !== 'error') {
          this.setActivePhase('apps');
          document.querySelectorAll('#install-phases-progress .phase-box')
            .forEach(b => b.classList.add('done'));
          setTimeout(() => this.showStep(this.steps.indexOf('complete')), 1200);
        }
      }
    } catch { /* retry */ }
  }
}

document.addEventListener('DOMContentLoaded', () => new HATANInstaller());
