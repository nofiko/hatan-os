// HATAN OS — تسلسل التشغيل

class HATANShell {
  constructor() {
    this.started = false;
    this.settings = null;
    this.shortcuts = null;
    this.statusBar = null;
    this.gamepadNav = null;
    this.init();
  }

  init() {
    document.title = HATAN_CONFIG.name;

    const logoVersion = Date.now();
    const bootImg = document.querySelector('.boot-splash-img');
    if (bootImg) bootImg.src = `assets/boot.png?v=${logoVersion}`;
    const favicon = document.querySelector('link[rel="icon"]');
    if (favicon) favicon.href = `assets/boot.png?v=${logoVersion}`;

    const bootVer = document.getElementById('boot-version');
    if (bootVer) bootVer.textContent = HATAN_CONFIG.name;

    const welcomeText = document.getElementById('welcome-text');
    if (welcomeText) welcomeText.textContent = HATAN_CONFIG.welcome.text;

    const openPrompt = document.getElementById('open-prompt');
    if (openPrompt) openPrompt.textContent = HATAN_CONFIG.welcome.openText;

    this.setupUnlock();
  }

  setupUnlock() {
    const unlock = document.getElementById('tap-unlock');

    // محاولة البدء تلقائياً (Steam Deck)
    this.runSequence().catch(() => {
      if (!unlock) return;
      unlock.classList.add('show');
      unlock.addEventListener('click', () => {
        unlock.classList.remove('show');
        this.runSequence();
      }, { once: true });
    });
  }

  async runSequence() {
    if (this.started) return;
    this.started = true;

    const splash = document.getElementById('boot-splash');
    const shell = document.getElementById('shell');
    const startupSound = document.getElementById('startup-sound');
    const welcomeSound = document.getElementById('welcome-sound');
    const welcomeText = document.getElementById('welcome-text');
    const openWrap = document.getElementById('open-prompt-wrap');
    const openPrompt = document.getElementById('open-prompt');

    // ── 1. شعار النظام + startup-sound ──
    await this.playAudio(startupSound);

    // ── 2. إخفاء شاشة التشغيل ──
    splash?.classList.add('fade-out');
    if (shell) shell.style.visibility = 'visible';
    await this.wait(800);
    splash?.remove();

    // ── 3. مرحبا + welcom.mp3 ──
    welcomeText?.classList.add('show');
    await this.playAudio(welcomeSound);

    // ── 4. إخفاء مرحبا ──
    welcomeText?.classList.remove('show');
    welcomeText?.classList.add('hide');
    await this.wait(600);

    // ── 5. اضغط هنا لفتح النظام ──
    openWrap?.classList.add('show');
    const canvas = document.getElementById('network-canvas');
    if (canvas) {
      canvas.classList.add('active');
      this.network = new NetworkMesh(canvas);
      this.network.start();
    }
    this.playLoopAudio(document.getElementById('press-music'));
    openPrompt?.addEventListener('click', () => this.openSystem(), { once: true });
  }

  async openSystem() {
    const openWrap = document.getElementById('open-prompt-wrap');
    const openPrompt = document.getElementById('open-prompt');
    const canvas = document.getElementById('network-canvas');
    const selectSound = document.getElementById('select-sound');
    const disSound = document.getElementById('dis-sound');
    const pressMusic = document.getElementById('press-music');

    this.stopAudio(pressMusic);

    openWrap?.classList.add('exiting-ui');
    openPrompt?.classList.add('exiting');

    this.playAudio(selectSound).catch(() => {});
    setTimeout(() => this.playAudio(disSound).catch(() => {}), 500);

    await new Promise(resolve => {
      if (this.network) {
        this.network.exit(resolve);
      } else {
        resolve();
      }
    });

    canvas?.classList.remove('active');
    openWrap?.remove();
    canvas?.remove();

    document.querySelector('.welcome-screen')?.classList.add('hidden');
    await this.wait(400);
    this.showHome();
  }

