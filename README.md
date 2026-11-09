# Dimitriy Leontev's website

Static Jekyll 4 portfolio at https://dleontev.com. The Gemfile selects Jekyll 4.4 and explicitly declares the plugins and validation libraries; Gemfile.lock fixes the resolved versions for Windows and Linux.

## Preview and validate

Use Ruby 3.3 or 3.4, Bundler 2.6.3, and Node.js 22. Windows Ruby installations need the matching RubyInstaller Devkit for native gems.
The offline Entra helper check runs in PowerShell 7 in CI. You can also run that script in Windows PowerShell 5.1.

```sh
bundle install
pwsh -NoProfile -File ./scripts/test-entra-sign-in-triage.ps1
bundle exec ruby scripts/test-build.rb
bundle exec jekyll build
bundle exec ruby scripts/validate.rb
npm ci
npx playwright install chromium webkit
npm test
npm run preview
```

Open http://127.0.0.1:4000. Rebuild after source edits and reload the preview. The preview server preserves published slashless article URLs. Generated content lives in `_site/`. The build writes `.validation/manifest.json` through `_plugins/validation-manifest.rb` after the rendered files have been written. It records Jekyll's resolved HTML pages, output collections, URLs, output paths, merged metadata, redirects, and shared data; the content validator and browser tests consume this inventory. It is excluded from publication and invalidated at the start of each rebuild. Rebuild before running validation; the validator does not reconstruct routes from filenames.

## Deployment and failure handling

GitHub Pages uses **GitHub Actions** as its publishing source. `.github/workflows/validate.yml` builds once, checks content and browser behavior, and packages that exact `_site` directory only after successful tests. Its deployment job requires the validation job and runs only for main, never for pull requests or feature branches. No deployment job rebuilds the artifact.

Pull requests validate once per update. Push validation runs only on `main`, and manual runs remain available. Review a change in a pull request before merging. Main deployments are serialized; obsolete pull-request validation runs are cancelled. Failure screenshots, traces, the HTML report, and candidate visual baselines are retained for seven days in `browser-diagnostics`. A failing test prevents the tested-site upload and deployment. To recover from a bad published change, revert it through a reviewed commit and let the same checks run.

The build uses standalone Jekyll rather than the `github-pages` dependency bundle. `_config.yml` explicitly preserves GFM Markdown, Rouge highlighting, compressed CSS without source maps, and the previous inclusion of future-dated posts. Use `published: false` or `_drafts/` for unpublished work. The site uses local layouts and no packaged theme. `jekyll-github-metadata` supplies the build revision used by asset URLs; `jekyll-feed`, `jemoji`, `jekyll-default-layout`, and `jekyll-optional-front-matter` are the other active plugins. Sitemap and structured data remain local templates.

Malformed front matter, invalid Liquid syntax, and unknown filters fail the build. `strict_variables` remains disabled because optional metadata is intentional. `scripts/test-build.rb` exercises the real Jekyll build with nested content, custom post routes/slugs, metadata defaults, output filtering, redirects, and invalid content. The inventory comes from resolved source metadata; title, canonical, structured-data, feed, and link assertions still independently inspect the rendered output.

The workflow uses pinned actions and locked Ruby/npm dependencies. Dependabot proposes monthly dependency updates; review and validate them before merging. No user tokens belong in content or workflow files.

## Content and metadata

- Home: `pages/index.md` renders `_includes/bio.md`.
- About: `pages/about.md`.
- Skills: `_data/skills.yml`; each category has the existing homepage wording and, when applicable, its longer About wording. `_includes/skills.html` renders semantic rows on both pages.
- Posts: `_posts/YYYY-MM-DD-slug.md`. Supply `title`, `description`, and a `tags` array. The layout supplies h1/date/tags; use h2 for major sections.
- Projects: `_projects/`. Supply `title`, `order`, `description`, `status`, `tools`, and `permalink`. The index groups `Deployed`, `Published`, `In progress`, and `Planned` projects by status and lists selected published guides separately. Set `article` to the article's canonical site-relative URL (for example, `/blog/entra-sign-in-troubleshooting-framework`) to link a project to its supporting material.
- Navigation: `_data/navigation.yml`. Home uses an exact URL match; section ancestry is visually marked separately from `aria-current="page"`.
- Every content page has an explicit title. Project sorting prefixes must never become browser or social-preview titles.
- Generate internal links with Jekyll `post_url` and `link` tags. Preserve published permalinks or provide redirects.

