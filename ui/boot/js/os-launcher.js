// HATAN OS — تثبيت / إقلاع النظام المختار

(function () {
  const cfg = () => HATAN_CONFIG.os || {};

  class OsLauncher {
    constructor() {
      this.overlay = document.getElementById('os-action-overlay');
      this.title = document.getElementById('os-action-title');
      this.message = document.getElementById('os-action-message');
      this.bar = document.getElementById('os-action-bar');
      this.pollTimer = null;
    }

    async fetchStatus() {
      try {
        const res = await fetch('/api/os/status', { cache: 'no-store' });
        if (!res.ok) return null;
        return await res.json();
      } catch {
        return null;
      }
    }

    applyPickerBadges(status) {
      if (!status) return;
      this.setBadge('windows', status.windows?.installed);
      this.setBadge('steam', status.steam?.installed);
    }

    setBadge(os, installed) {
      const el = document.getElementById(`badge-${os}`);
      if (!el) return;
      el.textContent = installed
        ? (cfg().installed || 'مثبت')
        : (cfg().notInstalled || 'غير مثبت');
      el.classList.toggle('is-installed', !!installed);
      el.classList.toggle('is-missing', !installed);
    }

    async launch(os) {
      this.showOverlay(os, cfg().checking || 'جاري التحقق...');
      try {
        const res = await fetch('/api/os/launch', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ os }),
        });
        const data = await res.json();
        if (!res.ok || !data.ok) {
          this.showError(data.error || cfg().launchError || 'تعذّر تنفيذ العملية');
          return data;
        }

        const label = os === 'windows' ? 'Windows' : 'Steam';
        if (data.action === 'boot') {
          this.showOverlay(label, data.message || cfg().booting || 'جاري الدخول...', 72);
          await this.wait(1600);
          this.showOverlay(label, cfg().bootDone || 'تم الدخول إلى النظام', 100);
          await this.wait(1200);
          this.hideOverlay();
          return data;
        }

        this.showOverlay(label, data.message || cfg().installing || 'جاري التثبيت...', 8);
        this.startPoll();
        return data;
      } catch {
        this.showError(cfg().networkError || 'تعذّر الاتصال بالخادم');
        return { ok: false };
      }
    }

    startPoll() {
      this.stopPoll();
      this.pollTimer = setInterval(() => this.pollProgress(), 900);
      this.pollProgress();
    }

    stopPoll() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    }

    async pollProgress() {
      try {
        const res = await fetch('/api/os/progress', { cache: 'no-store' });
        if (!res.ok) return;
        const p = await res.json();
        const label = p.os === 'windows' ? 'Windows' : 'Steam';

        if (p.error) {
          this.stopPoll();
          this.showError(p.error);
          return;
        }

        if (p.message) {
          this.showOverlay(label, p.message, p.percent || 0);
        }

        if (p.done || (!p.active && (p.percent >= 100 || p.installed))) {
          this.stopPoll();
          this.showOverlay(label, p.message || cfg().installDone || 'اكتمل التثبيت', 100);
          await this.wait(1400);
          this.hideOverlay();
          if (p.installed) {
            this.setBadge(p.os, true);
          }
        }
      } catch { /* */ }
    }

    showOverlay(title, message, percent = 0) {
      this.overlay?.classList.add('show');
      if (this.title) this.title.textContent = title;
      if (this.message) {
        this.message.textContent = message;
        this.message.classList.remove('is-error');
      }
      if (this.bar) this.bar.style.width = `${Math.max(0, Math.min(100, percent))}%`;
    }

    showError(msg) {
      this.stopPoll();
      this.overlay?.classList.add('show');
      if (this.title) this.title.textContent = cfg().errorTitle || 'خطأ';
      if (this.message) {
        this.message.textContent = msg;
        this.message.classList.add('is-error');
      }
      if (this.bar) this.bar.style.width = '0%';
    }

    hideOverlay() {
      this.stopPoll();
      this.overlay?.classList.remove('show');
    }

    wait(ms) {
      return new Promise((r) => setTimeout(r, ms));
    }
  }

  window.HatanOsLauncher = new OsLauncher();
})();
