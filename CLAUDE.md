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
  articles/<filename>.md            # YAML front matter: title, tags (list)
  articles/images/*.{jpg,jpeg,png}  # → Picture, artwork: false
  gallery/*.{jpg,jpeg,png}          # → Picture, artwork: true
  static_pages/about.md             # rendered at /about
  overlay.png                       # watermark composited onto every Picture variant
```

- **Sync (write path):** `ContentSync` (`app/models/content_sync.rb`; the `contents:*` rake tasks only call it) upserts DB rows from `content/` — `Article` keyed by `filename` (basename without `.md`) with `title` from front matter, tags via `ArticleToTagRelation` → `ArticleTag`, and every image attached to a `Picture` through Active Storage. It never deletes rows for removed files. Re-run after adding files or changing a title/tags.
- **Render (read path):** `ArticlesController#show` finds the `Article` by filename, and `Article#body` reads `content/articles/<filename>.md` from disk on every request. The DB holds only metadata, so body edits need no resync. `Article` validates that `filename` contains no path separators, since it becomes part of that path.
- **Parsing vs. rendering:** `MarkdownDocument` splits the optional YAML front matter from the body (`YAML.safe_load`, so no dates or symbols in front matter) for both paths; views call `markdown(body)` from `MarkdownHelper` (Redcarpet with `filter_html: true` — raw HTML in Markdown is stripped, which is what makes marking the output `html_safe` safe).
- Routes use natural keys, not ids: `/articles/:filename`, `/article_tags/:name` (`param:` in `config/routes.rb`). Lookups use `find_by`, so unknown keys produce a 500 rather than a 404.

### Pictures

`Picture` declares named variants: the article ones are `preprocessed: true` and the gallery ones `preprocessed: :artwork?`, so attaching enqueues an `ActiveStorage::TransformJob` per preprocessed variant. Every variant composites `content/overlay.png` at the south-east corner, and two details of that config are load-bearing:

- `OVERLAY` is a String because the transformations become Active Job arguments, and Active Job can't serialize a Pathname (attaching raised `ActiveJob::SerializationError`).
- `composite:` is an Array, `[ path, { gravity: } ]`. A Hash would be splatted into keyword arguments, but image_processing's `composite` takes the overlay positionally (`ArgumentError`).

Active Storage uses the Disk service in dev and prod (`storage/`).

### Views and CSS

- Views are Slim (`.html.slim`), not ERB; the dev group has `html2slim`/`erb2slim` for conversions (from the upstream GitHub repo — the RubyGems releases depend on hpricot, which no longer compiles).
- The layout's `stylesheet_link_tag :app` links every built stylesheet under `app/assets`:
  - `app/assets/tailwind/application.css` → `builds/tailwind.css` (Tailwind v4, configured in CSS; no JS config)
  - `app/assets/stylesheets/application.scss` → `builds/application.css` (Dart Sass)
  - `app/assets/stylesheets/application.css` is **shadowed**: it shares the logical path `application.css` with the Sass output, and Propshaft resolves `app/assets/builds/` first, so edits to it never ship. Put custom styles in `application.scss`.

### Infrastructure

Rails 8 "Solid" defaults: SQLite everywhere (`storage/*.sqlite3`); production adds separate SQLite databases for Solid Cache/Queue/Cable. `config/deploy.yml` (Kamal) is still the generator template with placeholder host/registry, and it enables Kamal's SSL proxy, which requires `config.assume_ssl`/`config.force_ssl` in `production.rb`.

After `bin/rails app:update` (Rails upgrades), review the diff before keeping it: it comments out `assume_ssl`/`force_ssl` and drops the Solid Cache/Queue lines from `production.rb`, replaces the foreman-based `bin/dev` with a plain `rails server`, and copies Active Storage upgrade migrations that are no-ops for this schema.

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

- `ContentSync` re-attaches every image on each run, so every sync uploads new blobs and regenerates every preprocessed variant.
- Unused/WIP: `AttachImageJob` (superseded by `ContentSync`), `PictureTag` (no associations), `ImagesController` (redirects `/image` to the first `Picture`; untested, and it raises `ArgumentError` because `image.url` on the Disk service needs `ActiveStorage::Current.url_options`, which only Active Storage's own controllers set).
