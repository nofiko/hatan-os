// HATAN OS — تسلسل الإقلاع

(function () {
  class HATANBoot {
    constructor() {
      this.started = false;
      this.opening = false;
      this.network = null;
      this.ambient = null;
      this.init();
    }

    init() {
      document.title = HATAN_CONFIG.name;

      const v = Date.now();
      const bootImg = document.querySelector('.boot-splash-img');
      if (bootImg) bootImg.src = `assets/logo.png?v=${v}`;

      const bootVer = document.getElementById('boot-version');
      if (bootVer) bootVer.textContent = HATAN_CONFIG.name;

      const welcomeText = document.getElementById('welcome-text');
      if (welcomeText) welcomeText.textContent = HATAN_CONFIG.welcome.text;

      const openPrompt = document.getElementById('open-prompt');
      if (openPrompt) openPrompt.textContent = HATAN_CONFIG.welcome.openText;

      const pickerTitle = HATAN_CONFIG.picker?.title;
      if (pickerTitle) {
        document.querySelectorAll('.picker-title-layer').forEach((el) => {
          el.textContent = pickerTitle;
        });
        const sr = document.querySelector('.picker-title-sr');
        if (sr) sr.textContent = pickerTitle;
      }

      this.spawnBootParticles();
      this.enterFullscreen();
      this.runSequence();
    }

    enterFullscreen() {
      const el = document.documentElement;
      const req = el.requestFullscreen
        || el.webkitRequestFullscreen
        || el.msRequestFullscreen;
      if (req) {
        try { req.call(el); } catch { /* */ }
      }
    }

    spawnBootParticles() {
      const container = document.getElementById('boot-particles');
      if (!container) return;
      for (let i = 0; i < 36; i++) {
        const p = document.createElement('span');
        p.className = 'boot-particle';
        p.style.left = `${Math.random() * 100}%`;
        p.style.top = `${55 + Math.random() * 40}%`;
        p.style.setProperty('--dur', `${4 + Math.random() * 5}s`);
        p.style.setProperty('--delay', `${Math.random() * 4}s`);
        container.appendChild(p);
      }
    }

    async ensureAudio(audio) {
      if (!audio) return;
      try {
        await this.playAudio(audio);
        return;
      } catch { /* autoplay blocked */ }

      await new Promise((resolve) => {
        const unlock = () => {
          document.removeEventListener('pointerdown', unlock);
          document.removeEventListener('keydown', unlock);
          resolve();
        };
        document.addEventListener('pointerdown', unlock, { once: true });
        document.addEventListener('keydown', unlock, { once: true });
      });

      try { await this.playAudio(audio); } catch { /* continue silently */ }
    }

    async runSequence() {
      if (this.started) return;
      this.started = true;

      const splash = document.getElementById('boot-splash');
      const shell = document.getElementById('shell');
      const flash = document.getElementById('transition-flash');
      const startupSound = document.getElementById('startup-sound');
      const welcomeSound = document.getElementById('welcome-sound');
      const welcomeText = document.getElementById('welcome-text');
      const openWrap = document.getElementById('open-prompt-wrap');
      const openPrompt = document.getElementById('open-prompt');

      // 1 — شعار + startup-sound.mp3 (تلقائي بدون ضغط)
      await this.ensureAudio(startupSound);

      flash?.classList.add('play');
      splash?.classList.add('fade-out');
      shell?.classList.add('reveal');
      if (shell) shell.style.visibility = 'visible';
      await this.wait(1100);
      flash?.classList.remove('play');
      splash?.remove();

      // 2 — مرحباً + welcom.mp3
      welcomeText?.classList.add('show');
      await this.ensureAudio(welcomeSound);

      flash?.classList.add('play');
      welcomeText?.classList.remove('show');
      welcomeText?.classList.add('hide');
      await this.wait(900);
      flash?.classList.remove('play');
      await this.wait(200);

      // 3 — شبكة 3D دوّارة + اضغط هنا
      openWrap?.classList.add('show');
      const canvas = document.getElementById('network-canvas');
      if (canvas) {
        canvas.classList.add('active');
        this.network = new NetworkMesh(canvas);
        this.network.start();
      }

      this.playLoopAudio(document.getElementById('press-music'));

      const onOpenOnce = () => {
        if (this.opening) return;
        document.removeEventListener('keydown', onKey);
        openPrompt?.removeEventListener('click', onOpenOnce);
        this.onOpen();
      };
      const onKey = (e) => {
        if (['Enter', ' ', 'a', 'A'].includes(e.key)) onOpenOnce();
      };

      openPrompt?.addEventListener('click', onOpenOnce);
      document.addEventListener('keydown', onKey);
    }

    async onOpen() {
      if (this.opening) return;
      this.opening = true;

      const openWrap = document.getElementById('open-prompt-wrap');
      const openPrompt = document.getElementById('open-prompt');
      const canvas = document.getElementById('network-canvas');
      const pressMusic = document.getElementById('press-music');
      const selectSound = document.getElementById('select-sound');
      const disSound = document.getElementById('dis-sound');

      this.stopAudio(pressMusic);
      openWrap?.classList.add('exiting-ui');
      openPrompt?.classList.add('exiting');
      canvas?.classList.add('zoom-out');

      this.playAudio(selectSound).catch(() => {});
      setTimeout(() => this.playAudio(disSound).catch(() => {}), 500);

      await new Promise((resolve) => {
        if (this.network) this.network.exit(resolve);
        else resolve();
      });

      canvas?.classList.remove('active');
      document.querySelector('.welcome-screen')?.classList.add('hidden');
      await this.wait(500);

      await this.showAmbient();
      const os = await this.waitForOsChoice();
      await this.hideOsPicker();
      if (os === 'hatan') {
        this.bootDone(os);
        const shellPort = window.HATAN_SHELL_PORT || 8765;
        window.location.replace(`http://127.0.0.1:${shellPort}/`);
        return;
      }
      await window.HatanOsLauncher?.launch(os);
      this.bootDone(os);
    }

    async showAmbient() {
      const flash = document.getElementById('transition-flash');
      const phase = document.getElementById('phase-ambient');
      const canvas = document.getElementById('ambient-canvas');
      const shell = document.getElementById('shell');

      shell?.classList.add('hidden');
      flash?.classList.add('play');
      await this.wait(400);
      flash?.classList.remove('play');

      phase?.classList.add('active');
      if (canvas) {
        this.ambient = new AmbientScene(canvas);
        this.ambient.start();
      }
      await this.wait(1400);

      const picker = document.getElementById('os-picker');
      phase?.classList.add('picker-ready');
      picker?.classList.add('show');

      const status = await window.HatanOsLauncher?.fetchStatus();
      window.HatanOsLauncher?.applyPickerBadges(status);
    }

    waitForOsChoice() {
      return new Promise((resolve) => {
        const osChoices = document.querySelectorAll('.os-choice');
        const selectSound = document.getElementById('select-sound');

        const pick = (btn) => {
          if (!btn) return;
          const os = btn.dataset.os;
          btn.classList.add('selected');
          this.playAudio(selectSound).catch(() => {});
          osChoices.forEach((c) => {
            c.removeEventListener('click', onClick);
            c.disabled = true;
          });
          document.removeEventListener('keydown', onKey);
          this.wait(700).then(() => resolve(os));
        };

        const onClick = (e) => pick(e.currentTarget);
        const onKey = (e) => {
          if (e.key === 'h' || e.key === 'H') {
            document.removeEventListener('keydown', onKey);
            osChoices.forEach((c) => c.removeEventListener('click', onClick));
            resolve('hatan');
            return;
          }
          if (e.key === '1') pick(document.getElementById('choice-windows'));
          if (e.key === '2') pick(document.getElementById('choice-steam'));
          if (e.key === 'ArrowRight') pick(document.getElementById('choice-windows'));
          if (e.key === 'ArrowLeft') pick(document.getElementById('choice-steam'));
        };

        osChoices.forEach((c) => c.addEventListener('click', onClick));
        document.addEventListener('keydown', onKey);
      });
    }

    async hideOsPicker() {
      document.getElementById('os-picker')?.classList.add('hide');
      await this.wait(900);
    }

    bootDone(os) {
      const detail = { os };
      document.dispatchEvent(new CustomEvent('hatan-boot-done', { detail }));
      if (window.parent !== window) {
        window.parent.postMessage({ type: 'hatan-boot-done', os }, '*');
      }
    }

    playLoopAudio(audio) {
      if (!audio) return;
      audio.loop = true;
      audio.currentTime = 0;
      audio.play().catch(() => {});
    }

    stopAudio(audio) {
      if (!audio) return;
      audio.pause();
      audio.currentTime = 0;
    }

    playAudio(audio) {
      return new Promise((resolve, reject) => {
        if (!audio) { resolve(); return; }
        audio.currentTime = 0;
        const cleanup = () => {
          audio.removeEventListener('ended', onEnd);
          audio.removeEventListener('error', onError);
        };
        const onEnd = () => { cleanup(); resolve(); };
        const onError = () => { cleanup(); reject(); };
        audio.addEventListener('ended', onEnd);
        audio.addEventListener('error', onError);
        audio.play().catch(reject);
      });
    }

    wait(ms) {
      return new Promise((r) => setTimeout(r, ms));
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => new HATANBoot());
  } else {
    new HATANBoot();
  }
})();
