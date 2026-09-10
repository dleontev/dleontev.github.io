(() => {
  const search = document.querySelector('[data-search-url]');
  if (!search) return;
  const input = document.getElementById('search-input');
  const results = document.getElementById('results-container');
  const status = document.getElementById('search-status');
  let posts = [];
  const render = () => {
    results.replaceChildren();
    const query = input.value.trim().toLocaleLowerCase();
    if (!query) { status.textContent = ''; return; }
    const matches = posts.filter(post => `${post.title} ${post.tags.join(' ')} ${post.description}`.toLocaleLowerCase().includes(query));
    status.textContent = matches.length ? `${matches.length} matching article${matches.length === 1 ? '' : 's'}.` : 'No matching articles. Try another title or topic.';
    matches.forEach(post => {
      const destination = new URL(post.url, location.href);
      if (!['https:', 'http:'].includes(destination.protocol)) return;
      const item = document.createElement('li');
      const link = document.createElement('a');
      link.href = destination.href;
      link.textContent = post.title;
      item.append(link); results.append(item);
    });
  };
  input.addEventListener('input', render);
  status.textContent = 'Loading search…';
  fetch(search.dataset.searchUrl).then(response => {
    if (!response.ok) throw new Error('Search index unavailable');
    return response.json();
  }).then(data => {
    posts = data; input.disabled = false; status.textContent = ''; render();
  }).catch(() => { status.textContent = 'Search is unavailable. Browse the articles below or use the tags page.'; });
})();
