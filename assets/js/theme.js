(() => {
  const root = document.documentElement;
  const preference = window.matchMedia('(prefers-color-scheme: dark)');
  let explicit = null;
  try { explicit = localStorage.getItem('theme'); } catch (_) { /* Storage may be unavailable. */ }
  if (!['dark', 'light'].includes(explicit)) explicit = null;
  const apply = theme => {
    root.setAttribute('data-theme', theme);
    const button = document.getElementById('theme-toggle');
    if (button) button.setAttribute('aria-pressed', String(theme === 'dark'));
  };
  apply(explicit || (preference.matches ? 'dark' : 'light'));
  preference.addEventListener('change', event => {
    if (!explicit) apply(event.matches ? 'dark' : 'light');
  });
  document.addEventListener('DOMContentLoaded', () => {
    const button = document.getElementById('theme-toggle');
    if (!button) return;
    button.hidden = false;
    apply(root.getAttribute('data-theme'));
    button.addEventListener('click', () => {
      explicit = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      apply(explicit);
      try { localStorage.setItem('theme', explicit); } catch (_) { /* Switching still works. */ }
    });
  });
})();
