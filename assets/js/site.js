(() => {
  const toggle = document.querySelector('.menu-toggle');
  const menu = document.getElementById('site-menu');
  const mobile = window.matchMedia('(max-width: 767px)');
  if (toggle && menu) {
    const setOpen = open => {
      toggle.setAttribute('aria-expanded', String(open));
      menu.hidden = mobile.matches && !open;
    };
    const sync = () => { toggle.hidden = !mobile.matches; setOpen(false); };
    toggle.addEventListener('click', () => setOpen(toggle.getAttribute('aria-expanded') !== 'true'));
    menu.addEventListener('keydown', event => {
      if (event.key === 'Escape' && mobile.matches) { setOpen(false); toggle.focus(); }
    });
    mobile.addEventListener('change', sync);
    sync();
  }
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', () => {
      const target = document.getElementById(decodeURIComponent(link.hash.slice(1)));
      if (target && target.matches('h2, h3')) { target.tabIndex = -1; target.focus({preventScroll: true}); }
    });
  });
})();
