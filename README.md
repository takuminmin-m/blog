# Blog

A personal blog on Rails 8.1 and Ruby 4.0. Articles, the about page, and images live in a separate content repository: this app indexes them into SQLite, renders the Markdown, and serves the images only as watermarked copies stripped of their metadata. The originals can't be downloaded.

## Requirements

- Ruby 4.0.7 (see `.ruby-version`)
- [libvips](https://www.libvips.org/) for image variants, which some tests also need. On macOS: `brew install vips`

## Setup

```sh
bin/setup --skip-server        # gems and databases
git clone <content repository> content
bin/rails contents:sync        # index the content into the database
bin/dev                        # http://localhost:3000
```

`content/` is gitignored; a symlink to an existing checkout works too.

## Writing content

```
content/
  articles/<name>.md       # served at /articles/<name>
  articles/images/         # images embedded in articles
  gallery/                 # images shown at /gallery
  static_pages/index.md    # introduction at the top of the home page (optional)
  static_pages/about.md    # served at /about
  overlay.png              # watermark added to every image
```

Every article starts with front matter:

```markdown
---
title: Hello, world
date: 2026-09-26
tags:
  - ruby
---
The body is Markdown. Embed an image from articles/images like this:

![A photo](images/photo.jpg)
```

Fenced code blocks that name their language (```` ```ruby ````) are syntax-highlighted.

The gallery shows 24 photos a page, newest first. Clicking one enlarges it in place, where the ‹ › buttons, the arrow keys, or a swipe move to the previous or next photo, on into the neighboring pages. Its Info toggle lists what each photo's EXIF records: when it was taken, the camera and lens, focal length, aperture, shutter speed, and ISO. EXIF is read from JPEGs only, and nothing else in it, such as the location, is shown.

Run `bin/rails contents:sync` after adding, removing, or renaming files or changing front matter. Edits to a body show up without it. Image filenames must be unique across `articles/images` and `gallery`, and a sync stops at an article without a title or date, naming the file.

## Development

- `bin/ci` runs what GitHub CI runs: RuboCop, slim-lint, the importmap audit, Brakeman, and the tests, including the system tests in headless Chrome.
- [CLAUDE.md](CLAUDE.md) describes the architecture and the coding conventions.

## Deployment

Not set up yet.
