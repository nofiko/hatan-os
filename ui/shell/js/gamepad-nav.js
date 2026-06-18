// HATAN OS — تنقل D-Pad باليد

class HATANGamepadNav {
  constructor(shell) {
    this.shell = shell;
    this.focused = null;
    this.zone = 'apps';
    this.zones = ['games', 'apps'];
  }

  isActive() {
    const home = document.getElementById('home-screen');
    const settings = document.getElementById('settings-screen');
    if (settings?.classList.contains('show')) return 'settings';
    if (home?.classList.contains('show')) return 'home';
    return null;
  }

  handleDpad(btnId) {
    const ctx = this.isActive();
    if (!ctx) return false;

    const dir = {
      DPAD_UP: 'up',
      DPAD_DOWN: 'down',
      DPAD_LEFT: 'left',
      DPAD_RIGHT: 'right',
    }[btnId];
    if (!dir) return false;

    if (ctx === 'home') this.moveHome(dir);
    else if (ctx === 'settings') this.moveSettings(dir);
    return true;
  }

  homeItems() {
    const games = [...document.querySelectorAll('.home-game-card')];
    const apps = [...document.querySelectorAll('.home-app-3d')];
    return { games, apps };
  }

  moveHome(dir) {
    const { games, apps } = this.homeItems();
    const inGames = this.focused?.classList?.contains('home-game-card');

    if (!this.focused) {
      this.focus(games[0] || apps[0]);
      return;
    }

    if (dir === 'up') {
      if (inGames) this.focus(apps[Math.min(3, apps.length - 1)] || apps[0]);
      return;
    }
    if (dir === 'down') {
      if (!inGames && games.length) this.focus(games[0]);
      return;
    }

    const list = inGames ? games : apps;
    const idx = list.indexOf(this.focused);
    if (idx < 0) {
      this.focus(list[0]);
      return;
    }
    if (dir === 'left') this.focus(list[Math.min(list.length - 1, idx + 1)]);
    if (dir === 'right') this.focus(list[Math.max(0, idx - 1)]);
  }

  settingsItems() {
    return {
      nav: [...document.querySelectorAll('.settings-nav-item')],
      content: [...document.querySelectorAll(
        '#settings-content button, #settings-content .set-dev-item:not(.set-dev-static), ' +
        '#settings-content .set-theme-card, #settings-content .set-wall-card, ' +
        '#settings-content .set-toggle, #settings-content input, #settings-content select'
      )],
    };
  }

  moveSettings(dir) {
    const { nav, content } = this.settingsItems();
    const inNav = this.focused?.classList?.contains('settings-nav-item');

    if (!this.focused) {
      this.focus(nav.find(n => n.classList.contains('active')) || nav[0]);
      return;
    }

    if (dir === 'left' && inNav && content.length) {
      this.focus(content[0]);
      return;
    }
    if (dir === 'right' && !inNav && nav.length) {
      this.focus(nav.find(n => n.classList.contains('active')) || nav[0]);
      return;
    }

    const list = inNav ? nav : content;
    const idx = list.indexOf(this.focused);
    if (idx < 0) {
      this.focus(list[0]);
      return;
    }
    if (dir === 'up') this.focus(list[Math.max(0, idx - 1)]);
    if (dir === 'down') this.focus(list[Math.min(list.length - 1, idx + 1)]);
  }

  focus(el) {
    if (!el) return;
    this.focused?.classList.remove('hat-focused');
    this.focused = el;
    el.classList.add('hat-focused');
    el.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
  }

  clear() {
    this.focused?.classList.remove('hat-focused');
    this.focused = null;
  }

  confirm() {
    if (this.focused) {
      this.focused.click?.();
      return true;
    }
    return false;
  }

  resetHome() {
    this.clear();
    const { games } = this.homeItems();
    if (games.length) this.focus(games[0]);
    else {
      const apps = document.querySelectorAll('.home-app-3d');
      if (apps[0]) this.focus(apps[0]);
    }
  }
}
