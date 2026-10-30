(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // nav background on scroll
  const nav = document.getElementById('nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 30);
  addEventListener('scroll', onScroll, { passive: true }); onScroll();

  // year
  const yr = document.getElementById('yr'); if (yr) yr.textContent = new Date().getFullYear();

  // typed tagline
  const lines = ['Make games on your phone.', 'Godot 4.7.2 editor, now CHoMU.', 'GDScript. 2D. 3D. Android.', 'Play Chomu City today.'];
  const el = document.getElementById('typed');
  if (el) {
    if (reduce) el.textContent = lines[0];
    else {
      let li = 0, ci = 0, del = false;
      const tick = () => {
        const s = lines[li];
        el.textContent = s.slice(0, ci);
        if (!del && ci < s.length) ci++;
        else if (!del) { del = true; return setTimeout(tick, 1600); }
        else if (ci > 0) ci--;
        else { del = false; li = (li + 1) % lines.length; }
        setTimeout(tick, del ? 35 : 70);
      };
      setTimeout(tick, 1200);
    }
  }

  // scroll reveal
  const io = new IntersectionObserver((es) => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { threshold: .12 });
  document.querySelectorAll('.reveal').forEach(n => io.observe(n));

  // hover tilt (pointer devices only)
  if (!reduce && matchMedia('(hover: hover)').matches) {
    document.querySelectorAll('.tilt, .tilt-soft').forEach(card => {
      const max = card.classList.contains('tilt-soft') ? 5 : 10;
      card.addEventListener('pointermove', ev => {
        const r = card.getBoundingClientRect();
        const x = (ev.clientX - r.left) / r.width - .5, y = (ev.clientY - r.top) / r.height - .5;
        card.style.transform = `perspective(900px) rotateY(${x * max}deg) rotateX(${-y * max}deg) translateY(-4px)`;
      });
      card.addEventListener('pointerleave', () => { card.style.transform = ''; });
    });
  }

  // optional videos: only shown if the file exists (drop-in slots)
  const tryVideo = (v, onOk) => {
    if (!v) return;
    const src = v.dataset.src;
    fetch(src, { method: 'HEAD' }).then(r => {
      const ct = r.headers.get('content-type') || '';
      if (r.ok && ct.startsWith('video')) { v.src = src; onOk(v); }
    }).catch(() => {});
  };
  tryVideo(document.getElementById('cityVideo'), v => {
    v.hidden = false; const shot = document.getElementById('cityShot'); if (shot) shot.remove();
    new IntersectionObserver(es => es.forEach(e => e.isIntersecting ? v.play().catch(()=>{}) : v.pause()), { threshold: .4 }).observe(v);
  });
  if (!reduce) tryVideo(document.getElementById('heroVideo'), v => { v.play().then(() => v.classList.add('on')).catch(()=>{}); });

  // particles
  const c = document.getElementById('particles');
  if (!c || reduce) return;
  const ctx = c.getContext('2d');
  let w, h, dpr, pts = [];
  const resize = () => {
    dpr = Math.min(devicePixelRatio || 1, 2);
    w = c.width = innerWidth * dpr; h = c.height = innerHeight * dpr;
    c.style.width = innerWidth + 'px'; c.style.height = innerHeight + 'px';
    const n = Math.min(90, Math.floor(innerWidth * innerHeight / 16000));
    pts = Array.from({ length: n }, () => ({
      x: Math.random() * w, y: Math.random() * h,
      vx: (Math.random() - .5) * .35 * dpr, vy: (Math.random() - .5) * .35 * dpr,
      r: (Math.random() * 1.6 + .4) * dpr, hue: Math.random() < .5 ? 185 : 310
    }));
  };
  resize(); addEventListener('resize', resize);
  let mx = -1e4, my = -1e4;
  addEventListener('pointermove', e => { mx = e.clientX * dpr; my = e.clientY * dpr; }, { passive: true });
  const link = 120;
  const frame = () => {
    ctx.clearRect(0, 0, w, h);
    for (const p of pts) {
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0 || p.x > w) p.vx *= -1;
      if (p.y < 0 || p.y > h) p.vy *= -1;
      const dx = p.x - mx, dy = p.y - my, d2 = dx * dx + dy * dy;
      if (d2 < 10000 * dpr * dpr) { p.x += dx * .02; p.y += dy * .02; }
      ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7);
      ctx.fillStyle = `hsla(${p.hue},100%,65%,.8)`; ctx.fill();
    }
    for (let i = 0; i < pts.length; i++) for (let j = i + 1; j < pts.length; j++) {
      const a = pts[i], b = pts[j], dx = a.x - b.x, dy = a.y - b.y, d = Math.hypot(dx, dy);
      if (d < link * dpr) {
        ctx.strokeStyle = `rgba(0,240,255,${(1 - d / (link * dpr)) * .18})`;
        ctx.lineWidth = dpr * .6; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      }
    }
    requestAnimationFrame(frame);
  };
  document.addEventListener('visibilitychange', () => {}); frame();
})();
