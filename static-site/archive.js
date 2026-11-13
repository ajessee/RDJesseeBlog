const searchInput = document.querySelector('[data-story-search]');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const navHeader = document.querySelector('.archive-header');
const setHeaderHeight = () => {
  if (navHeader) document.documentElement.style.setProperty('--archive-header-height', `${navHeader.offsetHeight}px`);
};
setHeaderHeight();
if (navHeader && 'ResizeObserver' in window) new ResizeObserver(setHeaderHeight).observe(navHeader);

const heroText = document.querySelector('[data-hero-typing]');
if (heroText && !reducedMotion) {
  const text = heroText.dataset.text || heroText.textContent;
  heroText.textContent = '';
  let index = 0;
  const typeNext = () => {
    heroText.textContent = text.slice(0, index);
    index += 1;
    if (index <= text.length) window.setTimeout(typeNext, 34);
  };
  typeNext();
}

const counters = [...document.querySelectorAll('[data-count]')];
if (counters.length && !reducedMotion && 'IntersectionObserver' in window) {
  const countObserver = new IntersectionObserver((entries, observer) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      const counter = entry.target;
      const target = Number.parseInt(counter.dataset.count, 10);
      const start = performance.now();
      const duration = 750;
      const tick = (now) => {
        const progress = Math.min((now - start) / duration, 1);
        counter.textContent = String(Math.round(target * (1 - (1 - progress) ** 3)));
        if (progress < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
      observer.unobserve(counter);
    }
  }, { threshold: 0.3 });
  counters.forEach((counter) => countObserver.observe(counter));
}

const randomHero = document.querySelector('[data-random-quote]');
const revealHeroDetails = () => document.querySelectorAll('[data-hero-reveal]').forEach((element) => element.classList.add('is-visible'));
if (randomHero) {
  document.querySelectorAll('[data-hero-reveal]').forEach((element) => element.classList.remove('is-visible'));
  const showQuote = (quote) => {
    const { text, pauseAfter, pauseMs } = quote;
    if (reducedMotion) { randomHero.textContent = text; revealHeroDetails(); return; }
    randomHero.textContent = ''; let i = 0;
    const type = () => {
      randomHero.textContent = text.slice(0, i++);
      if (i <= text.length) {
        // Match Typed.js in the original site: randomized 0–70 ms plus typeSpeed 0.10.
        const typeSpeed = 0.10;
        const delay = pauseAfter === i ? pauseMs : Math.round(Math.random() * (100 - 30)) + typeSpeed;
        window.setTimeout(type, delay);
      } else revealHeroDetails();
    };
    type();
  };
  fetch('/home-quotes.json').then((r) => r.json()).then((quotes) => {
    if (!quotes.length) throw new Error('No homepage excerpts');
    showQuote(quotes[Math.floor(Math.random() * quotes.length)]);
  }).catch(() => showQuote({ text: 'Remembering Ralph “Don” Jessee' }));
}

if (navHeader?.closest('body.archive-home-page')) {
  const hero = document.querySelector('.archive-home-hero');
  if (hero) {
    const updateHomeNavigation = () => navHeader.classList.toggle('is-visible', window.scrollY >= hero.offsetHeight);
    window.addEventListener('scroll', updateHomeNavigation, { passive: true });
    window.addEventListener('resize', () => { setHeaderHeight(); updateHomeNavigation(); }, { passive: true });
    updateHomeNavigation();
  }
}

for (const list of document.querySelectorAll('[data-random-list]')) {
  const items = [...list.querySelectorAll(':scope > [data-random-item]')];
  const limit = Number.parseInt(list.dataset.randomList, 10) || 3;
  const shuffled = window.StaticArchiveRandom.shuffle(items);
  const selected = new Set(shuffled.slice(0, limit));
  for (const item of shuffled) {
    item.hidden = !selected.has(item);
    list.append(item);
  }
}

