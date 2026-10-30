(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveData = navigator.connection && navigator.connection.saveData;

  // Header state
  const nav = document.getElementById('nav');
  let navOn = null;
  const setNav = () => { const on = scrollY > 24; if (on !== navOn) { nav.classList.toggle('scrolled', on); navOn = on; } };

  // Smooth anchor scroll with header offset
  document.querySelectorAll('a[href^="#"]').forEach(a => a.addEventListener('click', e => {
    const id = a.getAttribute('href');
    const t = id === '#top' ? document.body : document.querySelector(id);
    if (!t) return;
    e.preventDefault();
    const y = id === '#top' ? 0 : t.getBoundingClientRect().top + scrollY - nav.offsetHeight - 8;
    scrollTo({ top: y, behavior: reduce ? 'auto' : 'smooth' });
    history.replaceState(null, '', id);
  }));

  // Year
  const yr = document.getElementById('yr'); if (yr) yr.textContent = new Date().getFullYear();

  // Staggered scroll reveal
  document.querySelectorAll('.stagger').forEach(g => {
    [...g.children].forEach((c, i) => c.style.setProperty('--d', (i % 3) * 0.09 + 's'));
  });
  const items = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) items.forEach(n => n.classList.add('in', 'settled'));
  else {
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (!e.isIntersecting) return;
      const n = e.target; n.classList.add('in'); io.unobserve(n);
      const d = parseFloat(getComputedStyle(n).getPropertyValue('--d')) || 0;
      setTimeout(() => n.classList.add('settled'), 950 + d * 1000);
    }), { threshold: 0.14, rootMargin: '0px 0px -6% 0px' });
    items.forEach(n => io.observe(n));
  }

  // Hero parallax (transform only, rAF-throttled, only while hero is on screen)
  const heroBg = document.getElementById('heroBg');
  const hero = document.getElementById('hero');
  let heroVisible = true, ticking = false;
  if (hero && 'IntersectionObserver' in window) new IntersectionObserver(es => { heroVisible = es[0].isIntersecting; }).observe(hero);
  const frame = () => {
    ticking = false; setNav();
    if (!reduce && heroVisible && heroBg) heroBg.style.transform = `translate3d(0,${Math.min(scrollY, innerHeight) * 0.22}px,0)`;
  };
  addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(frame); } }, { passive: true });
  frame();

  // Hero video: load after first paint, skip on reduced motion / data saver
  const hv = document.getElementById('heroVideo');
  if (hv && !reduce && !saveData) {
    const start = () => { hv.src = hv.dataset.src; hv.play().then(() => hv.classList.add('on')).catch(() => {}); };
    ('requestIdleCallback' in window) ? requestIdleCallback(start, { timeout: 2000 }) : setTimeout(start, 1200);
  }

  // Gameplay video: lazy-load when near view, play only while visible
  const cv = document.getElementById('cityVideo');
  if (cv) {
    const shot = document.getElementById('cityShot');
    const mute = document.getElementById('cityMute');
    let loaded = false;
    const load = () => {
      if (loaded) return; loaded = true;
      cv.src = cv.dataset.src;
      cv.addEventListener('loadeddata', () => { cv.hidden = false; if (shot) shot.remove(); if (mute) mute.hidden = false; }, { once: true });
      cv.addEventListener('error', () => { cv.remove(); }, { once: true });
    };
    if (saveData) { /* keep screenshot */ }
    else if ('IntersectionObserver' in window) {
      new IntersectionObserver(es => es.forEach(e => {
        if (e.isIntersecting) { load(); if (!reduce) cv.play().catch(() => {}); }
        else if (loaded) cv.pause();
      }), { rootMargin: '300px 0px', threshold: 0 }).observe(cv.parentElement);
    } else load();
    if (mute) mute.addEventListener('click', () => {
      cv.muted = !cv.muted; if (!cv.muted) cv.play().catch(() => {});
      mute.textContent = cv.muted ? 'Sound off' : 'Sound on';
      mute.setAttribute('aria-label', cv.muted ? 'Turn sound on' : 'Turn sound off');
    });
  }
})();
