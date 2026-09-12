# Heroku deployment readiness

Updated September 11, 2026. This is a rollout plan, not authorization to change production. Do not run mutation, backup, migration, or deployment commands until their production window is explicitly approved.

## Verified current state

- App: `rdjessee`, Cedar generation, US region, one Basic web dyno.
- The running slug is on `heroku-20`; the already-selected next-build stack is `heroku-24`. The first new build will therefore change both the application and its OS stack.
- The production database contains the same 44 migration versions as this branch. There are no application migrations waiting to run at this checkpoint.
- The custom domain is `www.ralphdonaldjessee.com`, and Automatic Certificate Management is enabled.
- Existing config includes the database, S3, Searchbox, SendGrid, Rails master key, and stable `SECRET_KEY_BASE` settings. Only config-key names were inspected. Turnstile keys are not configured on Heroku.
- The free Cloudflare widget `RDJesseeBlog production signup` now exists in Managed mode, restricted to `www.ralphdonaldjessee.com`, with pre-clearance disabled. Its secret remains in Cloudflare and must not be committed.

## Buildpack correction required before the release build

The current order is:

1. Heroku's Active Storage preview buildpack
2. `jonathanong/heroku-buildpack-ffmpeg-latest`
3. `heroku/ruby`

The second buildpack is unmaintained and explicitly recommends Heroku's Active Storage preview buildpack, which is already installed and supplies ffmpeg. Remove the duplicate. The application now loads Trix from `node_modules`, so add the official Node.js buildpack before Ruby; with the checked-in `package-lock.json`, it uses `npm ci`.

The intended order for the candidate build is:

1. `https://github.com/heroku/heroku-buildpack-activestorage-preview`
2. `heroku/nodejs`
3. `heroku/ruby`

Apply these remote changes only as part of an authorized staging or production rollout. After the build, verify `ruby -v`, `bundle -v`, `node -v`, `ffmpeg -version`, `ffprobe -version`, and that Ruby can load libvips. Heroku currently supports Ruby 4.0.6 and Bundler 4.0.16. Its `heroku-24` base contains libvips 8.15.1, and the official preview buildpack supplies ffmpeg 7.1.3. This is close to the locally tested ffmpeg 7.1.5 candidate but still requires a real conversion check.

Use `heroku-24` for the first controlled release rather than adding a simultaneous move to `heroku-26`. Heroku-26 is supported, but Heroku recommends changing runtime, framework, and stack incrementally; move again after the Rails 8.1 release stabilizes.

Sources: [Heroku Ruby support](https://devcenter.heroku.com/articles/ruby-support-reference), [Active Storage preview buildpack](https://github.com/heroku/heroku-buildpack-activestorage-preview), [Node.js classic build behavior](https://devcenter.heroku.com/articles/nodejs-classic-buildpack-builds), [Heroku stack packages](https://devcenter.heroku.com/articles/stack-packages), and [Heroku-26 availability](https://devcenter.heroku.com/changelog-items/3703).

## Controlled rollout order

1. Explicitly accept or further mitigate the documented no-fix image-library findings. The real-device microphone check now passes locally.
2. Prefer a separate preview/staging app with isolated database, object storage, search, and non-delivering email. Provision nothing paid without approval.
3. Apply the buildpack correction to the chosen candidate app and build on `heroku-24`.
4. Configure `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY`, and `TURNSTILE_HOSTNAME=www.ralphdonaldjessee.com` from the Cloudflare widget. Setting production config creates a release/restart, so defer it to the approved window.
5. Run the test suite, security scans, production asset compilation, `/up` smoke check, association audit, and synthetic image/audio conversion against the exact candidate.
6. Arrange and verify fresh database and media backups. The earlier production backup command was declined; request authorization again rather than assuming it.
7. Record the current release identifier, deploy, and verify the public route set, TLS/assets, login/logout, admin edits, search, comments, images, audio upload/conversion/playback, S3, SendGrid, and both accepted/rejected Turnstile flows.
8. Roll back the application release immediately if validation fails. A Heroku release rollback does not undo database or external-media changes. This checkpoint has no pending migrations, which reduces but does not eliminate rollback risk.

Do not use seeds or `db:prepare` against production.
