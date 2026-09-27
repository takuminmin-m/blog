# Deploying to the Raspberry Pi

The production setup (the site runs on the Pi 3B+ behind a Cloudflare Tunnel):

- On every push to main that passes CI, GitHub Actions builds the arm64 image and pushes it to `ghcr.io/takuminmin-m/blog:latest` (`.github/workflows/image.yml`).
- On the Pi, `blog-update.timer` runs `deploy/bin/update` every 5 minutes: it pulls this repository, the content repository, and the image, then runs `contents:sync` when the content or the image changed.
- Photos aren't in the content repository. Send them from the Mac with `deploy/bin/push-photos`.
- The Pi opens no ports. cloudflared connects to Cloudflare, and TLS ends at Cloudflare.

## Directory layout on the Pi

```
/srv/blog/          # <root>. Any other directory works too
  app/              # this repository (deploy/.env lives only here)
  content/          # the content repository plus the photos sent from the Mac
  storage/          # SQLite and the Active Storage files. The only thing to back up
```

## Prerequisites

- Cloudflare: register the domain, then create a tunnel and give it a Public Hostname of `<domain>` → `HTTP` / `app:80`. Note down the tunnel's token.
- GitHub: make both repositories public. Once the first image is built, make the `blog` package public too (profile → Packages → blog → Package settings → Change visibility).
- Pi: 64-bit Raspberry Pi OS Lite, reachable over SSH from the Mac, with Docker installed:

  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER   # takes effect once you log in again
  ```

## First-time setup (on the Pi, as the first user, uid 1000)

```bash
sudo install -d -o $USER -g $USER /srv/blog
git clone https://github.com/takuminmin-m/blog.git /srv/blog/app
cd /srv/blog/app/deploy
cp .env.example .env && nano .env   # RAILS_MASTER_KEY, APP_HOST, TUNNEL_TOKEN
bin/install                         # clones content, creates storage, starts the timer
```

Then, from the Mac:

```bash
deploy/bin/push-photos <user>@blog.local
```

This does the first `contents:sync`. Until the photos arrive, `update` refuses to sync (otherwise it would delete every Picture).

## Day to day

| What | How | When it goes live |
| --- | --- | --- |
| Code | merge into main | about 5 minutes after the image build finishes |
| Articles and static pages | push the content repository | within 5 minutes |
| Photos | `deploy/bin/push-photos <host>` on the Mac | right away |

## Operations (on the Pi)

```bash
journalctl -u blog-update -f                  # update runs (errors from a failed sync go here too)
cd /srv/blog/app/deploy && docker compose logs -f app
docker compose exec app bin/rails console
```

- To stop automatic updates: `sudo systemctl disable --now blog-update.timer`
- Back up `/srv/blog/storage` (and `deploy/.env`). You can recreate everything else: the photos are on the Mac and the variants are regenerated.