Article URLs intentionally have no trailing slash. Other existing routes retain their conventions. `/pages/bio` redirects to Home and is excluded from indexing and the sitemap. Its JavaScript redirect preserves URL fragments; an immediate meta refresh in a head `noscript` fallback handles browsers with scripting disabled. The visible destination link remains available if automatic navigation is suppressed. GitHub Pages does not provide configurable HTTP redirects for individual paths.

## Structured identity data

`_includes/structured-data.html` emits one JSON-LD graph on indexable HTML pages. The stable `/#person` identity connects the website publisher, article author, project creator, and About profile. Name, current employment title, image, and professional profile handles come from `_config.yml`. Keep the employment title consistent with the visible biography when changing the portfolio headline. About declares `schema_type: ProfilePage` in front matter.

Home and About include skills and credentials from the same YAML records used for their visible content. Credential URLs link to the existing issuer verification pages. Articles use their publication dates; projects retain their actual status as `CreativeWork` records. Do not infer employment history, credential validity dates, completed software, or modification dates from a build. The 404 and legacy redirect pages intentionally omit structured data.

Articles display a byline linked to About, using the same author name as the shared Person record. All dynamic values are JSON-encoded, and literal less-than signs are escaped before embedding the graph in HTML. `scripts/validate.rb` checks the generated relationships and their agreement with visible content, including the byline, as part of normal validation.

## Sitemap and crawler policy

`sitemap.xml` is generated by a local Liquid template from HTML pages and output collections. It uses canonical URLs and excludes `sitemap: false`, `noindex`, and redirect pages. The 404 page, legacy biography redirect, search JSON, and discovery files are explicitly excluded. No sitemap plugin is required.

Only an explicit, accurate `last_modified_at` front-matter value produces a sitemap modification date. Do not use a build date or assume a post's original publication date is its latest update. In particular, Jekyll gives undated collection documents a build-time date; the template deliberately ignores that value.

`robots.txt` allows all crawlers, including search, assistant retrieval, and training crawlers, and advertises `https://dleontev.com/sitemap.xml`. Utility pages remain crawlable so their `noindex` directives can be read. There are no AI-specific restrictions. Revisit the owner's policy before introducing any, since training and discovery controls differ by provider.

The normal content validator checks strict sitemap XML, unique canonical URLs, exact coverage of indexable HTML, exclusions, declared modification dates, and the agreed robots policy. The local preview serves XML and plain text with their correct content types.

After publication, check that the public sitemap and robots file return HTTP 200. In the verified `dleontev.com` property in Google Search Console and Bing Webmaster Tools, submit the sitemap and inspect Home, About, the Projects index, a project, and a recent article. Review indexing/canonical results and Bing AI Performance where available. Local preview URLs cannot be submitted; account verification and live deployment must come first.

## Article navigation and search

`jekyll-feed` generates `/feed.xml` as an Atom feed of the ten most recent published articles, including full content, summaries, canonical article links, and the shared author name. `{% feed_meta %}` adds feed discovery in the shared head, and the footer exposes a Subscribe link. The feed remains outside the HTML sitemap. Content validation checks strict Atom XML, article coverage and order, author identity, and discovery/Subscribe links.

Use Kramdown's `{:toc}` inside the native `details.article-toc` pattern in existing posts. It works without JavaScript; JavaScript opens it by default on desktop and collapses it on mobile. Heading links move keyboard focus to the destination. Keep the Back to top and All articles links in the post layout.

