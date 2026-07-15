// Image fallback on error
function imgFallback(e) {
  var el = e.target;
  if (el.dataset.fallbackSet) return;
  el.dataset.fallbackSet = '1';
  el.src = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22400%22 height=%22300%22 fill=%22%23f0f0f0%22%3E%3Crect width=%22400%22 height=%22300%22/%3E%3Ctext x=%22200%22 y=%22150%22 text-anchor=%22middle%22 fill=%22%23999%22 font-size=%2216%22 font-family=%22sans-serif%22%3EImage unavailable%3C/text%3E%3C/svg%3E';
}

// Supabase setup
const supabaseUrl = "https://yfyopxzdvyntjnocnzpi.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmeW9weHpkdnludGpub2NuenBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MTQ2MDYsImV4cCI6MjA5Njk5MDYwNn0.-p-k2H9AbOIW7_Ka5ZpybfFiCpImGMkl4dHIiuuEQFw";
const _supabaseCreateClient = window.supabase.createClient;
window.supabase = _supabaseCreateClient(supabaseUrl, supabaseKey);
window.currentUserRole = null;
window.adminPromise = new Promise(r => { window.adminResolve = r; });

// Fix all logo images on load
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.logo-img').forEach(function (img) {
    img.addEventListener('error', function () {
      this.style.display = 'none';
    });
  });

  // ─── Mobile nav toggle ───
  const toggle = document.getElementById('mobileToggle');
  const nav = document.getElementById('mainNav');
  if (toggle && nav) {
    toggle.addEventListener('click', () => nav.classList.toggle('open'));
    document.addEventListener('click', e => {
      if (!nav.contains(e.target) && !toggle.contains(e.target)) nav.classList.remove('open');
    });
  }

  // ─── Dynamic Hero Slider ───
  const slider = document.getElementById('heroSlider');
  if (slider) {
    const slidesContainer = document.getElementById('heroSlidesContainer');
    const dotsContainer = document.getElementById('sliderDots');
    const prevBtn = document.getElementById('sliderPrev');
    const nextBtn = document.getElementById('sliderNext');
    let current = 0;
    let interval;

    const gradients = [
      'linear-gradient(135deg, #1a0000 0%, #4a0000 50%, #8b0000 100%)',
      'linear-gradient(135deg, #2d0000 0%, #660000 50%, #990000 100%)',
      'linear-gradient(135deg, #3a0000 0%, #7a0000 50%, #b30000 100%)'
    ];

    const defaultImgs = [
      'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=1200',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1200',
      'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=1200'
    ];

    (async () => {
      try {
        const { data: events } = await window.supabase.from('events')
          .select('title, description, start_date, banner_url')
          .order('start_date', { ascending: true })
          .limit(3);

        const slideData = (events && events.length > 0) ? events : [
          { title: 'Rise & Run TT', start_date: null, banner_url: '' },
          { title: 'Join the Community', start_date: null, banner_url: '' },
          { title: 'Virtual & In-Person Races', start_date: null, banner_url: '' }
        ];

        slidesContainer.innerHTML = slideData.map((ev, i) => {
          const img = ev.banner_url || defaultImgs[i % defaultImgs.length];
          return '<div class="hero-slide' + (i === 0 ? ' active' : '') + '" style="background: ' + gradients[i % gradients.length] + ';">' +
            '<div class="hero-slide-bg" style="background-image: url(\'' + img + '\');" onerror="this.style.display=\'none\';"></div>' +
            '<div class="hero-slide-content">' +
              '<h1>' + (ev.title || 'Upcoming Race') + '</h1>' +
              '<a href="events.html" class="hero-btn">Register Now</a>' +
            '</div>' +
          '</div>';
        }).join('');

        const slides = slidesContainer.querySelectorAll('.hero-slide');
        if (slides.length === 0) return;

        dotsContainer.innerHTML = '';
        slides.forEach((_, i) => {
          const dot = document.createElement('button');
          dot.className = 'slider-dot' + (i === 0 ? ' active' : '');
          dot.setAttribute('aria-label', 'Go to slide ' + (i + 1));
          dot.addEventListener('click', () => goTo(i));
          dotsContainer.appendChild(dot);
        });

        const dots = dotsContainer.querySelectorAll('.slider-dot');

        function goTo(index) {
          slides.forEach(s => s.classList.remove('active'));
          dots.forEach(d => d.classList.remove('active'));
          current = (index + slides.length) % slides.length;
          slides[current].classList.add('active');
          dots[current].classList.add('active');
          resetInterval();
        }

        function next() { goTo(current + 1); }
        function prev() { goTo(current - 1); }
        function resetInterval() { clearInterval(interval); interval = setInterval(next, 5000); }

        if (prevBtn) prevBtn.addEventListener('click', prev);
        if (nextBtn) nextBtn.addEventListener('click', next);
        resetInterval();
      } catch (_) {
        renderFallbackSlides();
      }
    })();
    function renderFallbackSlides() {
      if (!slidesContainer) return;
      slidesContainer.innerHTML = defaultImgs.map(function(url, i) {
        return '<div class="hero-slide' + (i === 0 ? ' active' : '') + '" style="background: ' + gradients[i % gradients.length] + ';">' +
          '<div class="hero-slide-bg" style="background-image: url(\'' + url + '\');"></div>' +
          '<div class="hero-slide-content">' +
            '<h1>' + (['Rise & Run TT', 'Join the Community', 'Virtual & In-Person Races'][i]) + '</h1>' +
            '<a href="events.html" class="hero-btn">Register Now</a>' +
          '</div>' +
        '</div>';
      }).join('');
      var s = slidesContainer.querySelectorAll('.hero-slide');
      if (s.length === 0) return;
      dotsContainer.innerHTML = '';
      s.forEach(function(_, i) {
        var dot = document.createElement('button');
        dot.className = 'slider-dot' + (i === 0 ? ' active' : '');
        dot.setAttribute('aria-label', 'Go to slide ' + (i + 1));
        dot.addEventListener('click', function() { goToFallback(i); });
        dotsContainer.appendChild(dot);
      });
      var d = dotsContainer.querySelectorAll('.slider-dot');
      var currentFb = 0;
      function goToFallback(index) {
        s.forEach(function(el) { el.classList.remove('active'); });
        d.forEach(function(el) { el.classList.remove('active'); });
        currentFb = (index + s.length) % s.length;
        s[currentFb].classList.add('active');
        d[currentFb].classList.add('active');
        clearInterval(interval);
        interval = setInterval(function() { goToFallback(currentFb + 1); }, 5000);
      }
      if (prevBtn) prevBtn.addEventListener('click', function() { goToFallback(currentFb - 1); });
      if (nextBtn) nextBtn.addEventListener('click', function() { goToFallback(currentFb + 1); });
      interval = setInterval(function() { goToFallback(currentFb + 1); }, 5000);
    }
  }

  // ─── Carousel scroll ───
  const carouselPrev = document.getElementById('carouselPrev');
  const carouselNext = document.getElementById('carouselNext');
  const carouselTrack = document.getElementById('carouselTrack');
  if (carouselPrev && carouselNext && carouselTrack) {
    const scrollAmount = 296;
    carouselPrev.addEventListener('click', () => carouselTrack.scrollBy({ left: -scrollAmount, behavior: 'smooth' }));
    carouselNext.addEventListener('click', () => carouselTrack.scrollBy({ left: scrollAmount, behavior: 'smooth' }));
  }

  // ─── Admin status ───
  function showAdminUI() {
    if (window.currentUserRole === 'admin') return;
    window.currentUserRole = 'admin';
    document.querySelectorAll('.admin-only').forEach(el => el.style.display = 'block');
  }

  function hideAdminUI() {
    window.currentUserRole = 'user';
    document.querySelectorAll('.admin-only').forEach(el => el.style.display = 'none');
  }

  async function checkAdminStatus() {
    try {
      const { data: { user } } = await window.supabase.auth.getUser();
      if (!user) { console.log('[admin] no user'); window.adminResolve(); return; }
      const { data: role, error: rpcErr } = await window.supabase.rpc('get_my_role');
      if (role === 'admin') { showAdminUI(); }
      else if (rpcErr) { console.warn('[admin] RPC failed, denying admin:', rpcErr.message); }
    } catch (e) { console.log('[admin] error:', e); }
    window.adminResolve();
    document.dispatchEvent(new CustomEvent('admin-status-resolved', { detail: { role: window.currentUserRole } }));
  }
  checkAdminStatus();

  // ─── Auth-aware navigation ───
  (() => {
    const loginLink = document.getElementById('navLogin');
    const signupLink = document.getElementById('navSignup');
    const dashLink = document.getElementById('navDashboard');
    const logoutLink = document.getElementById('navLogout');
    let userData;
    try { userData = JSON.parse(localStorage.getItem('rr_user')); } catch (_) {}

    if (userData && userData.id) {
      if (loginLink) loginLink.style.display = 'none';
      if (signupLink) signupLink.style.display = 'none';
      if (dashLink) { dashLink.style.display = 'inline-flex'; dashLink.href = 'dashboard.html'; }
      if (logoutLink) logoutLink.style.display = 'inline-flex';
    } else {
      if (dashLink) dashLink.style.display = 'none';
      if (logoutLink) logoutLink.style.display = 'none';
    }

    const displayName = document.getElementById('userDisplayName');
    const saved = localStorage.getItem('rr_runner_name');
    if (displayName && saved) displayName.textContent = saved;
  })();

  // ─── Logout handler ───
  const logoutBtn = document.getElementById('navLogout');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async e => {
      e.preventDefault();
      try { await window.supabase.auth.signOut(); } catch (_) {}
      localStorage.removeItem('rr_token');
      localStorage.removeItem('rr_user');
      localStorage.removeItem('rr_runner_name');
      window.location.href = 'index.html';
    });
  }

  // ─── Dynamic event loading ───
  const container = document.getElementById('raceListContainer');
  const indexGrid = document.getElementById('dynamicEventGrid');
  const carouselTrackEl = document.getElementById('carouselTrack');
  let _allEvents = [];
  let _eventAthletes = {};

  // Make filter controls work on the events page
  window.applyEventFilters = function (filters) {
    if (!container) return;
    filters = filters || {};
    if (_allEvents.length === 0) { renderEventCards(container, [], ''); return; }
    let filtered = _allEvents.slice();
    const sort = filters.sort || 'upcoming';
    const year = filters.year || '';
    const search = (filters.search || '').toLowerCase();

    if (search) {
      filtered = filtered.filter(function (ev) {
        var athleteMatch = false;
        var athletes = _eventAthletes[ev.id];
        if (athletes) {
          for (var i = 0; i < athletes.length; i++) {
            if (athletes[i].toLowerCase().indexOf(search) !== -1) {
              athleteMatch = true;
              break;
            }
          }
        }
        return athleteMatch ||
               (ev.title || '').toLowerCase().indexOf(search) !== -1 ||
               (ev.location || '').toLowerCase().indexOf(search) !== -1 ||
               (ev.category || '').toLowerCase().indexOf(search) !== -1 ||
               (ev.description || '').toLowerCase().indexOf(search) !== -1 ||
               (ev.organizer_name || '').toLowerCase().indexOf(search) !== -1;
      });
    }

    if (year) {
      filtered = filtered.filter(function (ev) {
        return ev.start_date && ev.start_date.indexOf(year) === 0;
      });
    }

    if (sort === 'upcoming') {
      filtered.sort(function (a, b) {
        if (!a.start_date) return 1; if (!b.start_date) return -1;
        return a.start_date < b.start_date ? -1 : a.start_date > b.start_date ? 1 : 0;
      });
    } else if (sort === 'all') {
      filtered.sort(function (a, b) {
        if (!a.start_date) return 1; if (!b.start_date) return -1;
        return a.start_date > b.start_date ? -1 : a.start_date < b.start_date ? 1 : 0;
      });
    } else if (sort === 'recommended') {
      filtered.sort(function (a, b) {
        var aWeight = (a.category === 'In-Person' || a.category === 'Both' ? 2 : 0);
        var bWeight = (b.category === 'In-Person' || b.category === 'Both' ? 2 : 0);
        if (!a.start_date) return 1; if (!b.start_date) return -1;
        aWeight += a.start_date > new Date().toISOString().slice(0,10) ? 1 : 0;
        bWeight += b.start_date > new Date().toISOString().slice(0,10) ? 1 : 0;
        return bWeight - aWeight;
      });
    }

    if (container) renderEventCards(container, filtered, search);
  };

  function renderEventCards(target, events, searchTerm) {
    if (!events || events.length === 0) { target.innerHTML = '<div class="empty-state"><i class="fas fa-search"></i><p>' + (searchTerm ? 'No events match "' + searchTerm + '".' : 'No events match your filters.') + '</p></div>'; return; }
    const imgs = [
      'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1461896836934-bd45ba8fcf9b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1579126038374-6064e9370f0f?w=400&h=300&fit=crop'
    ];
    target.innerHTML = events.map(function (ev) {
      const safeId = ev.id || Math.floor(Math.random() * imgs.length);
      const img = ev.banner_url || imgs[safeId % imgs.length];
      let dateDisplay = ev.start_date || '';
      if (ev.start_time) dateDisplay += ' \u00b7 ' + ev.start_time;
      return '<div class="race-card" style="position:relative;cursor:pointer;" data-href="event_detail.html?id=' + ev.id + '">' +
        '<button class="admin-only admin-delete-btn" data-id="' + ev.id + '" style="display:none;position:absolute;top:8px;right:8px;z-index:2;background:var(--accent-red);color:white;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;align-items:center;justify-content:center;font-size:14px;line-height:1;">&times;</button>' +
        '<div class="race-card-img-wrap"><img src="' + img + '" alt="' + ev.title + '" class="race-card-img" onerror="imgFallback(event)"></div>' +
        '<div class="race-card-content">' +
          '<div class="race-card-info">' +
            '<div class="race-card-datetime"><span>' + dateDisplay + '</span></div>' +
            '<h3 class="race-card-name">' + ev.title + '</h3>' +
            '<div class="race-card-venue">' + (ev.location || '') + '</div>' +
          '</div>' +
        '</div>' +
      '</div>';
    }).join('');
    document.querySelectorAll('.race-card').forEach(function (card) {
      card.addEventListener('click', function (e) {
        if (e.target.closest('.admin-delete-btn')) return;
        const href = this.dataset.href;
        if (href) window.location.href = href;
      });
    });
    if (window.currentUserRole === 'admin') {
      document.querySelectorAll('.admin-only').forEach(function (el) { el.style.display = 'block'; });
    }
    document.querySelectorAll('.admin-delete-btn').forEach(function (btn) {
      btn.addEventListener('click', async function (e) {
        e.stopPropagation();
        if (!confirm('Delete this event permanently?')) return;
        const { error } = await window.supabase.from('events').delete().eq('id', this.dataset.id);
        if (error) { alert('Delete failed: ' + error.message); return; }
        this.closest('.race-card').remove();
      });
    });
  }

  // Initial event data load
  if (container || indexGrid) {
    (async function () {
      await window.adminPromise;
      const [{ data: events, error }, { data: regs }] = await Promise.all([
        window.supabase.from('events').select('*').order('created_at', { ascending: false }),
        window.supabase.from('registrations').select('event_id, billing_first_name, billing_last_name, attendee_first_name, attendee_last_name')
      ]);
      if (!error && events) _allEvents = events;
      if (regs) {
        regs.forEach(function (r) {
          if (!r.event_id) return;
          if (!_eventAthletes[r.event_id]) _eventAthletes[r.event_id] = [];
          var names = [r.billing_first_name, r.billing_last_name, r.attendee_first_name, r.attendee_last_name].filter(Boolean);
          names.forEach(function (n) {
            if (_eventAthletes[r.event_id].indexOf(n) === -1) _eventAthletes[r.event_id].push(n);
          });
        });
      }
      if (container) {
        var si = document.querySelector('.search-bar input');
        var sl = document.querySelector('.sort-link.active');
        var sy = document.querySelector('.sort-year');
        if (si && si.value) {
          window.applyEventFilters({
            sort: sl ? sl.textContent.toLowerCase().replace(/\s+/g, '') : 'upcoming',
            year: sy ? sy.value : '',
            search: si.value
          });
        } else {
          renderEventCards(container, _allEvents, '');
        }
      }
      if (indexGrid) {
        indexGrid.innerHTML = _allEvents.slice(0, 3).map(function (ev) {
          const safeId = ev.id || 0;
          const img = (ev.banner_url || 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop');
          let dateDisplay = ev.start_date || '';
          if (ev.start_time) dateDisplay += ' \u00b7 ' + ev.start_time;
          return '<div class="event-card" style="position:relative;cursor:pointer;" data-href="event_detail.html?id=' + ev.id + '">' +
            '<button class="admin-only admin-delete-btn" data-id="' + ev.id + '" style="display:none;position:absolute;top:8px;right:8px;z-index:2;background:var(--accent-red);color:white;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;align-items:center;justify-content:center;font-size:14px;line-height:1;">&times;</button>' +
            '<img src="' + img + '" alt="" class="event-card-img" onerror="imgFallback(event)">' +
            '<div class="event-card-body">' +
              '<span class="event-card-date">' + dateDisplay + '</span>' +
              '<h3>' + ev.title + '</h3>' +
              '<div class="event-card-meta"><i class="fas fa-map-marker-alt"></i> ' + (ev.location || '') + '</div>' +
              (ev.price && ev.price !== '0.00' ? '<span class="event-card-price">TTD' + ev.price + '</span>' : '') +
            '</div>' +
          '</div>';
        }).join('');
        document.querySelectorAll('.event-card').forEach(function (card) {
          card.addEventListener('click', function (e) {
            if (e.target.closest('.admin-delete-btn')) return;
            const href = this.dataset.href;
            if (href) window.location.href = href;
          });
        });
      }
    })();
  }

  if (carouselTrackEl && !carouselTrackEl.querySelector('.carousel-card')) loadCarousel(carouselTrackEl);

  // ─── Load carousel ───
  async function loadCarousel(track) {
    try {
      const { data: events, error } = await window.supabase.from('events').select('*').order('start_date', { ascending: true }).limit(8);
      if (error || !events || events.length === 0) { track.style.display = 'none'; return; }

      const imgs = [
        'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1461896836934-bd45ba8fcf9b?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1576678927484-cc907957088c?w=600&h=600&fit=crop'
      ];

      track.style.display = '';
      track.innerHTML = events.map(ev => {
        const safeId = ev.id || Math.floor(Math.random() * imgs.length);
        const img = ev.banner_url || imgs[safeId % imgs.length];
        const cat = ev.category || 'Race';
        let dateDisplay = ev.start_date || '';
        if (ev.start_time) dateDisplay += ' · ' + ev.start_time;
        return '<div class="carousel-card" data-href="event_detail.html?id=' + ev.id + '" style="cursor:pointer;">' +
          '<div class="carousel-card-link">' +
            '<div class="carousel-card-img" style="background-image:url(\'' + img + '\');" onerror="this.style.display=\'none\';">' +
              '<span class="carousel-badge">' + cat + '</span>' +
              '<div class="carousel-card-footer">' +
                '<p class="carousel-date">' + dateDisplay + '</p>' +
                '<p class="carousel-title">' + ev.title + '</p>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
      }).join('');
      track.querySelectorAll('.carousel-card').forEach(card => {
        card.addEventListener('click', () => {
          const href = card.dataset.href;
          if (href) window.location.href = href;
        });
      });
    } catch (_) {}
  }

  // ─── PWA: Register service worker ───
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  // ─── PWA: Install prompt ───
  let deferredPrompt = null;
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    const installBtn = document.getElementById('installAppBtn');
    if (installBtn) installBtn.style.display = 'inline-flex';
  });

  const installBtn = document.getElementById('installAppBtn');
  if (installBtn) {
    installBtn.addEventListener('click', async () => {
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      const result = await deferredPrompt.userChoice;
      if (result.outcome === 'accepted') installBtn.style.display = 'none';
      deferredPrompt = null;
    });
  }

});
