const COLORS = ["#2ee7ff", "#ff4777", "#ffbf3c", "#8a57ff", "#57db4d", "#ff8a66"];
const TAU = Math.PI * 2;

export function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value));
}

export function findNearestBlob(blobs, x, y) {
  return blobs.reduce((nearest, blob) => {
    if (!nearest) return blob;
    const blobDistance = (blob.x - x) ** 2 + (blob.y - y) ** 2;
    const nearestDistance = (nearest.x - x) ** 2 + (nearest.y - y) ** 2;
    return blobDistance < nearestDistance ? blob : nearest;
  }, null);
}

export function flingVelocity(origin, target, speed = 15) {
  const dx = target.x - origin.x;
  const dy = target.y - origin.y;
  const distance = Math.hypot(dx, dy);
  if (distance < 0.001) return { x: speed, y: 0 };
  return { x: (dx / distance) * speed, y: (dy / distance) * speed };
}

class BlobArena {
  constructor(canvas) {
    this.canvas = canvas;
    this.context = canvas.getContext("2d", { alpha: true });
    this.blobs = [];
    this.particles = [];
    this.pointer = { x: 0, y: 0, active: false };
    this.lastTime = 0;
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.visible = !document.hidden;
    this.inViewport = false;
    this.running = false;
    this.frameId = null;
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(canvas.parentElement);
    this.visibilityObserver = new IntersectionObserver((entries) => {
      this.inViewport = entries[0]?.isIntersecting ?? false;
      if (this.inViewport) this.start();
      else this.stop();
    }, { rootMargin: "120px" });
    this.visibilityObserver.observe(canvas.parentElement);
    this.bindEvents();
    this.resize();
    this.createBlobs();
    this.draw();
  }

  start() {
    if (this.reducedMotion || !this.visible || !this.inViewport || this.running) return;
    this.running = true;
    this.lastTime = 0;
    this.frameId = requestAnimationFrame((time) => this.tick(time));
  }

  stop() {
    this.running = false;
    if (this.frameId !== null) cancelAnimationFrame(this.frameId);
    this.frameId = null;
  }

  resize() {
    const bounds = this.canvas.parentElement.getBoundingClientRect();
    const ratio = Math.min(window.devicePixelRatio || 1, 1.5);
    this.width = Math.max(1, bounds.width);
    this.height = Math.max(1, bounds.height);
    this.canvas.width = Math.round(this.width * ratio);
    this.canvas.height = Math.round(this.height * ratio);
    this.context.setTransform(ratio, 0, 0, ratio, 0, 0);
    this.blobs.forEach((blob) => {
      blob.x = clamp(blob.x, blob.radius, this.width - blob.radius);
      blob.y = clamp(blob.y, blob.radius, this.height - blob.radius);
    });
    this.draw();
  }

  createBlobs() {
    const count = this.width < 600 ? 5 : 8;
    this.blobs = Array.from({ length: count }, (_, index) => {
      const radius = this.width < 600 ? 30 + (index % 3) * 5 : 38 + (index % 4) * 5;
      return {
        x: radius + ((this.width - radius * 2) * (index + 1)) / (count + 1),
        y: this.height * (0.28 + ((index * 37) % 52) / 100),
        vx: (index % 2 ? -1 : 1) * (1.8 + (index % 3) * 0.45),
        vy: -1.2 + (index % 4) * 0.75,
        radius,
        color: COLORS[index % COLORS.length],
        wobble: index * 0.8,
        trail: [],
      };
    });
  }