  async showHome() {
    const home = document.getElementById('home-screen');
    const appsEl = document.getElementById('home-apps');
    const brand = document.getElementById('home-brand');
    const bg = document.getElementById('home-bg-image');
    const logoImg = document.getElementById('home-logo-img');
    const scene = document.getElementById('home-scene');
    const gridCanvas = document.getElementById('home-grid-canvas');
    const logoVersion = Date.now();
    const total = HATAN_CONFIG.apps.length;

    await HATANSettings.applySavedTheme();

    if (brand && !brand.textContent.trim()) brand.textContent = HATAN_CONFIG.name;
    const logoUrl = `assets/boot.png?v=${logoVersion}`;
    if (logoImg) logoImg.src = logoUrl;

    if (appsEl) {
      appsEl.innerHTML = HATAN_CONFIG.apps.map((app, i) => {
        const angle = ((i - (total - 1) / 2) / (total - 1 || 1)) * 42;
        const lift = 30 + Math.abs(angle) * 0.8;
        return `
          <button class="home-app-3d" data-app="${app.id}"
            style="--i:${i}; --ry:${angle}deg; --tz:${lift}px">
            <div class="home-app-face">
              <div class="home-app-face-top"></div>
              <span class="home-app-icon">${app.icon}</span>
              <span class="home-app-name">${app.name}</span>
            </div>
            <div class="home-app-shadow"></div>
          </button>
        `;
      }).join('');

      appsEl.querySelectorAll('.home-app-3d').forEach(btn => {
        btn.addEventListener('click', () => this.launchApp(btn.dataset.app));
      });
    }

    if (gridCanvas) {
      this.homeGrid = new HomeGrid3D(gridCanvas);
      this.homeGrid.start();
    }

    this.loadRecentGames();

    document.getElementById('home-games-store')?.addEventListener('click', () => {
      this.launchApp('steam');
    });

    this.setupHomeParallax(scene);

    if (!this.shortcuts) {
      this.gamepadNav = new HATANGamepadNav(this);
      this.shortcuts = new HATANButtonShortcuts(this);
      this.shortcuts.load().then(() => this.shortcuts.start());
    }

    if (!this.statusBar) {
      this.statusBar = new HATANStatusBar();
      this.statusBar.mount();
    } else {
      this.statusBar.tick();
    }

    requestAnimationFrame(() => {
      home?.classList.add('show');
      this.gamepadNav?.resetHome();
    });
  }

  setupHomeParallax(scene) {
    if (!scene) return;

    const onMove = (x, y) => {
      const rx = ((y / window.innerHeight) - 0.5) * -10;
      const ry = ((x / window.innerWidth) - 0.5) * 14;
      scene.style.setProperty('--rx', `${rx}deg`);
      scene.style.setProperty('--ry', `${ry}deg`);
    };

    window.addEventListener('mousemove', e => onMove(e.clientX, e.clientY));
    window.addEventListener('touchmove', e => {
      if (e.touches[0]) onMove(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: true });
  }

  launchApp(id) {
    if (id === 'settings') {
      if (!this.settings) this.settings = new HATANSettings(this);
      this.settings.open();
      return;
    }
    if (id === 'capture') {
      if (!this.capture) this.capture = new HATANCapture(this);
      this.capture.open();
      return;
    }
    fetch(`/api/launch?app=${encodeURIComponent(id)}`).catch(() => {});
  }

  launchSteamGame(appid, slug = '') {
    const q = slug
      ? `game=${encodeURIComponent(appid)}&slug=${encodeURIComponent(slug)}`
      : `game=${encodeURIComponent(appid)}`;
    fetch(`/api/launch?${q}`).catch(() => {});
  }

  async loadRecentGames() {
    const row = document.getElementById('home-games-row');
    if (!row) return;

    row.innerHTML = '<p class="home-games-empty home-games-loading">⏳ جاري تحميل الألعاب...</p>';

    let data = { games: [] };
    try {
      const res = await fetch('/api/games');
      data = await res.json();
    } catch { /* preview offline */ }

    const games = data.games || [];
    if (!games.length) {
      row.innerHTML = '<p class="home-games-empty">لا توجد ألعاب حديثة — افتح Steam لتحميل ألعابك</p>';
      return;
    }

    row.innerHTML = games.map((g, i) => {
      const featured = i === 0 ? ' featured' : '';
      const hours = g.playtimeLabel
        ? `<span class="home-game-hours">${this.escHtml(g.playtimeLabel)}</span>`
        : '';
      const img = g.image
        ? `<img src="${this.escHtml(g.image)}" alt="" loading="lazy" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">`
        : '';
      const slugAttr = g.slug ? ` data-slug="${this.escHtml(g.slug)}"` : '';
      const srcBadge = g.source === 'lutris' ? '<span class="home-game-src">L</span>' : '';
      return `
        <button type="button" class="home-game-card${featured}" data-appid="${this.escHtml(g.appid)}"${slugAttr} title="${this.escHtml(g.name)}">
          <div class="home-game-cover">
            ${img}
            <div class="home-game-cover-fallback" style="${g.image ? 'display:none' : ''}">🎮</div>
            ${srcBadge}
            <span class="home-game-play">▶</span>
          </div>
          <div class="home-game-meta">
            <span class="home-game-name">${this.escHtml(g.name)}</span>
            ${hours}
          </div>
        </button>
      `;
    }).join('');

    row.querySelectorAll('.home-game-card').forEach(btn => {
      btn.addEventListener('click', () => this.launchSteamGame(btn.dataset.appid, btn.dataset.slug || ''));
    });

    this.gamepadNav?.resetHome();
  }

  escHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/"/g, '&quot;');
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
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

document.addEventListener('DOMContentLoaded', () => new HATANShell());