Related reading takes up to three posts: explicit `related_posts` first, then shared tags, then recent posts. The current article is excluded and duplicate entries are removed. Use canonical site-relative URLs for `article`, `related_posts` (an array), and `related_project`, preserving each published URL's trailing-slash convention. The validator rejects unresolved references.

Templates use Jekyll 4's native `find` filter for single-document URL lookups. No compatibility filter or custom plugin loader is required.

Blog search shows a distinct results section and preserves the All articles archive. Results use text nodes for safe rendering. Search has clear, no-match, failure, retry, and eight-second timeout states. Malformed indexes also keep browsing available.

## Certifications and GitHub profile

`_data/certifications.yml` is the website's source of truth: `title`, `issuer`, `group`, `image`, `width`, `height`, and `verification_url`. Both Home and About render these records, and validation compares both link sets directly with the YAML.

```sh
bundle exec ruby scripts/profile-certifications.rb
```

Copy the generated section into the separate `dleontev/dleontev` profile README in a reviewed update. This script only prints Markdown; it does not publish. Use verified public credential destinations: Microsoft Learn links follow `https://learn.microsoft.com/en-us/users/dimitriyleontev/credentials/<credential-id>` with lowercase paths and no query string; Credly links follow `https://www.credly.com/badges/<badge-id>` with no sharing suffix. Confirm issuer redirects and the recipient before replacing a badge ID; do not guess credential identifiers or sharing values.

## Styling, fonts, and images

The site uses local templates and a small stylesheet in `assets/css/style.scss`. It no longer imports Bootstrap or remote theme CSS. Heading sizes h1–h6, component rules, focus styles, and light/dark colors are defined together. The typography uses Poppins; four Latin WOFF2 weights are self-hosted with their license in `assets/fonts/`. Other glyphs use the system fallback. Regular text is preloaded and all fonts use swap behavior.

Home keeps a slightly wider layout than article text. Skill descriptions may wrap and stack below labels on mobile; never force entire rows not to wrap or shrink body text to fit them.

The theme button describes the next action and does not use `aria-pressed`. System color preference is the default; a manual light/dark selection persists. CSS/scripts use the build revision to invalidate changed assets; stable font filenames are reused across content-only deployments. Rename font assets and update references when replacing their bytes.

Canonical asset filenames use lowercase kebab-case. Images need intrinsic dimensions and meaningful alt text, or empty alt for decorative badges beside visible titles. Article WebP derivatives and responsive sources are mapped in `_data/images.yml`. Figures default to lazy loading; use eager loading for the lead figure. Original article images and legacy badge aliases remain available for existing consumers. They are not automatically loaded on every page.

## Browser and visual checks

The suite covers all published pages at 320, 390, 768, and 1280px; light/dark axe checks; explicit metadata; heading hierarchy; Home and active navigation; keyboard and persisted theme behavior; search states; source certification links; skill preservation; project article links; TOC focus; redirects; and content without JavaScript. A WebKit smoke test covers the core mobile interactions.

Seven screenshots cover Home and a representative article at 390, 768, and 1280px, plus dark Home. Baselines live in `tests/visual-baselines/`. They are created and compared with Chromium on Ubuntu 24.04 and the locked Playwright version. Review any intended visual change before replacing a baseline. Font, browser, or runner updates can require reviewed baseline updates too.

To generate candidate baselines in that Linux environment:

```sh
npm test -- --project=chromium --grep 'visual layout' --update-snapshots
```

Inspect every candidate before committing it. Do not make the normal validation workflow automatically accept new screenshots. A missing baseline intentionally fails validation and retains the generated image for review.

## Attribution

The site began with portfolYOU by Yousinix. Its MIT license is retained in `assets/lib/portfolYOU-LICENSE.txt`. Bootstrap 4.6.2 and its MIT license remain at their legacy URLs for compatibility, but are no longer loaded by the site. Poppins is distributed under the SIL Open Font License in `assets/fonts/OFL.txt`.
