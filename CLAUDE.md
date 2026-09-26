# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Blog built on Rails 8.1 / Ruby 4.0: SQLite, Hotwire via importmap (no Node), Slim views, Propshaft with Tailwind v4 + Dart Sass. Article content is **not in this repo** — it lives in a gitignored `content/` directory managed in a separate repository, and the database only indexes it.

## Commands

```bash
bin/setup                 # bundle install, db:prepare, clear logs/tmp, then exec bin/dev (--skip-server to stop there, --reset to also db:reset)
bin/dev                   # foreman (Procfile.dev): rails server + tailwindcss:watch + dartsass:watch
bin/rails contents:sync   # import content/ into the DB (also: contents:sync_articles, contents:sync_gallery)
bin/rails test            # whole suite; one file/test: bin/rails test test/models/article_test.rb[:LINE]
bin/rubocop               # Ruby lint, see Conventions (-a to autocorrect)
bin/slim-lint             # Slim template lint (all of app/views unless files are given)
bin/ci                    # local CI: runs the steps in config/ci.rb (setup, rubocop, slim-lint, audits, brakeman, tests)
```

- `bin/dev` is tailwindcss-rails' template: it defaults `PORT` to 3000 (foreman alone would pick 5000) and sets `RUBY_DEBUG_OPEN`, so attach to `debugger` breakpoints with `rdbg --attach`. Installers such as `dartsass:install` overwrite it with a version that drops both.
- Compiled CSS goes to the gitignored `app/assets/builds/`; without the watchers running, use `bin/rails tailwindcss:build dartsass:build`.
- Image variants require **libvips** (Rails' default variant processor; the Dockerfile and the CI test job install it), and so does the watermark test in `test/models/picture_test.rb`, which errors with `LoadError` without it. macOS: `brew install vips`. image_processing 2.x no longer pulls in `ruby-vips`, so the Gemfile lists it explicitly with `require: false` — that keeps Rails bootable on machines without libvips.
- CI (`.github/workflows/ci.yml`) runs `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/rubocop -f github`, `bin/slim-lint`, and `bin/rails db:test:prepare test`, with system tests in a separate job.

## Architecture

### Content lives outside the repo

Articles, the about page, and all images come from `content/` — `Rails.configuration.x.content_root`, set in `config/application.rb` and pointed at `test/fixtures/files/content` in tests; those pages fail without it:

```
content/
  articles/<filename>.md            # YAML front matter: title, date (both required), tags (list)
  articles/images/*.{jpg,jpeg,png}  # → Picture, artwork: false; articles embed them as ![alt](images/<file>)
  gallery/*.{jpg,jpeg,png}          # → Picture, artwork: true; /gallery lists them by filename, descending
  static_pages/about.md             # rendered at /about
  overlay.png                       # watermark composited onto every Picture variant
```

- **Sync (write path):** `ContentSync` (`app/models/content_sync.rb`; the `contents:*` rake tasks only call it) mirrors `content/` into the DB — `Article` keyed by `filename` (basename without `.md`) with `title` and `published_on` (the `date` key) from front matter, tags via `ArticleToTagRelation` → `ArticleTag`, and every image attached to a `Picture` through Active Storage. Re-run it after adding, removing, or renaming files or changing front matter; it's cheap to repeat:
  - Rows whose files are gone are deleted (articles before they're upserted, so a renamed article keeps its title), along with tags no article uses.
  - An invalid article (say, no `date`) raises `ContentSync::InvalidArticle` naming its file, and the whole article part rolls back. Error messages call `published_on` "Date" (`config/locales/en.yml`) to match the key.
  - An image whose file checksum matches its blob's (Base64 MD5) is skipped; re-attaching would upload a new blob and regenerate every preprocessed variant.
  - `Picture` is keyed by filename alone, so image filenames must be unique across `articles/images` and `gallery`.
  - It raises `ContentSync::MissingCheckout` when the root has no `articles/` directory, so a missing checkout (e.g. an unmounted volume) can't delete every row.
- **Render (read path):** `ArticlesController#show` finds the `Article` by filename, and `Article#body` reads `content/articles/<filename>.md` from disk on every request. The DB holds only metadata, so body edits need no resync. `Article` validates that `filename` contains no path separators, since it becomes part of that path. Lists use `Article.newest_first`.
- **Parsing vs. rendering:** `MarkdownDocument` splits the optional YAML front matter from the body (`YAML.safe_load` permitting only `Date` and `Time`, so no symbols or other objects) for both paths; views call `markdown(body)` from `MarkdownHelper` (Redcarpet with `filter_html: true` — raw HTML in Markdown is stripped, which is what makes marking the output `html_safe` safe). Its `Renderer` turns an `images/<file>` image into the Picture's watermarked `:article` variant, and never links the original, which has no watermark; any other image keeps its src.
- **Gallery:** `/gallery` (`ArtworksController#index`) shows each `Picture.artworks` as its `:gallery_thumb` variant, linking to the larger `:gallery` variant. Filenames sort descending, so date-prefixed or camera-numbered names come out newest first.
- Routes use natural keys, not ids: `/articles/:filename`, `/article_tags/:name` (`param:` in `config/routes.rb`). Lookups use `find_by!` with `params.expect`, so unknown keys are 404s. An article deleted from `content/` but not yet synced still has its row, and its page is a 500 (`Errno::ENOENT`) until the next sync.

### Pictures

`Picture` declares named variants: the article ones are `preprocessed: true` and the gallery ones `preprocessed: :artwork?`, so attaching enqueues an `ActiveStorage::TransformJob` per preprocessed variant. Every variant composites `content/overlay.png` at the south-east corner, and two details of that config are load-bearing:

- `OVERLAY` is a String because the transformations become Active Job arguments, and Active Job can't serialize a Pathname (attaching raised `ActiveJob::SerializationError`).
- `composite:` is an Array, `[ path, { gravity: } ]`. A Hash would be splatted into keyword arguments, but image_processing's `composite` takes the overlay positionally (`ArgumentError`).

Active Storage uses the Disk service in dev and prod (`storage/`).

Only variants can be fetched; originals can't be at all. An original has no watermark and keeps all its EXIF (GPS position included), and Active Storage's blob routes would serve it to anyone with the signed blob ID from any of its variant URLs. So `config.active_storage.draw_routes` is off, and `config/routes.rb` draws only what variants need: the representation routes (redirect and proxy), the Disk service's GET route, and the URL helpers `url_for(variant)` goes through, all copied from activestorage's `config/routes.rb`, so check them against it after a Rails upgrade. That leaves out direct uploads, which would let anyone store files, and `url_for` of an attachment or blob raises.

### Views and CSS

- Views are Slim (`.html.slim`), not ERB; the dev group has `html2slim`/`erb2slim` for conversions (from the upstream GitHub repo — the RubyGems releases depend on hpricot, which no longer compiles).
- The layout's `stylesheet_link_tag :app` links every built stylesheet under `app/assets`:
  - `app/assets/tailwind/application.css` → `builds/tailwind.css` (Tailwind v4, configured in CSS; no JS config)
  - `app/assets/stylesheets/application.scss` → `builds/application.css` (Dart Sass)
  - `app/assets/stylesheets/application.css` is **shadowed**: it shares the logical path `application.css` with the Sass output, and Propshaft resolves `app/assets/builds/` first, so edits to it never ship. Put custom styles in `application.scss`.
- The design is one text-first column (`max-w-2xl`): a header with `site_name` (`config.x.site_name`, still the placeholder "Blog") and `layouts/_navigation`, whose `nav_link_to` marks the current section with `aria-current`, then the page and a footer. UI text is English, while `<html lang="ja">` is for the article text.
- Markdown bodies get Tailwind's typography plugin (`prose`), loaded with `@plugin "@tailwindcss/typography"`; the standalone Tailwind CLI bundles it, so there's no Node dependency. Overrides of its defaults go in `application.scss`, like inline code's light background in place of the plugin's backticks.
- Code blocks are highlighted server-side: `MarkdownHelper::Renderer` includes `Rouge::Plugins::Redcarpet`, which renders `<pre class="highlight <language>">` (plain text when there's no language and the code doesn't name one, e.g. by a shebang). `app/assets/stylesheets/_syntax.scss`, `@use`d by `application.scss`, is Rouge's GitHub light theme generated with `rougify` (the command is in its header) and scoped to `.prose .highlight`; being unlayered, it overrides the typography plugin's dark `<pre>`.
- Slim's `.class` shortcuts can't hold `:` or `[ ]`, so Tailwind variant classes (`sm:…`, `aria-[…]:…`) go in a `class="…"` attribute.
- **Page titles and link previews:** a view provides `:title` (the `<title>` becomes "Title | Blog"), `:description`, `:og_type` (default "website"), and `:og_image` (an absolute URL), and `layouts/_link_preview` turns them into description, Open Graph, and Twitter card tags. An article describes itself with `Article#summary` (`MarkdownDocument#plain_text`, truncated) and previews `Article#cover_picture`, the first `images/<file>` it embeds.
- The gallery uses CSS columns instead of a cropped square grid, so artworks keep their proportions and their watermarked corner.

### Infrastructure

Rails 8 "Solid" defaults: SQLite everywhere (`storage/*.sqlite3`); production adds separate SQLite databases for Solid Cache/Queue/Cable. `config/deploy.yml` (Kamal) is still the generator template with placeholder host/registry, and it enables Kamal's SSL proxy, which requires `config.assume_ssl`/`config.force_ssl` in `production.rb`.

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
- **Tests:** Minitest with fixtures. `test/fixtures/files/content` mirrors `content/`, and the DB fixtures must match it (every fixture article has a Markdown file there). A bug fix comes with a test that fails without it.
- **Commits:** short, lowercase, imperative subject (`fix div typos in slim views`), with a body saying why when it isn't obvious.

## Known state (update as it changes)

- Unused: `PictureTag` (a model and table with no associations yet).
