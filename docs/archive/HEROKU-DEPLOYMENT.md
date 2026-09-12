# Heroku deployment record and remaining validation

> **Archived.** Point-in-time record of the `v169` production rollout. For current outstanding work, see [ROADMAP.md](../development/ROADMAP.md).

Updated September 12, 2026. The user explicitly authorized skipping staging, creating a fresh production database backup, correcting the production configuration/buildpacks, and deploying. Release `v169` from commit `6a8993e` is live on `heroku-24`. This authorization was for this rollout; it is not standing authorization for future production mutations.

## Verified current state

- App: `rdjessee`, Cedar generation, US region, one Basic web dyno.
- The running slug is release `v169` on `heroku-24`; pre-rollout application code was represented by the older slug retained through release `v165`.
- The production database contains the same 44 migration versions as this branch. There are no application migrations waiting to run at this checkpoint.
- The custom domain is `www.ralphdonaldjessee.com`, and Automatic Certificate Management is enabled.
- Existing config includes the database, S3, Searchbox, SendGrid, Rails master key, stable `SECRET_KEY_BASE`, and the three Turnstile settings. Secret values are not committed or documented.
- The free Cloudflare widget `RDJesseeBlog production signup` now exists in Managed mode, restricted to `www.ralphdonaldjessee.com`, with pre-clearance disabled. Its secret remains in Cloudflare and must not be committed.

## Applied buildpack correction

The former order was:

1. Heroku's Active Storage preview buildpack
2. `jonathanong/heroku-buildpack-ffmpeg-latest`
3. `heroku/ruby`

The second buildpack is unmaintained and explicitly recommends Heroku's Active Storage preview buildpack, which is already installed and supplies ffmpeg. Remove the duplicate. The application now loads Trix from `node_modules`, so add the official Node.js buildpack before Ruby; with the checked-in `package-lock.json`, it uses `npm ci`.

The deployed order is:

1. `https://github.com/heroku/heroku-buildpack-activestorage-preview`
2. `heroku/nodejs`
3. `heroku/ruby`

The release build installed FFmpeg 7.1.3, Node 24.21.0, Ruby 4.0.6, Bundler 4.0.16, and x86-64 native gems, and completed Rails asset precompilation. Puma's live boot log confirms Rails 8.1.3.1 and Ruby 4.0.6 on x86-64 Linux. Direct runtime `node`, `ffprobe`, and libvips checks plus a real production conversion remain outstanding; avoid a metered one-off dyno unless explicitly approved.

Use `heroku-24` for the first controlled release rather than adding a simultaneous move to `heroku-26`. Heroku-26 is supported, but Heroku recommends changing runtime, framework, and stack incrementally; move again after the Rails 8.1 release stabilizes.

Sources: [Heroku Ruby support](https://devcenter.heroku.com/articles/ruby-support-reference), [Active Storage preview buildpack](https://github.com/heroku/heroku-buildpack-activestorage-preview), [Node.js classic build behavior](https://devcenter.heroku.com/articles/nodejs-classic-buildpack-builds), [Heroku stack packages](https://devcenter.heroku.com/articles/stack-packages), and [Heroku-26 availability](https://devcenter.heroku.com/changelog-items/3703).

## Production rollout result

- Manual database backup `b037` completed immediately before the release. Continuous database protection also reports enabled, but restoration has not been tested and S3 media backup completeness is not established.
- Turnstile configuration releases were `v166` through `v168`; the application deploy is `v169` from commit `6a8993e`.
- Heroku built on `heroku-24` with the corrected buildpack order and released successfully. The Basic web dyno reached `up` without a crash.
- The custom HTTPS domain returned 200 for `/up`, `/`, `/stories`, `/pictures`, `/recordings`, `/videos`, and `/signup`. The fingerprinted application CSS and JavaScript returned 200.
- The live signup page preserved the site's responsive visual identity and displayed a successful Cloudflare Turnstile widget. No account was created and no email was sent during this read-only rendering check.
- An existing Active Storage recording followed its signed redirect and returned a 1024-byte ranged response with HTTP 206 and `audio/mp4`, verifying production database-to-S3 media delivery.
- Focused logs after the release show successful Rails 8.1.3.1 / Ruby 4.0.6 boot and successful checks, with no matching 5xx, crash, error, or fatal entries.
- No migration command ran: production and the branch had the same 44 migration versions. No seeds or `db:prepare` ran.

## Outstanding follow-up work

Tracked in [ROADMAP.md](../development/ROADMAP.md) rather than duplicated here. (Item 5 from the original list — removing `bin/bundle` and adding a `Procfile` — was completed 2026-09-12.) This document remains the historical record of what was open immediately after the `v169` rollout.

Do not use seeds or `db:prepare` against production.
