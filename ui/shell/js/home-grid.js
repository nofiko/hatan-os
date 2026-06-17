// HATAN OS — خلفية تقنية ثلاثية الأبعاد للشاشة الرئيسية

class HomeGrid3D {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.running = false;
    this.t = 0;
    this.stars = [];
    this.nodes = [];
    this._onResize = () => this.resize();
    this.resize();
    this._initStars();
    this._initNodes();
    window.addEventListener('resize', this._onResize);
  }

  _color(name, fallback) {
    const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
    return v || fallback;
  }

  _parseRgb(hexOrRgb) {
    if (hexOrRgb.startsWith('#')) {
      const h = hexOrRgb.slice(1);
      const full = h.length === 3 ? h.split('').map(c => c + c).join('') : h;
      const n = parseInt(full, 16);
      return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    return [34, 211, 238];
  }

  _initStars() {
    this.stars = Array.from({ length: 90 }, () => ({
      x: Math.random(),
      y: Math.random() * 0.55,
      z: 0.2 + Math.random() * 0.8,
      s: 0.4 + Math.random() * 1.4,
      tw: Math.random() * Math.PI * 2,
    }));
  }

  _initNodes() {
    this.nodes = [];
    const cols = 10;
    const rows = 8;
    for (let r = 0; r <= rows; r++) {
      for (let c = -cols / 2; c <= cols / 2; c++) {
        if ((r + c) % 3 === 0) {
          this.nodes.push({ c, r: r / rows, phase: Math.random() * Math.PI * 2 });
        }
      }
    }
  }

  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.cx = this.canvas.width / 2;
    this.horizon = this.canvas.height * 0.38;
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.tick();
  }

  stop() {
    this.running = false;
  }

  tick() {
    if (!this.running) return;
    this.t += 0.016;
    this.draw();
    requestAnimationFrame(() => this.tick());
  }

  _floorY(tNorm) {
    const { horizon, canvas } = this;
    return horizon + Math.pow(tNorm, 2.1) * (canvas.height - horizon + 20);
  }

  draw() {
    const { ctx, canvas, cx, horizon, t, stars, nodes } = this;
    const electric = this._parseRgb(this._color('--electric', '#22D3EE'));
    const primary = this._parseRgb(this._color('--primary', '#2563EB'));
    const [er, eg, eb] = electric;
    const [pr, pg, pb] = primary;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // ── سماء / جزيئات ──
    const sky = ctx.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, `rgba(${pr}, ${pg}, ${pb}, 0.12)`);
    sky.addColorStop(0.5, `rgba(2, 8, 24, 0.4)`);
    sky.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, canvas.width, horizon + 40);

    for (const s of stars) {
      const sx = s.x * canvas.width + Math.sin(t * 0.3 + s.tw) * 4 * s.z;
      const sy = s.y * horizon * 0.95 + Math.cos(t * 0.25 + s.tw) * 3;
      const a = 0.15 + Math.abs(Math.sin(t * 1.2 + s.tw)) * 0.45 * s.z;
      ctx.fillStyle = `rgba(${er}, ${eg}, ${eb}, ${a})`;
      ctx.fillRect(sx, sy, s.s, s.s);
    }

    // ── خط أفق متوهج ──
    const hGrad = ctx.createLinearGradient(0, horizon, canvas.width, horizon);
    hGrad.addColorStop(0, 'transparent');
    hGrad.addColorStop(0.2, `rgba(${er}, ${eg}, ${eb}, 0.35)`);
    hGrad.addColorStop(0.5, `rgba(255, 255, 255, 0.55)`);
    hGrad.addColorStop(0.8, `rgba(${er}, ${eg}, ${eb}, 0.35)`);
    hGrad.addColorStop(1, 'transparent');
    ctx.strokeStyle = hGrad;
    ctx.lineWidth = 2;
    ctx.shadowColor = `rgba(${er}, ${eg}, ${eb}, 0.8)`;
    ctx.shadowBlur = 12;
    ctx.beginPath();
    ctx.moveTo(0, horizon);
    ctx.lineTo(canvas.width, horizon);
    ctx.stroke();
    ctx.shadowBlur = 0;

    // ── أرضية شبكة 3D ──
    const rows = 16;
    const scroll = (t * 28) % 40;

    for (let i = 0; i <= rows; i++) {
      const tNorm = i / rows;
      const y = this._floorY(tNorm);
      const alpha = 0.06 + tNorm * 0.38;
      ctx.strokeStyle = `rgba(${er}, ${eg}, ${eb}, ${alpha * 0.55})`;
      ctx.lineWidth = tNorm > 0.85 ? 1.5 : 1;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(canvas.width, y);
      ctx.stroke();

      const pulse = ((y - horizon + scroll) % 40);
      if (pulse < 3 && tNorm > 0.15) {
        ctx.fillStyle = `rgba(${er}, ${eg}, ${eb}, ${0.25 + tNorm * 0.5})`;
        ctx.fillRect(cx - 3, y - 1, 6, 2);
      }
    }

    const cols = 18;
    for (let c = -cols / 2; c <= cols / 2; c++) {
      const spread = 1 + Math.abs(c) * 0.035;
      const xTop = cx + c * 22;
      const xBot = cx + c * spread * 380;
      const alpha = 0.05 + (1 - Math.abs(c) / (cols / 2)) * 0.22;
      ctx.strokeStyle = `rgba(${pr}, ${pg}, ${pb}, ${alpha})`;
      ctx.lineWidth = c === 0 ? 1.5 : 0.8;
      ctx.beginPath();
      ctx.moveTo(xTop, horizon);
      ctx.lineTo(xBot, canvas.height + 30);
      ctx.stroke();
    }

    // ── نقاط طاقة على الشبكة ──
    for (const n of nodes) {
      const tNorm = n.r;
      const y = this._floorY(tNorm);
      const spread = 1 + Math.abs(n.c) * 0.035;
      const x = cx + n.c * spread * (22 + tNorm * 358);
      const pulse = 0.4 + Math.sin(t * 2 + n.phase) * 0.6;
      const r = 1.5 + tNorm * 2.5;
      ctx.fillStyle = `rgba(${er}, ${eg}, ${eb}, ${(0.15 + tNorm * 0.35) * pulse})`;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }

    // ── مسح ضوئي ──
    const scanY = horizon + ((t * 45) % (canvas.height - horizon));
    const scan = ctx.createLinearGradient(0, scanY - 20, 0, scanY + 20);
    scan.addColorStop(0, 'transparent');
    scan.addColorStop(0.5, `rgba(${er}, ${eg}, ${eb}, 0.06)`);
    scan.addColorStop(1, 'transparent');
    ctx.fillStyle = scan;
    ctx.fillRect(0, scanY - 20, canvas.width, 40);

    // ── توهج مركزي ──
    const glow = ctx.createRadialGradient(cx, horizon, 0, cx, horizon, canvas.width * 0.55);
    glow.addColorStop(0, `rgba(${er}, ${eg}, ${eb}, 0.14)`);
    glow.addColorStop(0.25, `rgba(${pr}, ${pg}, ${pb}, 0.08)`);
    glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // ── تدرج أسفل ──
    const floorFade = ctx.createLinearGradient(0, horizon, 0, canvas.height);
    floorFade.addColorStop(0, 'rgba(0, 0, 0, 0)');
    floorFade.addColorStop(0.4, 'rgba(2, 8, 20, 0.25)');
    floorFade.addColorStop(1, 'rgba(0, 0, 0, 0.55)');
    ctx.fillStyle = floorFade;
    ctx.fillRect(0, horizon, canvas.width, canvas.height - horizon);
  }
}