const obituary = document.querySelector('[data-obit-carousel]');
if (obituary) {
  const slides = [...obituary.querySelectorAll('.item')];
  if (slides.length > 1) {
    let active = 0;
    const reserveTallestSlide = () => {
      let tallest = 0;
      for (const slide of slides) {
        const wasHidden = slide.hidden;
        slide.hidden = false;
        tallest = Math.max(tallest, slide.getBoundingClientRect().height);
        slide.hidden = wasHidden;
      }
      obituary.style.minHeight = `${Math.ceil(tallest)}px`;
    };
    const controls = document.createElement('div');
    controls.className = 'obit-carousel-controls';
    controls.setAttribute('aria-label', 'Obituary slides');
    controls.innerHTML = '<button type="button" data-obit-prev aria-label="Previous slide">‹ Previous</button><span data-obit-status aria-live="polite"></span><button type="button" data-obit-next aria-label="Next slide">Next ›</button>';
    obituary.after(controls);
    const showSlide = (index) => {
      active = (index + slides.length) % slides.length;
      slides.forEach((slide, i) => { slide.hidden = i !== active; slide.setAttribute('aria-hidden', String(i !== active)); });
      controls.querySelector('[data-obit-status]').textContent = `${active + 1} / ${slides.length}`;
    };
    controls.querySelector('[data-obit-prev]').addEventListener('click', () => showSlide(active - 1));
    controls.querySelector('[data-obit-next]').addEventListener('click', () => showSlide(active + 1));
    obituary.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowLeft') showSlide(active - 1);
      if (event.key === 'ArrowRight') showSlide(active + 1);
    });
    obituary.tabIndex = 0;
    showSlide(0);
    reserveTallestSlide();
    window.addEventListener('resize', reserveTallestSlide, { passive: true });
    obituary.querySelectorAll('img').forEach((image) => {
      if (!image.complete) image.addEventListener('load', reserveTallestSlide, { once: true });
    });
    if (document.fonts?.ready) document.fonts.ready.then(reserveTallestSlide);
  }
}

if (searchInput) {
  const stories = [...document.querySelectorAll('[data-story]')];
  const emptyState = document.querySelector('[data-search-empty]');
  const count = document.querySelector('[data-search-count]');
  const parameters = new URLSearchParams(window.location.search);
  const query = (parameters.get('query') || '').replace(/^['"]|['"]$/g, '').trim().toLowerCase();
  const legacySort = parameters.get('sort');
  const legacyKey = {year_written:'year',decade:'decade',location:'location',genre:'genre',category:'category',life_stage:'lifeStage',tag:'tag'};
  searchInput.value = query;
  for (const filter of document.querySelectorAll('[data-filter]')) {
    const key = filter.dataset.filter;
    let value = parameters.get(key) || (legacySort === 'has_'+key ? 'true' : legacySort === key || (legacyKey[legacySort] === key) ? parameters.get(key === 'year' ? 'year' : legacySort) : '');
    if (filter.type === 'checkbox') filter.checked = value === 'true'; else filter.value = value || '';
  }
  const applyFilters = () => {
    const term = searchInput.value.trim().toLowerCase(); let visibleCount = 0;
    const filters = [...document.querySelectorAll('[data-filter]')].map((filter) => ({
      key: filter.dataset.filter,
      value: filter.type === 'checkbox' ? (filter.checked ? 'true' : '') : filter.value
    }));
    for (const card of stories) {
      const visible = window.StaticArchiveFilters.matchesStory(card.dataset, term, filters);
      card.hidden = !visible; if (visible) visibleCount++;
    }
    if (count) count.textContent = `${visibleCount} ${visibleCount === 1 ? 'story' : 'stories'}`;
    if (emptyState) emptyState.hidden = visibleCount !== 0;
  };
  searchInput.addEventListener('input', applyFilters);
  document.querySelectorAll('[data-filter]').forEach((filter) => filter.addEventListener('change', applyFilters));
  document.querySelector('[data-clear-filters]')?.addEventListener('click', () => {
    searchInput.value = '';
    for (const filter of document.querySelectorAll('[data-filter]')) {
      if (filter.type === 'checkbox') filter.checked = false;
      else filter.value = '';
    }
    window.history.replaceState(null, '', window.location.pathname);
    applyFilters();
    searchInput.focus();
  });
  applyFilters();
}
