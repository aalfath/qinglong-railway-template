# Qinglong on Railway

One-click [Railway](https://railway.com) template for [Qinglong](https://github.com/whyour/qinglong) (青龙), a web panel that schedules and runs Python, JavaScript, TypeScript and Shell scripts on cron timers, with logs, environment variables, dependency installs and notifications.

**Version:** Qinglong **2.24.0**, official image `whyour/qinglong:2.24.0@sha256:2431b8b92d5822423d7d598110294691ae2a32d7fbde5c5d5a963db8b4f47cc3` (pinned by version and digest in the [`Dockerfile`](Dockerfile)).

## What the template deploys

One service, `Qinglong`, built from this repository:

- the panel on Railway's public domain (port `5700`, health check `/api/health`);
- a volume at `/ql/data` holding the SQLite database, scripts, logs, config, installed dependencies and backups, so everything survives redeploys and restarts;
- a small wrapper (`railway/railway-start.sh`) that creates the admin account on the first boot, refuses to start without a JWT secret, and exits non-zero when the panel stops answering so Railway restarts it.

No separate database is needed: Qinglong keeps its state in SQLite on the volume.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `QL_ADMIN_USERNAME` | `admin` | Admin user created on the first boot. |
| `QL_ADMIN_PASSWORD` | generated (`${{secret(24)}}`) | Admin password for the first boot. Read it in Railway → Qinglong → Variables. Change it later in the panel (System settings → Security); changing this variable after the first boot has no effect. |
| `JWT_SECRET` | generated (`${{secret(48)}}`) | Signs login tokens. Without it upstream falls back to a public default. |
| `PORT` | `5700` | Port the panel listens on. |

Optional, not set by the template: `TZ` (time zone for cron schedules, default `UTC`), `QL_CPU_LIMIT` (task concurrency, default = the service's vCPU count), `QlBaseUrl` (serve under a sub-path).

## After deploy

1. Open the public URL and sign in with `QL_ADMIN_USERNAME` / `QL_ADMIN_PASSWORD` from the service's Variables tab.
2. Change the password and turn on two-factor login under System settings → Security.
3. Add scripts (Scripts), subscriptions to script repositories (Subscriptions), timed tasks (Timed Tasks) and dependencies (Dependencies).

**Memory:** the panel idles at roughly 200–300 MB and fits Railway's 0.5 GB Free/Trial limit; heavy scripts or large dependency installs need more.

## Updates

Railway notifies everyone who deployed this template when this repository's `main` branch changes. Each version bump is listed in [`CHANGELOG.md`](CHANGELOG.md), breaking changes first. Apply the update from the Railway dashboard when you're ready; the volume is kept. Don't use the panel's built-in "System update", because the image is pinned and a redeploy replaces it.

## Licence

Qinglong is Apache-2.0 ([upstream](https://github.com/whyour/qinglong)). The wrapper files in this repository are released under the same licence.
