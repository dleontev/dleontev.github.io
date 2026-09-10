# Dimitriy Leontev's website

Static Jekyll portfolio at https://dleontev.com.

## Preview and validate

Use Ruby 3.3 or 3.4, Bundler 2.6.3, and Node.js 22.

```sh
bundle install
bundle exec jekyll build
bundle exec ruby scripts/validate.rb
npm ci
npx playwright install chromium
npm test
npm run preview
```

Open http://127.0.0.1:4000. Rebuild after editing source files and reload the preview. The preview server supports existing slashless article URLs. Generated content lives in _site/.

The validation workflow checks builds, links, anchors, metadata, search JSON, certification consistency, mobile overflow, keyboard behavior, search states, and accessibility in light/dark mode. Run checks before merging.

## Deployment

GitHub Pages continues to publish the default branch. The separate validation workflow checks pushes and pull requests; it does not deploy or change Pages settings. A passing Pages build alone does not guarantee working links or responsive layout.

## Content

- Home: pages/index.md renders _includes/bio.md.
- About: pages/about.md.
- Posts: _posts/YYYY-MM-DD-slug.md. Include title, description, and a tags array. The layout supplies h1/date/tags; use h2 for major sections.
- Projects: _projects/. Use name, description, status, tools, and permalink. Status is separate from technologies. Only add article when material is available.
- Navigation: _data/navigation.yml.
- Long posts use Kramdown's {:toc} inside article-toc navigation.
- Generate internal links with {% post_url YYYY-MM-DD-slug %} and {% link path/to/page.md %}.

Article URLs intentionally have no trailing slash. Page and project permalinks retain existing conventions. Preserve published URLs or supply redirects. The accidental /pages/bio route redirects to Home and is excluded from indexing.

## Certifications and GitHub profile

_data/certifications.yml is the website's source of truth: title, issuer, group, image, width, height, verification_url. Both Home and About display the same records.

```sh
bundle exec ruby scripts/profile-certifications.rb
```

Copy the generated section into the separate dleontev/dleontev profile README in a reviewed update. This script only prints Markdown; it does not publish or require credentials.

Four existing Microsoft credential URLs contain a valueless sharingId parameter. Existing issuer targets were preserved rather than guessed. Confirm replacement links through the issuer if verification stops working.

## Images and naming

Use lowercase kebab-case without download counters in canonical names. Include intrinsic dimensions and meaningful alt text, or empty alt for a decorative badge beside its visible label.

Canonical badges are optimized to 240px or smaller and displayed around 100–112px. _data/asset-aliases.yml maps old filenames retained for external consumers. Do not remove legacy files without checking consumers.

Article originals retain their URLs. _data/images.yml maps them to WebP derivatives and smaller responsive sources. The figure include reserves layout space and defaults to lazy loading; use loading="eager" for the lead image.

## Theme and dependencies

portfolYOU is pinned to 7a3e795d385e2dcd5bcd284f4862e1314efd1336. Local _includes/, _layouts/, _sass/portfolYOU.scss and assets/css/style.scss override inherited rendering.

Only Bootstrap 4.6.2 CSS is vendored in assets/lib/, with its MIT license. Menu, theme and search behavior use local JavaScript. jQuery, Popper, WOW.js, GitHub Buttons, Font Awesome and the external search runtime are not loaded. Poppins uses Google Fonts with swap behavior.

Update dependencies in a dedicated change and rerun validation. Commit Gemfile.lock and package-lock.json. No account tokens are needed for ordinary content updates.

## Attribution

Based on [portfolYOU](https://github.com/yousinix/portfolYOU) by Yousinix, under the MIT License. Bootstrap's license is in assets/lib/bootstrap-LICENSE.txt.
