// Supabase setup
const supabaseUrl = "https://yfyopxzdvyntjnocnzpi.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmeW9weHpkdnludGpub2NuenBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MTQ2MDYsImV4cCI6MjA5Njk5MDYwNn0.-p-k2H9AbOIW7_Ka5ZpybfFiCpImGMkl4dHIiuuEQFw";
const _supabaseCreateClient = window.supabase.createClient;
window.supabase = _supabaseCreateClient(supabaseUrl, supabaseKey);
window.currentUserRole = null;
window.adminPromise = new Promise(r => { window.adminResolve = r; });

document.addEventListener('DOMContentLoaded', () => {

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
            '<div class="hero-slide-bg" style="background-image: url(\'' + img + '\');"></div>' +
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
      } catch (_) {}
    })();
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

  // ─── Admin status (localStorage fast-path + server verify) ───
  function showAdminUI() {
    window.currentUserRole = 'admin';
    document.querySelectorAll('.admin-only').forEach(el => el.style.display = 'block');
    document.getElementById('navLogin') && (document.getElementById('navLogin').style.display = 'none');
    document.getElementById('navSignup') && (document.getElementById('navSignup').style.display = 'none');
  }
  function hideAdminUI() {
    window.currentUserRole = 'user';
    document.querySelectorAll('.admin-only').forEach(el => el.style.display = 'none');
  }

  // Fast path: use role from localStorage (set during login)
  try {
    var _stored = JSON.parse(localStorage.getItem('rr_user') || '{}');
    if (_stored.role === 'admin') showAdminUI();
  } catch (_) {}

  // Server verify (may override localStorage if role changed)
  async function checkAdminStatus() {
    try {
      const { data: { user } } = await window.supabase.auth.getUser();
      if (!user) { window.adminResolve(); return; }
      const { data: profile } = await window.supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
      if (profile?.role === 'admin') {
        showAdminUI();
      } else {
        hideAdminUI();
      }
    } catch (_) {
      // Server query failed — keep the localStorage-based state
    }
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
    const saved = localStorage.getItem('rr_runner_name');
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
    if (displayName && saved) displayName.textContent = saved;
  })();

  // ─── Logout handler ───
  const logoutBtn = document.getElementById('navLogout');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async e => {
      e.preventDefault();
      await window.supabase.auth.signOut();
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

  // Make filter controls work on the events page
  window.applyEventFilters = function (filters) {
    filters = filters || {};
    var filtered = _allEvents.slice();
    var sort = filters.sort || 'upcoming';
    var year = filters.year || '';
    var search = (filters.search || '').toLowerCase();
    var searchType = filters.searchType || 'event';

    // Search filter
    if (search) {
      filtered = filtered.filter(function (ev) {
        if (searchType === 'event') {
          return (ev.title || '').toLowerCase().indexOf(search) !== -1 ||
                 (ev.location || '').toLowerCase().indexOf(search) !== -1 ||
                 (ev.category || '').toLowerCase().indexOf(search) !== -1;
        }
        // athlete search - search by organizer_name
        return (ev.organizer_name || '').toLowerCase().indexOf(search) !== -1;
      });
    }

    // Year filter
    if (year) {
      filtered = filtered.filter(function (ev) {
        return ev.start_date && ev.start_date.indexOf(year) === 0;
      });
    }

    // Sort
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
    }
    // 'recommended' - keep original order (by creation date)

    if (container) renderEventCards(container, filtered);
  };

  function renderEventCards(target, events) {
    if (!events || events.length === 0) { target.innerHTML = '<p style="color:var(--gray)">No events match your filters.</p>'; return; }
    const imgs = [
      'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1461896836934-bd45ba8fcf9b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1579126038374-6064e9370f0f?w=400&h=300&fit=crop'
    ];
    target.innerHTML = events.map(function (ev) {
      const img = ev.banner_url || imgs[ev.id % imgs.length];
      let dateDisplay = ev.start_date || '';
      if (ev.start_time) dateDisplay += ' \u00b7 ' + ev.start_time;
      return '<div class="race-card" style="position:relative;cursor:pointer;" data-href="event_detail.html?id=' + ev.id + '">' +
        '<button class="admin-only admin-delete-btn" data-id="' + ev.id + '" style="display:none;position:absolute;top:8px;right:8px;z-index:2;background:var(--accent-red);color:white;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;align-items:center;justify-content:center;font-size:14px;line-height:1;">&times;</button>' +
        '<div class="race-card-img-wrap"><img src="' + img + '" alt="' + ev.title + '" class="race-card-img"></div>' +
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
        var href = this.dataset.href;
        if (href) window.location.href = href;
      });
    });
    if (window.currentUserRole === 'admin') {
      document.querySelectorAll('.admin-only').forEach(function (el) { el.style.display = 'block'; });
    }
    // Admin delete handlers
    document.querySelectorAll('.admin-delete-btn').forEach(function (btn) {
      btn.addEventListener('click', async function (e) {
        e.stopPropagation();
        if (!confirm('Delete this event permanently?')) return;
        var { error } = await window.supabase.from('events').delete().eq('id', this.dataset.id);
        if (error) { alert('Delete failed: ' + error.message); return; }
        this.closest('.race-card').remove();
      });
    });
  }

  // Initial event data load
  if (container || indexGrid) {
    (async function () {
      await window.adminPromise;
      var { data: events, error } = await window.supabase.from('events').select('*').order('created_at', { ascending: false });
      if (!error && events) _allEvents = events;
      if (container) renderEventCards(container, _allEvents);
      if (indexGrid) {
        indexGrid.innerHTML = _allEvents.slice(0, 3).map(function (ev) {
          var img = (ev.banner_url || 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop');
          var dateDisplay = ev.start_date || '';
          if (ev.start_time) dateDisplay += ' \u00b7 ' + ev.start_time;
          return '<div class="event-card" style="position:relative;cursor:pointer;" data-href="event_detail.html?id=' + ev.id + '">' +
            '<button class="admin-only admin-delete-btn" data-id="' + ev.id + '" style="display:none;position:absolute;top:8px;right:8px;z-index:2;background:var(--accent-red);color:white;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;align-items:center;justify-content:center;font-size:14px;line-height:1;">&times;</button>' +
            '<img src="' + img + '" alt="" class="event-card-img">' +
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
            var href = this.dataset.href;
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
      if (error || !events || events.length === 0) return;

      const imgs = [
        'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1461896836934-bd45ba8fcf9b?w=600&h=600&fit=crop',
        'https://images.unsplash.com/photo-1576678927484-cc907957088c?w=600&h=600&fit=crop'
      ];

      track.innerHTML = events.map(ev => {
        const img = ev.banner_url || imgs[ev.id % imgs.length];
        const cat = ev.category || 'Race';
        let dateDisplay = ev.start_date || '';
        if (ev.start_time) dateDisplay += ' · ' + ev.start_time;
        return '<div class="carousel-card" data-href="event_detail.html?id=' + ev.id + '" style="cursor:pointer;">' +
          '<div class="carousel-card-link">' +
            '<div class="carousel-card-img" style="background-image:url(\'' + img + '\');">' +
              '<span class="carousel-badge">' + cat + '</span>' +
              '<div class="carousel-card-footer">' +
                '<p class="carousel-date">' + dateDisplay + '</p>' +
                '<p class="carousel-title">' + ev.title + '</p>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
      }).join('');
      // Make carousel cards clickable
      track.querySelectorAll('.carousel-card').forEach(card => {
        card.addEventListener('click', () => {
          const href = card.dataset.href;
          if (href) window.location.href = href;
        });
      });
    } catch (_) {}
  }

});
