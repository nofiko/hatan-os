// HATAN OS — المثبّت الرسومي

class HATANInstaller {
  constructor() {
    this.stepIndex = 0;
    this.steps = HATAN_INSTALLER.steps;
    this.isRoot = false;
    this.installing = false;
    this.pollTimer = null;

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
    this.checkRoot();
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
  }

  async checkRoot() {
    try {
      const res = await fetch('/api/check');
      const data = await res.json();
      this.isRoot = data.root;
    } catch {
      this.isRoot = false;
    }
  }

  buildSummary() {
    const items = HATAN_INSTALLER.installPhases.map(p => p.label);
    document.getElementById('confirm-summary').innerHTML =
      items.map(t => `<li>${t}</li>`).join('');
  }

  showStep(index) {
    this.stepIndex = index;
    this.steps.forEach((name, i) => {
      document.getElementById(`screen-${name}`).classList.toggle('active', i === index);
      const dot = document.querySelector(`.step-dot[data-i="${i}"]`);
      dot?.classList.toggle('active', i === index);
      dot?.classList.toggle('done', i < index);
    });

    const back = document.getElementById('btn-back');
    const next = document.getElementById('btn-next');
    const isFirst = index === 0;
    const isConfirm = this.steps[index] === 'confirm';
    const isProgress = this.steps[index] === 'progress';
    const isComplete = this.steps[index] === 'complete';

    back.disabled = isFirst || isProgress || isComplete;
    next.style.display = isProgress || isComplete ? 'none' : 'inline-block';

    if (isConfirm) {
      next.textContent = 'ابدأ التثبيت';
      this.buildSummary();
    } else if (isComplete) {
      back.style.display = 'none';
    } else {
      next.textContent = 'التالي';
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
