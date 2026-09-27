# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Blog built on Rails 8.1 / Ruby 4.0: SQLite, Hotwire via importmap (no Node), Slim views, Propshaft with Tailwind v4 + Dart Sass. Article content is **not in this repo** — it lives in a gitignored `content/` directory managed in a separate repository, and the database only indexes it.

## Commands

```bash
bin/setup                 # bundle install, db:prepare, clear logs/tmp, then exec bin/dev (--skip-server to stop there, --reset to also db:reset)
bin/dev                   # foreman (Procfile.dev): rails server + tailwindcss:watch + dartsass:watch
bin/rails contents:sync   # import content/ into the DB (also: contents:sync_articles, contents:sync_gallery)
bin/rails contents:date_gallery  # rename undated gallery images to <shooting date>-<name>, from EXIF (run where the originals are)
bin/rails test            # whole suite; one file/test: bin/rails test test/models/article_test.rb[:LINE]
bin/rails test:system     # system tests (test/system) in headless Chrome, which bin/rails test leaves out
bin/rubocop               # Ruby lint, see Conventions (-a to autocorrect)
bin/slim-lint             # Slim template lint (all of app/views unless files are given)
bin/ci                    # local CI: runs the steps in config/ci.rb (setup, rubocop, slim-lint, audits, brakeman, tests, system tests)
```

