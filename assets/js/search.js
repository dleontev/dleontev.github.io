(() => {
  const search = document.querySelector('[data-search-url]');
  if (!search) return;
  const input = document.getElementById('search-input');
  const results = document.getElementById('results-container');
  const region = document.getElementById('search-results');
  const status = document.getElementById('search-status');
  const clear = document.getElementById('clear-search');
  const retry = document.getElementById('retry-search');
  let posts = [];
  const render = () => {
    results.replaceChildren();
    const query = input.value.trim().toLocaleLowerCase();
    region.hidden = !query; clear.hidden = !input.value;
    if (!query) { status.textContent = ''; return; }
    const matches = posts.filter(post => `${post.title} ${post.tags.join(' ')} ${post.description}`.toLocaleLowerCase().includes(query));
    status.textContent = matches.length ? `${matches.length} matching article${matches.length === 1 ? '' : 's'}.` : 'No matching articles. Try another title or topic, or browse all articles below.';
    matches.forEach(post => {
      const item = document.createElement('li');
      const link = document.createElement('a'); link.href = post.url; link.textContent = post.title;
      const excerpt = document.createElement('p'); excerpt.textContent = post.description;
      item.append(link, excerpt); results.append(item);
    });
  };
  const load = async () => {
    input.disabled = true; retry.hidden = true; status.textContent = 'Loading search…';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(search.dataset.searchUrl, {signal: controller.signal});
      if (!response.ok) throw new Error('Unavailable index');
      const data = await response.json();
      if (!Array.isArray(data)) throw new Error('Invalid index');
      posts = data.map(post => {
        if (typeof post.title !== 'string' || typeof post.description !== 'string' || !Array.isArray(post.tags) || !post.tags.every(tag => typeof tag === 'string')) throw new Error('Invalid article');
        const url = new URL(post.url, location.href);
        if (!['https:', 'http:'].includes(url.protocol)) throw new Error('Invalid link');
        return {...post, url: url.href};
      });
      input.disabled = false; render();
    } catch {
      region.hidden = true; retry.hidden = false;
      status.textContent = 'Search is unavailable. Browse all articles below or use the tags page.';
    } finally { clearTimeout(timeout); }
  };
  input.addEventListener('input', render);
  clear.addEventListener('click', () => { input.value = ''; render(); input.focus(); });
  retry.addEventListener('click', load);
  load();
})();
