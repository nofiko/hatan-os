// HATAN OS — خلفية 3D خرافية (شاشة فارغة)

class AmbientScene {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.stars = [];
    this.ribbons = [];
    this.orbs = [];
    this.running = false;
    this.alpha = 0;
    this.rotY = 0;
    this.rotX = 0.28;
    this.time = 0;
    this.FOCAL = 720;
    this._onResize = () => this.resize();
  }

  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.build();
  }

  build() {
    this.stars = [];
    for (let i = 0; i < 1400; i++) {
      this.stars.push({
        x: (Math.random() - 0.5) * 120,
        y: (Math.random() - 0.5) * 80,
        z: (Math.random() - 0.5) * 100 - 20,
        s: 0.3 + Math.random() * 1.2,
        tw: Math.random() * Math.PI * 2,
      });
    }

    this.ribbons = [];
    for (let i = 0; i < 6; i++) {
      this.ribbons.push({
        phase: Math.random() * Math.PI * 2,
        speed: 0.3 + Math.random() * 0.4,
        amp: 18 + Math.random() * 28,
        y: -15 + Math.random() * 30,
        z: -30 - Math.random() * 40,
        hue: i % 2 === 0 ? 'cyan' : 'blue',
      });
    }

    this.orbs = [];
    for (let i = 0; i < 80; i++) {
      const a = Math.random() * Math.PI * 2;
      const r = 25 + Math.random() * 45;
      this.orbs.push({
        x: Math.cos(a) * r,
        y: (Math.random() - 0.5) * 20,
        z: Math.sin(a) * r,
        phase: Math.random() * Math.PI * 2,
        size: 0.15 + Math.random() * 0.35,
      });
    }
  }

  rotate(x, y, z) {
    let cos = Math.cos(this.rotX);
    let sin = Math.sin(this.rotX);
    let y1 = y * cos - z * sin;
    let z1 = y * sin + z * cos;
    cos = Math.cos(this.rotY);
    sin = Math.sin(this.rotY);
    return { x: x * cos + z1 * sin, y: y1, z: -x * sin + z1 * cos };
  }

  project(x, y, z) {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const r = this.rotate(x, y, z);
    const scale = this.FOCAL / (this.FOCAL + r.z);
    return {
      sx: w / 2 + r.x * scale,
      sy: h / 2 + r.y * scale,
      scale: Math.max(0.04, scale),
      depth: r.z,
    };
  }

  start() {
    this.running = true;
    this.alpha = 0;
    this.time = 0;
    this.resize();
    window.addEventListener('resize', this._onResize);
    this.animate();
  }

  stop() {
    this.running = false;
    window.removeEventListener('resize', this._onResize);
  }

  drawGrid(ctx, w, h) {
    const floorY = 42;
    const step = 14;
    const span = 28;
    const fa = this.alpha * 0.12;

    for (let i = -span; i <= span; i++) {
      const z1 = i * step;
      const p1 = this.project(-span * step, floorY, z1);
      const p2 = this.project(span * step, floorY, z1);
      if (p1.visible !== false) {
        ctx.strokeStyle = `rgba(34, 211, 238, ${fa * 0.6})`;
        ctx.lineWidth = 0.6;
        ctx.beginPath();
        ctx.moveTo(p1.sx, p1.sy);
        ctx.lineTo(p2.sx, p2.sy);
        ctx.stroke();
      }
      const x1 = i * step;
      const p3 = this.project(x1, floorY, -span * step);
      const p4 = this.project(x1, floorY, span * step);
      ctx.beginPath();
      ctx.moveTo(p3.sx, p3.sy);
      ctx.lineTo(p4.sx, p4.sy);
      ctx.stroke();
    }
  }

  drawRibbons(ctx, w, h, t) {
    for (const rib of this.ribbons) {
      const pts = [];
      for (let x = -60; x <= 60; x += 4) {
        const wave = Math.sin(x * 0.08 + t * rib.speed + rib.phase) * rib.amp;
        const wave2 = Math.cos(x * 0.05 + t * 0.4) * rib.amp * 0.4;
        pts.push(this.project(x, rib.y + wave + wave2, rib.z));
      }

      ctx.beginPath();
      let started = false;
      for (const p of pts) {
        if (p.scale < 0.05) continue;
        if (!started) { ctx.moveTo(p.sx, p.sy); started = true; }
        else ctx.lineTo(p.sx, p.sy);
      }
      const col = rib.hue === 'cyan'
        ? `rgba(34, 211, 238, ${this.alpha * 0.22})`
        : `rgba(59, 130, 246, ${this.alpha * 0.18})`;
      ctx.strokeStyle = col;
      ctx.lineWidth = 1.8;
      ctx.shadowColor = 'rgba(34, 211, 238, 0.5)';
      ctx.shadowBlur = 12;
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
  }

  animate() {
    if (!this.running) return;

    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;
    this.time += 0.016;
    this.alpha = Math.min(1, this.alpha + 0.012);
    this.rotY += 0.0038;
    this.rotX = 0.26 + Math.sin(this.time * 0.15) * 0.06;

    const bg = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.75);
    bg.addColorStop(0, `rgba(6, 18, 40, ${this.alpha})`);
    bg.addColorStop(0.45, `rgba(2, 8, 24, ${this.alpha})`);
    bg.addColorStop(1, `rgba(0, 0, 0, ${this.alpha})`);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const neb = ctx.createRadialGradient(w * 0.5, h * 0.42, 0, w * 0.5, h * 0.42, w * 0.45);
    neb.addColorStop(0, `rgba(34, 211, 238, ${0.08 * this.alpha})`);
    neb.addColorStop(0.5, `rgba(37, 99, 235, ${0.04 * this.alpha})`);
    neb.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = neb;
    ctx.fillRect(0, 0, w, h);

    this.drawGrid(ctx, w, h);
    this.drawRibbons(ctx, w, h, this.time);

    const starDraw = [];
    for (const s of this.stars) {
      const drift = Math.sin(this.time * 0.5 + s.tw) * 0.3;
      const p = this.project(s.x + drift, s.y, s.z);
      if (p.scale < 0.04) continue;
      const a = (0.35 + 0.45 * Math.sin(this.time * 1.8 + s.tw)) * this.alpha;
      starDraw.push({ p, a, s });
    }
    starDraw.sort((a, b) => a.p.depth - b.p.depth);

    for (const { p, a, s } of starDraw) {
      const r = s.s * p.scale * 2.2;
      const g = ctx.createRadialGradient(p.sx, p.sy, 0, p.sx, p.sy, r * 3);
      g.addColorStop(0, `rgba(200, 240, 255, ${a})`);
      g.addColorStop(1, 'rgba(34, 211, 238, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(p.sx, p.sy, r * 3, 0, Math.PI * 2);
      ctx.fill();
    }

    for (const orb of this.orbs) {
      const a = orb.phase + this.time * 0.6;
      const x = orb.x * Math.cos(a * 0.3) - orb.z * Math.sin(a * 0.3);
      const z = orb.x * Math.sin(a * 0.3) + orb.z * Math.cos(a * 0.3);
      const p = this.project(x, orb.y + Math.sin(a) * 3, z);
      const glow = ctx.createRadialGradient(p.sx, p.sy, 0, p.sx, p.sy, 8 * p.scale);
      glow.addColorStop(0, `rgba(103, 232, 249, ${0.5 * this.alpha})`);
      glow.addColorStop(1, 'rgba(34, 211, 238, 0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(p.sx, p.sy, 10 * p.scale * orb.size, 0, Math.PI * 2);
      ctx.fill();
    }

    const vig = ctx.createRadialGradient(w / 2, h / 2, h * 0.2, w / 2, h / 2, h * 0.85);
    vig.addColorStop(0, 'rgba(0,0,0,0)');
    vig.addColorStop(1, `rgba(0,0,0,${0.55 * this.alpha})`);
    ctx.fillStyle = vig;
    ctx.fillRect(0, 0, w, h);

    requestAnimationFrame(() => this.animate());
  }
}

window.AmbientScene = AmbientScene;
