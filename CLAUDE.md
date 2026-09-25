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
bin/rubocop               # rubocop-rails-omakase (-a to autocorrect)
bin/ci                    # local CI: runs the steps in config/ci.rb (setup, rubocop, audits, brakeman, tests)
```

- `bin/dev` is tailwindcss-rails' template: it defaults `PORT` to 3000 (foreman alone would pick 5000) and sets `RUBY_DEBUG_OPEN`, so attach to `debugger` breakpoints with `rdbg --attach`. Installers such as `dartsass:install` overwrite it with a version that drops both.
- Compiled CSS goes to the gitignored `app/assets/builds/`; without the watchers running, use `bin/rails tailwindcss:build dartsass:build`.
- Image variants require **libvips** (Rails' default variant processor; the Dockerfile installs it). macOS: `brew install vips`. image_processing 2.x no longer pulls in `ruby-vips`, so the Gemfile lists it explicitly with `require: false` — that keeps Rails bootable on machines without libvips.
- CI (`.github/workflows/ci.yml`) runs `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/rubocop -f github`, and `bin/rails db:test:prepare test`, with system tests in a separate job.

## Architecture

### Content lives outside the repo

Articles, the about page, and all images come from `content/`; those pages fail without it:

```
content/
  articles/<filename>.md            # YAML front matter: title, tags (list)
  articles/images/*.{jpg,jpeg,png}  # → Picture, artwork: false
  gallery/*.{jpg,jpeg,png}          # → Picture, artwork: true
  static_pages/about.md             # rendered at /about
  overlay.png                       # watermark composited onto every Picture variant
```

- **Sync (write path):** `lib/tasks/contents.rake` upserts DB rows from `content/` — `Article` keyed by `filename` (basename without `.md`) with `title` from front matter, tags via `ArticleToTagRelation` → `ArticleTag`, and every image attached to a `Picture` through Active Storage. It never deletes rows for removed files. Re-run after adding files or changing a title/tags.
- **Render (read path):** `ArticlesController#show` finds the `Article` by filename, then reads `content/articles/<filename>.md` from disk on every request. The DB holds only metadata, so body edits need no resync.
- **`MarkdownHelper` is shared by both paths:** the rake file `include`s it at top level for `read_yaml_frontmatter`; views call `markdown` (Redcarpet, `filter_html: true` — raw HTML in Markdown is stripped). `markdown` raises `TypeError` on text without a `---` front matter block, so every rendered file, including `about.md`, needs front matter.
- Routes use natural keys, not ids: `/articles/:filename`, `/article_tags/:name` (`param:` in `config/routes.rb`). Lookups use `find_by`, so unknown keys produce a 500 rather than a 404.

### Pictures

`Picture` declares named variants with `preprocessed: true` (Active Storage enqueues transform jobs on attach); every variant composites `content/overlay.png` at the south-east corner. Active Storage uses the Disk service in dev and prod (`storage/`).

### Views and CSS

- Views are Slim (`.html.slim`), not ERB; the dev group has `html2slim`/`erb2slim` for conversions (from the upstream GitHub repo — the RubyGems releases depend on hpricot, which no longer compiles).
- The layout's `stylesheet_link_tag :app` links every built stylesheet under `app/assets`:
  - `app/assets/tailwind/application.css` → `builds/tailwind.css` (Tailwind v4, configured in CSS; no JS config)
  - `app/assets/stylesheets/application.scss` → `builds/application.css` (Dart Sass)
  - `app/assets/stylesheets/application.css` is **shadowed**: it shares the logical path `application.css` with the Sass output, and Propshaft resolves `app/assets/builds/` first, so edits to it never ship. Put custom styles in `application.scss`.

### Infrastructure

Rails 8 "Solid" defaults: SQLite everywhere (`storage/*.sqlite3`); production adds separate SQLite databases for Solid Cache/Queue/Cable. `config/deploy.yml` (Kamal) is still the generator template with placeholder host/registry, and it enables Kamal's SSL proxy, which requires `config.assume_ssl`/`config.force_ssl` in `production.rb`.

After `bin/rails app:update` (Rails upgrades), review the diff before keeping it: it comments out `assume_ssl`/`force_ssl` and drops the Solid Cache/Queue lines from `production.rb`, replaces the foreman-based `bin/dev` with a plain `rails server`, and copies Active Storage upgrade migrations that are no-ops for this schema.

## Known state (update as it changes)

- **Tests are untouched generator scaffolding and fail:** fixtures reference a nonexistent `content_path` column and repeat values that violate unique indexes; controller tests call route helpers (`articles_index_url`, `static_pages_about_url`, …) that the current `resources` routes don't define. Treat these failures as pre-existing.
- `bin/rubocop` reports pre-existing offenses, mostly omakase's required spaces inside array brackets (`[ :index, :show ]`).
- `bin/brakeman` exits non-zero on a pre-existing weak warning (model attribute used in a file name: `File.read` with `@article.filename` in `ArticlesController`), so the CI `scan_ruby` job fails until it's fixed or ignored.
- `with_options if: :artwork?` in `Picture` has no effect: the block calls the outer `attachable` directly and named variants accept no `if:`, so every picture also defines and preprocesses the gallery variants. `preprocessed: :artwork?` is the supported way to make preprocessing conditional.
- Unused/WIP: `AttachImageJob` (the rake task attaches inline instead), `PictureTag` (no associations), `ImagesController` (redirects `/image` to the first `Picture`).
