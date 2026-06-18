// HATAN OS — شريط البطارية والواي فاي

(function () {
  const cfg = () => HATAN_CONFIG.status || {};

  class SystemStatus {
    constructor() {
      this.battery = { level: null, charging: false, low: false };
      this.wifi = { connected: false, ssid: '', strength: 0 };
      this.panelOpen = false;
      this.scanning = false;
      this.connecting = false;
      this.selectedNetwork = null;
      this.pollTimer = null;
      this.browserBatteryBound = false;
      this.bind();
      this.refresh();
      this.pollTimer = setInterval(() => this.refresh(), cfg().pollMs || 8000);
    }

    bind() {
      this.tray = document.getElementById('status-tray');
      this.alert = document.getElementById('status-alert');
      this.alertText = document.getElementById('status-alert-text');
      this.wifiBtn = document.getElementById('status-wifi');
      this.batteryBtn = document.getElementById('status-battery');
      this.wifiLabel = document.getElementById('wifi-label');
      this.batteryLabel = document.getElementById('battery-label');
      this.wifiIcon = document.getElementById('wifi-icon');
      this.batteryIcon = document.getElementById('battery-icon');
      this.batteryFill = document.getElementById('battery-fill');
      this.panel = document.getElementById('wifi-panel');
      this.panelBackdrop = document.getElementById('wifi-panel-backdrop');
      this.networkList = document.getElementById('wifi-network-list');
      this.connectForm = document.getElementById('wifi-connect-form');
      this.connectSsid = document.getElementById('wifi-connect-ssid');
      this.connectPass = document.getElementById('wifi-connect-pass');
      this.panelStatus = document.getElementById('wifi-panel-status');

      this.wifiBtn?.addEventListener('click', () => this.togglePanel());
      this.panelBackdrop?.addEventListener('click', () => this.closePanel());
      document.getElementById('wifi-panel-close')?.addEventListener('click', () => this.closePanel());
      document.getElementById('wifi-scan-btn')?.addEventListener('click', () => this.scanNetworks());
      document.getElementById('wifi-connect-btn')?.addEventListener('click', () => this.connect());
      document.getElementById('wifi-connect-back')?.addEventListener('click', () => this.showList());

      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && this.panelOpen) this.closePanel();
      });
    }

    async refresh() {
      const api = await this.fetchApiStatus();
      if (api?.wifi) this.wifi = { ...this.wifi, ...api.wifi };
      if (api?.battery) {
        this.battery = { ...this.battery, ...api.battery };
      } else {
        await this.refreshBrowserBattery();
      }
      if (!api) {
        this.wifi.connected = navigator.onLine;
        if (!this.wifi.connected) this.wifi.ssid = '';
      }
      this.render();
    }

    async fetchApiStatus() {
      try {
        const res = await fetch('/api/status', { cache: 'no-store' });
        if (!res.ok) return null;
        return await res.json();
      } catch {
        return null;
      }
    }

    async refreshBrowserBattery() {
      if (!navigator.getBattery) return;
      try {
        const bat = await navigator.getBattery();
        const level = Math.round(bat.level * 100);
        this.battery = {
          level,
          charging: bat.charging,
          low: level <= (cfg().batteryLow || 20),
        };
        const update = () => {
          const lv = Math.round(bat.level * 100);
          this.battery = {
            level: lv,
            charging: bat.charging,
            low: lv <= (cfg().batteryLow || 20),
          };
          this.render();
        };
        bat.addEventListener('levelchange', update);
        bat.addEventListener('chargingchange', update);
        this.browserBatteryBound = true;
      } catch { /* */ }
    }

    render() {
      this.tray?.classList.add('visible');

      const wifiConnected = this.wifi.connected;
      const ssid = this.wifi.ssid || '';
      const strength = this.wifi.strength || 0;

      if (this.wifiLabel) {
        this.wifiLabel.textContent = wifiConnected
          ? (ssid || cfg().wifiConnected || 'متصل')
          : (cfg().wifiDisconnected || 'غير متصل');
      }

      this.wifiBtn?.classList.toggle('is-off', !wifiConnected);
      this.wifiBtn?.classList.toggle('is-on', wifiConnected);
      this.wifiIcon?.setAttribute('data-strength', wifiConnected ? this.strengthTier(strength) : '0');

      const level = this.battery.level;
      if (this.batteryLabel) {
        this.batteryLabel.textContent = level == null ? '—' : `${level}%`;
      }
      if (this.batteryFill) {
        const pct = level == null ? 0 : Math.max(0, Math.min(100, level));
        this.batteryFill.setAttribute('width', String((19 * pct) / 100));
      }
      this.batteryBtn?.classList.toggle('is-low', !!this.battery.low);
      this.batteryBtn?.classList.toggle('is-charging', !!this.battery.charging);

      const issues = [];
      if (!wifiConnected) issues.push(cfg().alertWifi || 'لا يوجد اتصال بالواي فاي');
      if (this.battery.level != null && this.battery.low) {
        issues.push(cfg().alertBattery || 'البطارية منخفضة');
      }

      if (issues.length) {
        this.alert?.classList.add('show');
        document.body.classList.add('alert-active');
        if (this.alertText) this.alertText.textContent = issues.join('  •  ');
      } else {
        this.alert?.classList.remove('show');
        document.body.classList.remove('alert-active');
      }
    }

    strengthTier(n) {
      if (n >= 70) return '3';
      if (n >= 40) return '2';
      if (n > 0) return '1';
      return '2';
    }

    togglePanel() {
      if (this.panelOpen) this.closePanel();
      else this.openPanel();
    }

    openPanel() {
      this.panelOpen = true;
      this.panel?.classList.add('open');
      this.panelBackdrop?.classList.add('open');
      this.showList();
      this.scanNetworks();
    }

    closePanel() {
      this.panelOpen = false;
      this.panel?.classList.remove('open');
      this.panelBackdrop?.classList.remove('open');
      this.selectedNetwork = null;
    }

    showList() {
      this.connectForm?.classList.remove('show');
      this.networkList?.classList.remove('hidden');
    }

    showConnectForm(network) {
      this.selectedNetwork = network;
      if (this.connectSsid) this.connectSsid.textContent = network.ssid;
      if (this.connectPass) this.connectPass.value = '';
      this.networkList?.classList.add('hidden');
      this.connectForm?.classList.add('show');
      if (network.secured) {
        setTimeout(() => this.connectPass?.focus(), 120);
      }
    }

    setPanelStatus(msg, type = '') {
      if (!this.panelStatus) return;
      this.panelStatus.textContent = msg;
      this.panelStatus.className = `wifi-panel-status${type ? ` is-${type}` : ''}`;
    }

    async scanNetworks() {
      if (this.scanning) return;
      this.scanning = true;
      this.setPanelStatus(cfg().scanning || 'جاري البحث عن الشبكات...');

      try {
        const res = await fetch('/api/wifi/scan', { cache: 'no-store' });
        if (!res.ok) throw new Error('scan failed');
        const data = await res.json();
        this.renderNetworkList(data.networks || []);
        this.setPanelStatus('');
      } catch {
        this.renderNetworkList([]);
        this.setPanelStatus(cfg().scanError || 'تعذّر البحث — تحقق من محول الواي فاي', 'error');
      } finally {
        this.scanning = false;
      }
    }

    renderNetworkList(networks) {
      if (!this.networkList) return;
      this.networkList.innerHTML = '';

      if (!networks.length) {
        const empty = document.createElement('p');
        empty.className = 'wifi-empty';
        empty.textContent = cfg().noNetworks || 'لم يُعثر على شبكات';
        this.networkList.appendChild(empty);
        return;
      }

      const seen = new Set();
      networks.forEach((net) => {
        if (!net.ssid || seen.has(net.ssid)) return;
        seen.add(net.ssid);

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'wifi-network-item';
        if (net.active) btn.classList.add('is-active');
        btn.innerHTML = `
          <span class="wifi-network-signal" data-strength="${this.strengthTier(net.signal)}"></span>
          <span class="wifi-network-name">${this.escape(net.ssid)}</span>
          ${net.secured ? '<span class="wifi-network-lock" aria-hidden="true">🔒</span>' : ''}
          ${net.active ? '<span class="wifi-network-badge">متصل</span>' : ''}
        `;
        btn.addEventListener('click', () => {
          if (net.active) {
            this.setPanelStatus(cfg().alreadyConnected || 'أنت متصل بهذه الشبكة', 'ok');
            return;
          }
          if (net.secured) this.showConnectForm(net);
          else this.connectTo(net.ssid, '');
        });
        this.networkList.appendChild(btn);
      });
    }

    async connect() {
      if (!this.selectedNetwork) return;
      const pass = this.connectPass?.value || '';
      await this.connectTo(this.selectedNetwork.ssid, pass);
    }

    async connectTo(ssid, password) {
      if (this.connecting) return;
      this.connecting = true;
      this.setPanelStatus(cfg().connecting || 'جاري الاتصال...');

      try {
        const res = await fetch('/api/wifi/connect', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ssid, password }),
        });
        const data = await res.json();
        if (!res.ok || !data.ok) {
          throw new Error(data.error || 'connect failed');
        }
        this.setPanelStatus(cfg().connectOk || 'تم الاتصال بنجاح', 'ok');
        await this.wait(900);
        await this.refresh();
        this.showList();
        this.scanNetworks();
      } catch (e) {
        this.setPanelStatus(
          (cfg().connectError || 'فشل الاتصال') + (e.message ? `: ${e.message}` : ''),
          'error',
        );
      } finally {
        this.connecting = false;
      }
    }

    escape(s) {
      const d = document.createElement('div');
      d.textContent = s;
      return d.innerHTML;
    }

    wait(ms) {
      return new Promise((r) => setTimeout(r, ms));
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => { window.hatanStatus = new SystemStatus(); });
  } else {
    window.hatanStatus = new SystemStatus();
  }
})();
