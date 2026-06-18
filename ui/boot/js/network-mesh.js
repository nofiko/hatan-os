// HATAN OS — شبكة 3D + اختفاء إبداعي

class NetworkMesh {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.nodes3d = [];
    this.edges = [];
    this.pulses = [];
    this.floorLines = [];
    this.exitParticles = [];
    this.progress = 0;
    this.alpha = 0;
    this.exiting = false;
    this.running = false;
    this.exitStartTime = 0;
    this.onExitComplete = null;
    this.nodeAlpha = 1;
    this.rotY = 0;
    this.rotX = 0.35;
    this._onResize = () => this.resize();

    this.FOCAL = 680;
    this.CLEAR_RADIUS = 155;
    this.EXIT_DURATION = 2800;
    this.WAVE_SPEED = 0.52;
    this.SPIRAL_SPEED = 0.0032;
  }

  resize() {
    if (this.exiting) return;
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.build();
  }

  build() {
    this.nodes3d = [];
    this.edges = [];
    this.pulses = [];
    this.floorLines = [];

    const layers = 7;
    const cols = 16;
    const rows = 11;
    const spreadX = 920;
    const spreadY = 580;
    const spreadZ = 720;

    const idx = (l, r, c) => l * rows * cols + r * cols + c;

    for (let l = 0; l < layers; l++) {
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const wave = Math.sin(c * 0.45 + l * 0.7) * 40 + Math.cos(r * 0.5) * 30;
          this.nodes3d.push({
            x: (c / (cols - 1) - 0.5) * spreadX + (Math.random() - 0.5) * 35,
            y: (r / (rows - 1) - 0.5) * spreadY + wave + (Math.random() - 0.5) * 25,
            z: (l / (layers - 1) - 0.5) * spreadZ + (Math.random() - 0.5) * 40,
            pulse: Math.random() * Math.PI * 2
          });
        }
      }
    }

    for (let i = 0; i < 55; i++) {
      this.nodes3d.push({
        x: (Math.random() - 0.5) * spreadX * 1.15,
        y: (Math.random() - 0.5) * spreadY * 1.1,
        z: (Math.random() - 0.5) * spreadZ * 1.1,
        pulse: Math.random() * Math.PI * 2
      });
    }

    const edgeSet = new Set();
    const addEdge = (a, b) => {
      const key = a < b ? `${a}-${b}` : `${b}-${a}`;
      if (edgeSet.has(key) || a === b) return;
      edgeSet.add(key);
      const n1 = this.nodes3d[a];
      const n2 = this.nodes3d[b];
      this.edges.push({
        a, b,
        len: Math.hypot(n2.x - n1.x, n2.y - n1.y, n2.z - n1.z),
        delay: Math.random() * 0.55
      });
    };

    for (let l = 0; l < layers; l++) {
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const i = idx(l, r, c);
          if (c < cols - 1) addEdge(i, idx(l, r, c + 1));
          if (r < rows - 1) addEdge(i, idx(l, r + 1, c));
          if (l < layers - 1) addEdge(i, idx(l + 1, r, c));
        }
      }
    }

    for (let i = 0; i < this.nodes3d.length; i++) {
      const nearest = this.nodes3d
        .map((n, j) => ({
          j,
          d: i === j ? Infinity : Math.hypot(
            n.x - this.nodes3d[i].x,
            n.y - this.nodes3d[i].y,
            n.z - this.nodes3d[i].z
          )
        }))
        .sort((a, b) => a.d - b.d);

      for (let k = 1; k < Math.min(4, nearest.length); k++) {
        addEdge(i, nearest[k].j);
      }
    }

    for (let i = 0; i < 35; i++) {
      const a = Math.floor(Math.random() * this.nodes3d.length);
      const b = Math.floor(Math.random() * this.nodes3d.length);
      if (a !== b) addEdge(a, b);
    }

    const gSize = 12;
    const gSpan = 1100;
    for (let i = -gSize; i <= gSize; i++) {
      this.floorLines.push(
        { x1: -gSpan, z1: i * 75, x2: gSpan, z2: i * 75 },
        { x1: i * 75, z1: -gSpan, x2: i * 75, z2: gSpan }
      );
    }

    for (let i = 0; i < Math.min(this.edges.length, 45); i++) {
      const e = this.edges[Math.floor(Math.random() * this.edges.length)];
      this.pulses.push({ edge: e, t: Math.random(), speed: 0.004 + Math.random() * 0.007 });
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
      scale: Math.max(0.05, scale),
      depth: r.z,
      visible: r.z > -this.FOCAL + 80
    };
  }

  depthColor(depth, alpha, bright = 1) {
    const t = Math.max(0, Math.min(1, (depth + 400) / 800));
    return `rgba(${Math.floor(120 + t * 135 * bright)}, ${Math.floor(160 + t * 95 * bright)}, ${Math.floor(200 + t * 55 * bright)}, ${alpha})`;
  }

  inClearZone(sx, sy, w, h) {
    return Math.hypot(sx - w / 2, sy - h / 2) < this.CLEAR_RADIUS;
  }

  drawClearZone(ctx, w, h) {
    const cx = w / 2;
    const cy = h / 2;
    const R = this.CLEAR_RADIUS + 12;
    const hole = ctx.createRadialGradient(cx, cy, R * 0.35, cx, cy, R);
    hole.addColorStop(0, `rgba(0, 0, 0, ${this.alpha})`);
    hole.addColorStop(0.65, `rgba(0, 0, 0, ${this.alpha * 0.92})`);
    hole.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = hole;
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.fill();
  }

  lerp3d(a, b, t) {
    const n1 = this.nodes3d[a];
    const n2 = this.nodes3d[b];
    return {
      x: n1.x + (n2.x - n1.x) * t,
      y: n1.y + (n2.y - n1.y) * t,
      z: n1.z + (n2.z - n1.z) * t
    };
  }

  getEdgePoints(e) {
    const n1 = this.nodes3d[e.a];
    const n2 = this.nodes3d[e.b];
    return { p1: this.project(n1.x, n1.y, n1.z), p2: this.project(n2.x, n2.y, n2.z) };
  }

  prepareExitMeta() {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const cx = w / 2;
    const cy = h / 2;

    for (const e of this.edges) {
      const { p1, p2 } = this.getEdgePoints(e);
      const midX = (p1.sx + p2.sx) / 2;
      const midY = (p1.sy + p2.sy) / 2;
      e.exitDist = Math.hypot(midX - cx, midY - cy);
      e.exitAngle = Math.atan2(midY - cy, midX - cx);
      e.shatterSeed = Math.random() * 100;
    }
  }

  getEdgeExit(e, elapsed) {
    const waveFront = this.CLEAR_RADIUS + elapsed * this.WAVE_SPEED;
    const spiralArm = (elapsed * this.SPIRAL_SPEED) % (Math.PI * 2);

    let angleDiff = e.exitAngle - spiralArm;
    while (angleDiff < 0) angleDiff += Math.PI * 2;
    while (angleDiff >= Math.PI * 2) angleDiff -= Math.PI * 2;

    const waveHit = waveFront >= e.exitDist;
    const spiralHit = angleDiff < 1.2;

    const waveTime = Math.max(0, (e.exitDist - this.CLEAR_RADIUS) / this.WAVE_SPEED);
    const spiralTime = (angleDiff / (Math.PI * 2)) * (this.EXIT_DURATION * 0.55);
    const triggerTime = Math.min(
      waveHit ? waveTime : Infinity,
      spiralHit ? spiralTime : Infinity
    );

    if (elapsed < triggerTime) return { alive: true, t: 0 };

    const t = Math.min(1, (elapsed - triggerTime) / 340);
    if (t >= 1) return { alive: false, t: 1 };

    return { alive: true, dying: true, t };
  }

  spawnShatterParticles(x, y, count = 4) {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const cx = w / 2;
    const cy = h / 2;
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 0.4 + Math.random() * 1.2;
      this.exitParticles.push({
        x, y,
        vx: Math.cos(angle) * speed + (cx - x) * 0.008,
        vy: Math.sin(angle) * speed + (cy - y) * 0.008,
        life: 1,
        decay: 0.025 + Math.random() * 0.02,
        size: 1 + Math.random() * 2
      });
    }
  }

  drawShatteringEdge(ctx, p1, p2, t, seed, alpha) {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const cx = w / 2;
    const cy = h / 2;
    const segments = 8;
    const dx = p2.sx - p1.sx;
    const dy = p2.sy - p1.sy;
    const len = Math.hypot(dx, dy) || 1;
    const nx = -dy / len;
    const ny = dx / len;
    const ease = 1 - Math.pow(1 - t, 2);

    if (t < 0.05) {
      ctx.strokeStyle = `rgba(255, 255, 255, ${alpha * 0.9})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(p1.sx, p1.sy);
      ctx.lineTo(p2.sx, p2.sy);
      ctx.stroke();
    }

    for (let i = 0; i < segments; i++) {
      const t0 = i / segments;
      const t1 = (i + 1) / segments;
      let sx = p1.sx + dx * t0;
      let sy = p1.sy + dy * t0;
      let ex = p1.sx + dx * t1;
      let ey = p1.sy + dy * t1;
      const mx = (sx + ex) / 2;
      const my = (sy + ey) / 2;

      const wobble = Math.sin(seed + i * 1.7 + t * 18) * ease * 22;
      const pull = ease * ease;
      const px = mx + (cx - mx) * pull * 0.75 + nx * wobble;
      const py = my + (cy - my) * pull * 0.75 + ny * wobble;
      const segLen = Math.hypot(ex - sx, ey - sy);

      sx += (px - mx) * pull * 0.5;
      sy += (py - my) * pull * 0.5;
      ex += (px - mx) * pull * 0.7;
      ey += (py - my) * pull * 0.7;

      const segAlpha = alpha * (1 - ease) * (1 - i / segments * 0.35);
      if (segAlpha < 0.02) continue;

      ctx.strokeStyle = `rgba(${200 + i * 5}, ${230 - i * 3}, 255, ${segAlpha})`;
      ctx.lineWidth = Math.max(0.3, (1 - ease) * 1.4);
      ctx.setLineDash([segLen * 0.3, segLen * 0.15]);
      ctx.lineDashOffset = -t * 40 + i * 5;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.lineTo(ex, ey);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    if (t > 0.15 && t < 0.35 && Math.random() > 0.7) {
      this.spawnShatterParticles(
        p1.sx + dx * 0.5,
        p1.sy + dy * 0.5,
        2
      );
    }
  }

  drawExitWave(ctx, w, h, elapsed) {
    const cx = w / 2;
    const cy = h / 2;
    const waveR = this.CLEAR_RADIUS + elapsed * this.WAVE_SPEED;
    const fade = Math.max(0, 1 - elapsed / (this.EXIT_DURATION * 0.85));

    ctx.save();
    ctx.globalCompositeOperation = 'lighter';

    for (let i = 0; i < 3; i++) {
      const r = waveR - i * 28;
      if (r < this.CLEAR_RADIUS) continue;
      ctx.strokeStyle = `rgba(255, 255, 255, ${0.18 * fade * (1 - i * 0.3)})`;
      ctx.lineWidth = 2 - i * 0.5;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();
    }

    const spiralAngle = elapsed * this.SPIRAL_SPEED;
    const spiralLen = Math.max(w, h) * 0.65;
    ctx.strokeStyle = `rgba(180, 220, 255, ${0.12 * fade})`;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(spiralAngle) * spiralLen, cy + Math.sin(spiralAngle) * spiralLen);
    ctx.stroke();

    ctx.restore();
  }

  updateExitParticles() {
    for (const p of this.exitParticles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.96;
      p.vy *= 0.96;
      p.life -= p.decay;
    }
    this.exitParticles = this.exitParticles.filter(p => p.life > 0);
  }

  drawExitParticles(ctx) {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const cx = w / 2;
    const cy = h / 2;

    for (const p of this.exitParticles) {
      const pull = (1 - p.life) * 0.3;
      const x = p.x + (cx - p.x) * pull;
      const y = p.y + (cy - p.y) * pull;
      ctx.fillStyle = `rgba(255, 255, 255, ${p.life * 0.8})`;
      ctx.beginPath();
      ctx.arc(x, y, p.size * p.life, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  start() {
    this.progress = 0;
    this.alpha = 0;
    this.nodeAlpha = 1;
    this.exiting = false;
    this.exitStartTime = 0;
    this.onExitComplete = null;
    this.exitParticles = [];
    this.rotY = 0.4;
    this.rotX = 0.32;
    this.running = true;
    this.resize();
    window.addEventListener('resize', this._onResize);
    this.animate();
  }

  exit(onComplete) {
    this.exiting = true;
    this.exitStartTime = Date.now();
    this.onExitComplete = onComplete || null;
    this.pulses = [];
    this.exitParticles = [];
    this.prepareExitMeta();
  }

  stop() {
    this.running = false;
    window.removeEventListener('resize', this._onResize);
  }

  animate() {
    if (!this.running) return;

    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;
    const elapsed = this.exiting ? Date.now() - this.exitStartTime : 0;
    const time = Date.now() * 0.001;

    if (!this.exiting) {
      this.progress = Math.min(1, this.progress + 0.007);
      this.alpha = Math.min(1, this.alpha + 0.022);
      this.rotY += 0.0055;
      this.rotX = 0.3 + Math.sin(time * 0.2) * 0.1;
    } else {
      this.rotY += 0.002;
      this.nodeAlpha = Math.max(0, 1 - elapsed / (this.EXIT_DURATION * 0.9));
      this.updateExitParticles();

      if (elapsed > this.EXIT_DURATION) {
        this.onExitComplete?.();
        this.stop();
        return;
      }
    }

    const bg = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.7);
    bg.addColorStop(0, `rgba(8, 14, 28, ${this.alpha})`);
    bg.addColorStop(1, `rgba(0, 0, 0, ${this.alpha})`);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    const floorAlpha = this.alpha * 0.07 * (this.exiting ? this.nodeAlpha : 1);
    if (floorAlpha > 0.01 && !this.exiting) {
      const floorY = 280;
      for (const line of this.floorLines) {
        const p1 = this.project(line.x1, floorY, line.z1);
        const p2 = this.project(line.x2, floorY, line.z2);
        if (!p1.visible && !p2.visible) continue;
        ctx.strokeStyle = this.depthColor((line.z1 + line.z2) / 2, floorAlpha, 0.6);
        ctx.lineWidth = 0.5;
        ctx.beginPath();
        ctx.moveTo(p1.sx, p1.sy);
        ctx.lineTo(p2.sx, p2.sy);
        ctx.stroke();
      }
    }

    const edgeDraw = [];

    for (const e of this.edges) {
      const { p1, p2 } = this.getEdgePoints(e);
      if (!p1.visible && !p2.visible) continue;

      const midX = (p1.sx + p2.sx) / 2;
      const midY = (p1.sy + p2.sy) / 2;
      if (this.inClearZone(midX, midY, w, h)) continue;
      if (this.inClearZone(p1.sx, p1.sy, w, h) && this.inClearZone(p2.sx, p2.sy, w, h)) continue;

      if (this.exiting) {
        const exit = this.getEdgeExit(e, elapsed);
        if (!exit.alive) continue;

        if (exit.dying) {
          edgeDraw.push({ type: 'shatter', p1, p2, t: exit.t, seed: e.shatterSeed, depth: (p1.depth + p2.depth) / 2 });
        } else {
          edgeDraw.push({ type: 'line', p1, p2, depth: (p1.depth + p2.depth) / 2, full: true });
        }
      } else {
        const drawT = Math.max(0, Math.min(1, (this.progress - e.delay) * 1.3));
        if (drawT <= 0) continue;
        const end3d = this.lerp3d(e.a, e.b, drawT);
        const pEnd = this.project(end3d.x, end3d.y, end3d.z);
        edgeDraw.push({ type: 'line', p1, p2: pEnd, depth: (p1.depth + pEnd.depth) / 2, full: false });
      }
    }

    edgeDraw.sort((a, b) => b.depth - a.depth);

    for (const ed of edgeDraw) {
      if (ed.type === 'shatter') {
        this.drawShatteringEdge(ctx, ed.p1, ed.p2, ed.t, ed.seed, this.alpha);
      } else {
        const depthFade = this.alpha * (0.08 + ed.p1.scale * 0.35);
        const grad = ctx.createLinearGradient(ed.p1.sx, ed.p1.sy, ed.p2.sx, ed.p2.sy);
        grad.addColorStop(0, this.depthColor(ed.p1.depth, depthFade * 0.7));
        grad.addColorStop(1, this.depthColor(ed.p2.depth, depthFade));
        ctx.strokeStyle = grad;
        ctx.lineWidth = 0.5 + ed.p1.scale * 1.2;
        ctx.beginPath();
        ctx.moveTo(ed.p1.sx, ed.p1.sy);
        ctx.lineTo(ed.p2.sx, ed.p2.sy);
        ctx.stroke();
      }
    }

    if (!this.exiting) {
      for (const p of this.pulses) {
        p.t = (p.t + p.speed) % 1;
        const pos = this.lerp3d(p.edge.a, p.edge.b, p.t);
        const pt = this.project(pos.x, pos.y, pos.z);
        if (!pt.visible || this.inClearZone(pt.sx, pt.sy, w, h)) continue;
        const glow = ctx.createRadialGradient(pt.sx, pt.sy, 0, pt.sx, pt.sy, 8 * pt.scale);
        glow.addColorStop(0, `rgba(255, 255, 255, ${0.7 * this.alpha})`);
        glow.addColorStop(1, 'rgba(255, 255, 255, 0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(pt.sx, pt.sy, 6 * pt.scale, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    if (this.exiting) {
      this.drawExitWave(ctx, w, h, elapsed);
      this.drawExitParticles(ctx);
    }

    const nodeDraw = [];
    for (let i = 0; i < this.nodes3d.length; i++) {
      const n = this.nodes3d[i];
      const p = this.project(n.x, n.y, n.z);
      if (!p.visible || this.inClearZone(p.sx, p.sy, w, h)) continue;

      if (this.exiting) {
        const dist = Math.hypot(p.sx - w / 2, p.sy - h / 2);
        const waveFront = this.CLEAR_RADIUS + elapsed * this.WAVE_SPEED;
        if (waveFront > dist + 40) continue;
      }

      nodeDraw.push({ p, n });
    }
    nodeDraw.sort((a, b) => b.p.depth - a.p.depth);

    for (const { p, n } of nodeDraw) {
      const glow = 0.35 + 0.25 * Math.sin(time * 2 + n.pulse);
      const a = glow * this.alpha * (this.exiting ? this.nodeAlpha : 1);
      if (a <= 0) continue;
      const radius = (2 + p.scale * 3.5) * (1 + Math.sin(n.pulse) * 0.15);
      ctx.fillStyle = this.depthColor(p.depth, a * 1.1, 1.3);
      ctx.beginPath();
      ctx.arc(p.sx, p.sy, radius, 0, Math.PI * 2);
      ctx.fill();
    }

    this.drawClearZone(ctx, w, h);
    requestAnimationFrame(() => this.animate());
  }
}

window.NetworkMesh = NetworkMesh;