- `bin/dev` is tailwindcss-rails' template: it defaults `PORT` to 3000 (foreman alone would pick 5000) and sets `RUBY_DEBUG_OPEN`, so attach to `debugger` breakpoints with `rdbg --attach`. Installers such as `dartsass:install` overwrite it with a version that drops both.
- Compiled CSS goes to the gitignored `app/assets/builds/`; without the watchers running, use `bin/rails tailwindcss:build dartsass:build`.
- Image variants require **libvips** (Rails' default variant processor; the Dockerfile and the CI test jobs install it), and so do the watermark test in `test/models/picture_test.rb`, which errors with `LoadError` without it, and the system tests, whose pages load variants. macOS: `brew install vips`. image_processing 2.x no longer pulls in `ruby-vips`, so the Gemfile lists it explicitly with `require: false` — that keeps Rails bootable on machines without libvips. EXIF is read by the pure-Ruby exifr, which doesn't need it.
- CI (`.github/workflows/ci.yml`) runs `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/rubocop -f github`, `bin/slim-lint`, and `bin/rails db:test:prepare test`, with system tests in a separate job.

## Architecture

### Content lives outside the repo

Articles, the about page, and all images come from `content/` — `Rails.configuration.x.content_root`, set in `config/application.rb` and pointed at `test/fixtures/files/content` in tests; those pages fail without it:

```
content/
  articles/<filename>.md            # YAML front matter: title, date (both required), tags (list)
  articles/images/*.{jpg,jpeg,png}  # → Picture, artwork: false; articles embed them as ![alt](images/<file>)
  gallery/*.{jpg,jpeg,png}          # → Picture, artwork: true; /gallery lists them by filename, descending
  static_pages/index.md             # optional introduction at the top of the home page
  static_pages/about.md             # rendered at /about
  overlay.png                       # watermark composited onto every Picture variant
```

- **Sync (write path):** `ContentSync` (`app/models/content_sync.rb`; the `contents:*` rake tasks only call it) mirrors `content/` into the DB — `Article` keyed by `filename` (basename without `.md`) with `title` and `published_on` (the `date` key) from front matter, tags via `ArticleToTagRelation` → `ArticleTag`, and every image attached to a `Picture` through Active Storage, with the shooting details from its EXIF. Re-run it after adding, removing, or renaming files or changing front matter; it's cheap to repeat:
  - Rows whose files are gone are deleted (articles before they're upserted, so a renamed article keeps its title), along with tags no article uses.
  - An invalid article (say, no `date`) raises `ContentSync::InvalidArticle` naming its file, and the whole article part rolls back. Error messages call `published_on` "Date" (`config/locales/en.yml`) to match the key.
  - An image whose file checksum matches its blob's (Base64 MD5) isn't attached again; re-attaching would upload a new blob and regenerate every preprocessed variant.
  - `Exif` (`app/models/exif.rb`) reads a JPEG's EXIF into `Picture#taken_at`, `camera`, `lens`, `focal_length` (mm), `f_number`, `exposure_time` (seconds), and `iso`, and nothing else, so GPS positions and serial numbers never reach the DB. It's read on every sync, unchanged images included, so pictures synced before a detail existed get it. A broken JPEG is logged and gets no details rather than stopping the sync.
  - `Picture` is keyed by filename alone, so image filenames must be unique across `articles/images` and `gallery`. Gallery URLs leave out the extension, so artworks also need names unique without it (of `a.jpg` and `a.png`, `/gallery/a` shows one).
  - It raises `ContentSync::MissingCheckout` when the root has no `articles/` directory, so a missing checkout (e.g. an unmounted volume) can't delete every row.
  - Images are listed by `ContentSync.images`, which drops duplicates: on macOS's case-insensitive file system the `IMAGES` pattern matches each file once per spelling of its extension.
- **Dating gallery images:** the gallery's naming is `<YYYY-MM-DD>-<name>` by shooting date, so it sorts newest first. `GalleryDating` (`contents:date_gallery`) renames gallery images without that prefix by their EXIF `taken_at` (camera numbers such as `P1200205.jpeg` keep a day in order), skipping ones with no date or whose new name exists. It renames files, so it's for the Mac holding the originals, before syncing and copying them; `ContentSync` never renames, since the server's checkout is read-only and a renamed copy would diverge from its original.
- **Render (read path):** `ArticlesController#show` finds the `Article` by filename, and `Article#body` reads `content/articles/<filename>.md` from disk on every request. The DB holds only metadata, so body edits need no resync. `Article` validates that `filename` contains no path separators, since it becomes part of that path. Lists use `Article.newest_first`.
- **Parsing vs. rendering:** `MarkdownDocument` splits the optional YAML front matter from the body (`YAML.safe_load` permitting only `Date` and `Time`, so no symbols or other objects) for both paths; views call `markdown(body)` from `MarkdownHelper` (Redcarpet with `filter_html: true` — raw HTML in Markdown is stripped, which is what makes marking the output `html_safe` safe). Its `Renderer` turns an `images/<file>` image into the Picture's watermarked `:article` variant, and never links the original, which has no watermark; any other image keeps its src.
- **Home page:** `StaticPagesController#index` shows `static_pages/index.md` as an introduction (and the page's description), leaving it out when the file is missing, then the 10 newest articles and the newest `RECENT_ARTWORKS` (4) artworks as `:gallery_thumb` variants linking to `/gallery`.
- **Gallery:** `/gallery` (`ArtworksController#index`) shows `Picture.artworks` `PER_PAGE` (24) to a page, each as its `:gallery_thumb` variant (`artworks/_artwork`), which opens the lightbox (`artworks/_lightbox`, `lightbox_controller.js`) at that photo. Filenames sort descending (`Picture.newest_first`), so date-prefixed or camera-numbered names come out newest first.
  - The lightbox is one modal `<dialog>` with a slide per artwork on the page, showing the larger `:gallery` variant, in a strip that scroll-snaps: swipes and trackpads move between photos natively, the ‹ › buttons and arrow keys scroll the strip, and its `scroll` event keeps the counter and buttons in step. Info shows each photo's EXIF (`ArtworksHelper#exif_details`) under it.
  - Links to the neighboring pages end the strip. Going past a page's first or last photo, by button, key, or swipe, visits that page with `#lightbox-last` or `#lightbox-first`, and the controller's `connect` reopens the lightbox there (not on Turbo's cached preview), so browsing runs across pages; the counter numbers photos across them.
  - Escape and the Close button close the dialog natively, and closing focuses the thumbnail of the photo last shown. Without JavaScript or in a new tab the thumbnail links to the artwork's page (below), and it has Turbo's hover prefetch off, since a click opens the lightbox. The dialog closes on `turbo:before-cache`, because Turbo's snapshot of an open modal comes back as a non-modal dialog stuck open.
  - While it's open, the address bar shows the photo's page (`history.replaceState`, keeping Turbo's `history.state`), so a copied or reloaded URL is the photo's. The gallery page's URL comes back on closing and on `turbo:before-visit`, before Turbo pushes the next page, so going back returns to the gallery rather than a photo's page. Share uses the Web Share API's sheet where there is one, and copies the link otherwise.
- **Artwork pages (for sharing):** `/gallery/:name` (`ArtworksController#show`) names an artwork by its filename without the extension (`artwork_title`; `Picture.named` looks it up by `ContentSync::EXTENSIONS`), which may hold dots (the route's constraint). It shows the `:gallery` variant and its EXIF, previews that variant as `:og_image` with `ArtworksHelper#exif_summary` as the description, and links back to the index page it's on, at its thumbnail (`dom_id`).
- **Pagination:** `Pagination` (`app/models/pagination.rb`) is one page of a relation, numbered from 1 by `?page=`. A number outside `1..pages`, or not a number, raises `ActiveRecord::RecordNotFound` (a 404). `application/_pagination` links the other pages ("‹ Newer 1 … 4 5 6 … 12 Older ›"), and `pagination_path` leaves `?page=` off the first.
- Routes use natural keys, not ids: `/articles/:filename`, `/article_tags/:name`, `/gallery/:name` (`param:` in `config/routes.rb`). Lookups use `find_by!` with `params.expect`, so unknown keys are 404s. An article deleted from `content/` but not yet synced still has its row, and its page is a 500 (`Errno::ENOENT`) until the next sync.

### Pictures

`Picture` declares named variants: the article ones are `preprocessed: true` and the gallery ones `preprocessed: :artwork?`, so attaching enqueues an `ActiveStorage::TransformJob` per preprocessed variant. Every variant composites `content/overlay.png` at the south-east corner, and three details of that config are load-bearing:

- `OVERLAY` is `Watermark.path` (`app/models/watermark.rb`), a copy of the watermark in `tmp/watermarks/` named by its digest, not the content path. A variant's URL comes from its transformations, so the digest gives variants new URLs when the watermark changes; with the content path they'd keep theirs, and Cloudflare, which keeps variants forever, would go on serving the old watermark. It's read when `Picture` loads, so a new watermark takes an app restart.
- `OVERLAY` is a String because the transformations become Active Job arguments, and Active Job can't serialize a Pathname (attaching raised `ActiveJob::SerializationError`).
- `composite:` is an Array, `[ path, { gravity: } ]`. A Hash would be splatted into keyword arguments, but image_processing's `composite` takes the overlay positionally (`ArgumentError`).

`taken_at` is the camera's clock time, and EXIF often has no time zone for it: `Exif` labels it UTC and `Picture` skips time zone conversion for the attribute, so show it as stored (`strftime`), never converted to `Time.zone`.

Active Storage uses the Disk service in dev and prod (`storage/`). Pages link variants by proxy (`config.active_storage.resolve_model_to_route = :rails_storage_proxy`): the response is `Cache-Control: max-age=3155695200, public, immutable` without a cookie, which Cloudflare caches at its edge, and a variant's URL changes with its image, so nothing goes stale. Redirecting instead would hand out the Disk service's URL, which expires in minutes and can't be cached.

Only variants can be fetched; originals can't be at all. An original has no watermark and keeps all its EXIF (GPS position included), and Active Storage's blob routes would serve it to anyone with the signed blob ID from any of its variant URLs. So `config.active_storage.draw_routes` is off, and `config/routes.rb` draws only what variants need: the representation routes (redirect and proxy), the Disk service's GET route, and the URL helpers `url_for(variant)` goes through, all copied from activestorage's `config/routes.rb`, so check them against it after a Rails upgrade. That leaves out direct uploads, which would let anyone store files, and `url_for` of an attachment or blob raises.

### Views and CSS

- Views are Slim (`.html.slim`), not ERB; the dev group has `html2slim`/`erb2slim` for conversions (from the upstream GitHub repo — the RubyGems releases depend on hpricot, which no longer compiles).
- The layout's `stylesheet_link_tag :app` links every built stylesheet under `app/assets`:
  - `app/assets/tailwind/application.css` → `builds/tailwind.css` (Tailwind v4, configured in CSS; no JS config)
  - `app/assets/stylesheets/application.scss` → `builds/application.css` (Dart Sass)
  - `app/assets/stylesheets/application.css` is **shadowed**: it shares the logical path `application.css` with the Sass output, and Propshaft resolves `app/assets/builds/` first, so edits to it never ship. Put custom styles in `application.scss`.
- The design is one text-first column (`max-w-2xl`): a header with `site_name` (`config.x.site_name`, "takuminmin-m", which the footer's copyright line also uses) and `layouts/_navigation`, whose `nav_link_to` marks the current section with `aria-current`, then the page and a footer. UI text is English, while `<html lang="ja">` is for the article text.
- Markdown bodies get Tailwind's typography plugin (`prose`), loaded with `@plugin "@tailwindcss/typography"`; the standalone Tailwind CLI bundles it, so there's no Node dependency. Overrides of its defaults go in `application.scss`, like inline code's light background in place of the plugin's backticks.
- Code blocks are highlighted server-side: `MarkdownHelper::Renderer` includes `Rouge::Plugins::Redcarpet`, which renders `<pre class="highlight <language>">` (plain text when there's no language and the code doesn't name one, e.g. by a shebang). `app/assets/stylesheets/_syntax.scss`, `@use`d by `application.scss`, is Rouge's GitHub light theme generated with `rougify` (the command is in its header) and scoped to `.prose .highlight`; being unlayered, it overrides the typography plugin's dark `<pre>`.
- Slim's `.class` shortcuts can't hold `:` or `[ ]`, so Tailwind variant classes (`sm:…`, `aria-[…]:…`) go in a `class="…"` attribute.
- **Page titles and link previews:** a view provides `:title` (the `<title>` becomes "Title | takuminmin-m"), `:description`, `:og_type` (default "website"), and `:og_image` (an absolute URL), and `layouts/_link_preview` turns them into description, Open Graph, and Twitter card tags. An article describes itself with `Article#summary` (`MarkdownDocument#plain_text`, truncated) and previews `Article#cover_picture`, the first `images/<file>` it embeds.
- The gallery uses CSS columns instead of a cropped square grid, so artworks keep their proportions and their watermarked corner. Its lightbox covers the viewport, and `application.scss` keeps the page behind any modal `<dialog>` from scrolling.

### Infrastructure

Rails 8 "Solid" defaults: SQLite everywhere (`storage/*.sqlite3`); production adds separate SQLite databases for Solid Cache/Queue/Cable.

Production is a Raspberry Pi 3B+ (1 GB, SD card) behind a Cloudflare Tunnel; `deploy/README.md` is the runbook, and there's no Kamal:

- `.github/workflows/image.yml` builds the arm64 image on an arm runner once CI passes on a push to main (`workflow_run`, or by hand) and pushes `ghcr.io/takuminmin-m/blog:latest`. It skips while the repository is private, since the Pi pulls without credentials.
- On the Pi, `deploy/compose.yaml` runs the image and cloudflared, with `<root>/content` mounted read-only at `/rails/content` and `<root>/storage` at `/rails/storage`. `deploy/.env` (gitignored) holds `RAILS_MASTER_KEY`, `APP_HOST`, and `TUNNEL_TOKEN`.
- `blog-update.timer` (installed by `deploy/bin/install`) runs `deploy/bin/update` every 5 minutes: it pulls both repositories and the image, and runs `contents:sync` when the content commit, the image, or the photo listing changed. It refuses to sync while there are no photos, since a fresh content clone has none and syncing would prune every Picture. The Mac sends the photos with `deploy/bin/push-photos <ssh host>`, which dates the gallery first.
- Memory is tight, so Solid Queue runs inside Puma in async mode (`config/puma.rb`, when `SOLID_QUEUE_IN_PUMA`), with one job thread (`JOB_THREADS`) and `VIPS_CONCURRENCY=1`.
- TLS ends at Cloudflare; `config.assume_ssl`/`config.force_ssl` stay on. `config.hosts` comes from `APP_HOST` (any host when unset), with `/up` excluded for Docker's health check.

After `bin/rails app:update` (Rails upgrades), review the diff before keeping it: it comments out `assume_ssl`/`force_ssl` and drops the Solid Cache/Queue lines from `production.rb`, replaces the foreman-based `bin/dev` with a plain `rails server`, copies Active Storage upgrade migrations that are no-ops for this schema, and offers a fresh `config/application.rb` without this app's settings (without `draw_routes = false`, routes fail to load with "Invalid route name, already in use").

## Conventions

Checked by `bin/ci` and GitHub CI; run `bin/ci` before pushing.

- **Ruby:** `bin/rubocop` — rubocop-rails-omakase plus the Lint, Rails, and Security departments, which catch bugs and Rails pitfalls rather than style (`.rubocop.yml`). `NewCops: enable`, so RuboCop upgrades can add offenses. Fix offenses rather than disabling cops; when disabling is right, scope it to the line and say why: `# rubocop:disable Cop/Name -- reason`.
- **Templates:** `bin/slim-lint` — slim-lint's defaults plus double-quoted attributes and no instance variables in partials (`.slim-lint.yml`); Ruby inside templates is checked against `.rubocop.yml`. Write `.foo`, not `div.foo`, and comment with `/`, not `- #`.
- **Security:** `bin/brakeman` must report no warnings. Fix the cause; record a genuine false positive with `bin/brakeman -I` (`config/brakeman.ignore`) and a note.
- **Whitespace:** `.editorconfig` — UTF-8, LF, two-space indentation, final newline.

Not checked by tools:

- **Where code goes:** domain logic lives in models, plain Ruby objects included (`ContentSync` and `MarkdownDocument` in `app/models`; there is no `app/services`). Controllers look up records for the view; rake tasks only call model code, so the logic stays testable.
- **Content paths:** build them from `Rails.configuration.x.content_root`, never `Rails.root.join("content")`, so tests read the fixture copy.
- **Private methods** are indented one level under `private`, as in Rails itself.
- **Tests:** Minitest with fixtures. `test/fixtures/files/content` mirrors `content/`, and the DB fixtures must match it (every fixture article has a Markdown file there). Its `gallery/sunset.jpg` carries camera EXIF, written with libvips (set `exif-ifd*` string fields on an image, then save it as a JPEG). A bug fix comes with a test that fails without it.
- **Commits:** short, lowercase, imperative subject (`fix div typos in slim views`), with a body saying why when it isn't obvious.

## Known state (update as it changes)

- Unused: `PictureTag` (a model and table with no associations yet).
