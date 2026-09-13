# Dimitriy Leontev's website

Static Jekyll portfolio at https://dleontev.com.

## Preview and validate

Use Ruby 3.3 or 3.4, Bundler 2.6.3, and Node.js 22.

```sh
bundle install
bundle exec jekyll build
bundle exec ruby scripts/validate.rb
npm ci
npx playwright install chromium webkit
npm test
npm run preview
```

Open http://127.0.0.1:4000. Rebuild after source edits and reload the preview. The preview server preserves published slashless article URLs. Generated content lives in `_site/`. The validator also builds `.validation/manifest.json` from page front matter and shared data; browser tests consume these expectations.

## Deployment and failure handling

GitHub Pages uses **GitHub Actions** as its publishing source. `.github/workflows/validate.yml` builds once, checks content and browser behavior, and packages that exact `_site` directory only after successful tests. Its deployment job requires the validation job and runs only for main, never for pull requests or feature branches. No deployment job rebuilds the artifact.

Review a change on a branch before merging. Main deployments are serialized; obsolete feature-branch validation runs are cancelled. Failure screenshots, traces, the HTML report, and candidate visual baselines are retained for seven days in `browser-diagnostics`. A failing test prevents the tested-site upload and deployment. To recover from a bad published change, revert it through a reviewed commit and let the same checks run.

The workflow uses pinned actions and locked Ruby/npm dependencies. Dependabot proposes monthly dependency updates; review and validate them before merging. No user tokens belong in content or workflow files.

## Content and metadata

- Home: `pages/index.md` renders `_includes/bio.md`.
- About: `pages/about.md`.
- Skills: `_data/skills.yml`; each category has the existing homepage wording and, when applicable, its longer About wording. `_includes/skills.html` renders semantic rows on both pages.
- Posts: `_posts/YYYY-MM-DD-slug.md`. Supply `title`, `description`, and a `tags` array. The layout supplies h1/date/tags; use h2 for major sections.
- Projects: `_projects/`. Supply `title`, `order`, `description`, `status`, `tools`, and `permalink`. Set `article` to a post's filename without `.md` when material is available. Current and planned work are grouped separately, and available articles receive direct links.
- Navigation: `_data/navigation.yml`. Home uses an exact URL match; section ancestry is visually marked separately from `aria-current="page"`.
- Every content page has an explicit title. Project sorting prefixes must never become browser or social-preview titles.
- Generate internal links with Jekyll `post_url` and `link` tags. Preserve published permalinks or provide redirects.

Article URLs intentionally have no trailing slash. Other existing routes retain their conventions. `/pages/bio` redirects to Home and is excluded from indexing.

## Article navigation and search

Use Kramdown's `{:toc}` inside the native `details.article-toc` pattern in existing posts. It works without JavaScript; JavaScript opens it by default on desktop and collapses it on mobile. Heading links move keyboard focus to the destination. Keep the Back to top and All articles links in the post layout.

Related reading takes up to three posts: explicit `related_posts` Jekyll IDs first, then shared tags, then recent posts. The current article is excluded and duplicate entries are removed.

Blog search shows a distinct results section and preserves the All articles archive. Results use text nodes for safe rendering. Search has clear, no-match, failure, retry, and eight-second timeout states. Malformed indexes also keep browsing available.

## Certifications and GitHub profile

`_data/certifications.yml` is the website's source of truth: `title`, `issuer`, `group`, `image`, `width`, `height`, and `verification_url`. Both Home and About render these records, and validation compares both link sets directly with the YAML.

```sh
bundle exec ruby scripts/profile-certifications.rb
```

Copy the generated section into the separate `dleontev/dleontev` profile README in a reviewed update. This script only prints Markdown; it does not publish. Preserve issuer verification links; do not invent replacements for existing valueless sharingId parameters.

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