  bindEvents() {
    const updatePointer = (event) => {
      const bounds = this.canvas.getBoundingClientRect();
      const point = event.touches?.[0] ?? event;
      this.pointer.x = point.clientX - bounds.left;
      this.pointer.y = point.clientY - bounds.top;
      this.pointer.active = true;
    };

    this.canvas.parentElement.addEventListener("pointermove", updatePointer, { passive: true });
    this.canvas.parentElement.addEventListener("pointerleave", () => {
      this.pointer.active = false;
    });
    this.canvas.parentElement.addEventListener("pointerdown", (event) => {
      updatePointer(event);
      this.activateFling(this.pointer);
    });

    this.canvas.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      this.activateFling({ x: this.width / 2, y: this.height * 0.28 });
    });

    document.addEventListener("visibilitychange", () => {
      this.visible = !document.hidden;
      if (this.visible) this.start();
      else this.stop();
    });
  }

  activateFling(target) {
    const blob = findNearestBlob(this.blobs, target.x, target.y);
    if (!blob) return;
    if (this.reducedMotion) {
      blob.x = clamp(target.x, blob.radius, this.width - blob.radius);
      blob.y = clamp(target.y, blob.radius + 24, this.height - blob.radius - 20);
      blob.vx = 0;
      blob.vy = 0;
      this.draw();
      return;
    }

    const velocity = flingVelocity(blob, target, this.width < 600 ? 12 : 16);
    blob.vx = velocity.x;
    blob.vy = velocity.y;
    this.burst(blob.x, blob.y, blob.color, 18);
    this.canvas.parentElement.animate(
      [{ transform: "scale(1)" }, { transform: "scale(0.995)" }, { transform: "scale(1)" }],
      { duration: 180, easing: "ease-out" },
    );
  }

  burst(x, y, color, count = 10) {
    for (let index = 0; index < count && this.particles.length < 140; index += 1) {
      const angle = (index / count) * TAU + Math.random() * 0.3;
      const speed = 2 + Math.random() * 5;
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1,
        size: 2 + Math.random() * 5,
        color,
      });
    }
  }

  tick(time) {
    if (!this.running || !this.visible || !this.inViewport) {
      this.stop();
      return;
    }
    const delta = this.lastTime ? Math.min((time - this.lastTime) / 16.67, 2) : 1;
    this.lastTime = time;
    this.update(delta, time * 0.001);
    this.draw();
    this.frameId = requestAnimationFrame((nextTime) => this.tick(nextTime));
  }

  update(delta, time) {
    for (const blob of this.blobs) {
      if (this.pointer.active) {
        const dx = this.pointer.x - blob.x;
        const dy = this.pointer.y - blob.y;
        const distance = Math.max(Math.hypot(dx, dy), 1);
        if (distance < 210) {
          const pull = (1 - distance / 210) * 0.045;
          blob.vx += (dx / distance) * pull * delta;
          blob.vy += (dy / distance) * pull * delta;
        }
      }

      blob.vy += 0.035 * delta;
      blob.vx *= 0.998 ** delta;
      blob.vy *= 0.998 ** delta;
      blob.x += blob.vx * delta;
      blob.y += blob.vy * delta;
      blob.wobble = time * 4 + blob.radius;
      blob.trail.unshift({ x: blob.x, y: blob.y });
      blob.trail.length = Math.min(blob.trail.length, 10);

      if (blob.x < blob.radius || blob.x > this.width - blob.radius) {
        blob.x = clamp(blob.x, blob.radius, this.width - blob.radius);
        blob.vx *= -0.88;
        this.burst(blob.x, blob.y, blob.color, 5);
      }
      if (blob.y < blob.radius + 24 || blob.y > this.height - blob.radius - 20) {
        blob.y = clamp(blob.y, blob.radius + 24, this.height - blob.radius - 20);
        blob.vy *= -0.88;
        this.burst(blob.x, blob.y, blob.color, 5);
      }
    }

    this.resolveCollisions();
    this.particles = this.particles.filter((particle) => {
      particle.x += particle.vx * delta;
      particle.y += particle.vy * delta;
      particle.vy += 0.08 * delta;
      particle.life -= 0.025 * delta;
      return particle.life > 0;
    });
  }

  resolveCollisions() {
    for (let firstIndex = 0; firstIndex < this.blobs.length; firstIndex += 1) {
      for (let secondIndex = firstIndex + 1; secondIndex < this.blobs.length; secondIndex += 1) {
        const first = this.blobs[firstIndex];
        const second = this.blobs[secondIndex];
        const dx = second.x - first.x;
        const dy = second.y - first.y;
        const distance = Math.max(Math.hypot(dx, dy), 0.1);
        const minimum = first.radius + second.radius;
        if (distance >= minimum) continue;

        const nx = dx / distance;
        const ny = dy / distance;
        const overlap = (minimum - distance) * 0.5;
        first.x -= nx * overlap;
        first.y -= ny * overlap;
        second.x += nx * overlap;
        second.y += ny * overlap;
        const relative = (second.vx - first.vx) * nx + (second.vy - first.vy) * ny;
        if (relative < 0) {
          first.vx += relative * nx;
          first.vy += relative * ny;
          second.vx -= relative * nx;
          second.vy -= relative * ny;
          this.burst((first.x + second.x) / 2, (first.y + second.y) / 2, "#ffffff", 6);
        }
      }
    }
  }

  draw() {
    const context = this.context;
    context.clearRect(0, 0, this.width, this.height);
    this.drawArenaLines(context);
    for (const blob of this.blobs) this.drawBlob(context, blob);
    for (const particle of this.particles) {
      context.globalAlpha = particle.life;
      context.fillStyle = particle.color;
      context.beginPath();
      context.arc(particle.x, particle.y, particle.size * particle.life, 0, TAU);
      context.fill();
    }
    context.globalAlpha = 1;
  }

  drawArenaLines(context) {
    context.save();
    context.strokeStyle = "rgba(247, 254, 255, 0.1)";
    context.lineWidth = 1;
    context.setLineDash([7, 10]);
    context.beginPath();
    context.arc(this.width / 2, this.height / 2, Math.min(this.width, this.height) * 0.25, 0, TAU);
    context.moveTo(this.width / 2, 0);
    context.lineTo(this.width / 2, this.height);
    context.stroke();
    context.restore();
  }

  drawBlob(context, blob) {
    for (let index = blob.trail.length - 1; index >= 2; index -= 2) {
      const point = blob.trail[index];
      context.globalAlpha = (1 - index / blob.trail.length) * 0.16;
      context.fillStyle = blob.color;
      context.beginPath();
      context.arc(point.x, point.y, blob.radius * (0.5 - index * 0.018), 0, TAU);
      context.fill();
    }
    context.globalAlpha = 1;

    const speed = Math.hypot(blob.vx, blob.vy);
    const stretch = clamp(speed / 32, 0, 0.26);
    const angle = Math.atan2(blob.vy, blob.vx);
    context.save();
    context.translate(blob.x, blob.y);
    context.rotate(angle);
    context.scale(1 + stretch, 1 - stretch * 0.62);
    context.shadowColor = blob.color;
    context.shadowBlur = 22;
    context.fillStyle = blob.color;
    context.beginPath();
    context.ellipse(0, 0, blob.radius, blob.radius * (1 + Math.sin(blob.wobble) * 0.025), 0, 0, TAU);
    context.fill();
    context.shadowBlur = 0;

    context.globalAlpha = 0.42;
    context.fillStyle = "#ffffff";
    context.beginPath();
    context.ellipse(-blob.radius * 0.3, -blob.radius * 0.38, blob.radius * 0.23, blob.radius * 0.13, -0.5, 0, TAU);
    context.fill();
    context.globalAlpha = 1;

    const eyeX = blob.radius * 0.25;
    for (const eyeY of [-blob.radius * 0.24, blob.radius * 0.24]) {
      context.fillStyle = "#f7feff";
      context.beginPath();
      context.ellipse(eyeX, eyeY, blob.radius * 0.18, blob.radius * 0.14, 0, 0, TAU);
      context.fill();
      context.fillStyle = "#07101f";
      context.beginPath();
      context.arc(eyeX + blob.radius * 0.055, eyeY, blob.radius * 0.065, 0, TAU);
      context.fill();
    }

    context.strokeStyle = "#07101f";
    context.lineWidth = Math.max(2, blob.radius * 0.055);
    context.lineCap = "round";
    context.beginPath();
    context.arc(blob.radius * 0.18, 0, blob.radius * 0.2, -0.55, 0.55);
    context.stroke();
    context.restore();
  }
}

function startPage() {
  document.documentElement.classList.add("motion-ready");
  const canvas = document.querySelector("#blob-playground");
  if (canvas) new BlobArena(canvas);

  const observer = new IntersectionObserver(
    (entries) => entries.forEach((entry) => entry.isIntersecting && entry.target.classList.add("is-visible")),
    { threshold: 0.12 },
  );
  document.querySelectorAll(".feature, .gallery-card, .modes-visual").forEach((element) => observer.observe(element));
}

if (typeof document !== "undefined") startPage();
