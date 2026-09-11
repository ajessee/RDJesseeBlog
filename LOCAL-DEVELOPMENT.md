# Local upgrade environment

This is the temporary **Rails 8.1.3.1 / Ruby 4.0.6 development environment**, not the completed modernization or a production Docker image. This remains an intermediate step; do not deploy it yet. The upgrade passed through Ruby 3.0.7 and Rails 6.1.7.10 / 7.0.10 to reproduce and repair the legacy baseline before changing the runtime. Rails 6.1.7.10 removed the unavailable `mimemagic 0.3.5` dependency from the original lockfile.

Docker Desktop must be running. From this repository:

```sh
docker compose build web
docker compose run --rm --no-deps web npm ci --ignore-scripts
docker compose up -d db search
docker compose run --rm web bundle exec rails db:create db:schema:load
docker compose up web
```

Open http://localhost:3000. The schema-loading commands above create an empty development database with no production content. The current upgrade workspace was also exercised with `db:prepare`, which ran the repository’s existing demo seeds locally; that data is synthetic and no production data was imported. Do not run the existing production pull task as part of local setup.

The web port binds only to localhost. PostgreSQL and Elasticsearch have no published host ports. Compose uses dedicated named volumes and local development credentials, not Heroku credentials. Development uploads use local disk and mail uses the test delivery adapter. Search uses the local Elasticsearch container; its legacy version is temporary for compatibility with the locked client.

## Tests

```sh
docker compose run --rm -e RAILS_ENV=test web bundle exec rails db:create db:schema:load
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/upgrade_baseline_spec.rb
```

RSpec refuses an explicit non-test environment or inherited `DATABASE_URL`. Development and test databases have different names. Schema loading is for disposable local databases only. Coverage output goes to ignored `tmp/coverage` instead of rewriting historical committed reports.

Bootsnap is updated and enabled. The image uses Bundler 4.0.16, Node 24 and Debian Trixie, with ffmpeg, ImageMagick and libvips installed explicitly. Ruby 4.0.6 and the updated dependency set pass 131 examples with zero failures and 29 inherited placeholders, plus autoloading checks. Tests exercise real audio conversion and image resizing. The production image is documented in [PRODUCTION-DOCKER.md](PRODUCTION-DOCKER.md).

Stop local services without deleting data:

```sh
docker compose down
```

## Baseline findings

The first executable legacy suite ran 82 examples: 25 failures and 29 pending. Seven additional empty helper specs referenced nonexistent modules and were removed to let the suite load; no implemented assertions were removed. Failures include scaffold tests issuing GET requests for create/delete without IDs, mailer tests omitting required users, and feature tests expecting obsolete headings, submit labels and redirect destinations. The obsolete assertions and request methods have now been repaired. The repaired Rails 6.1 suite passed 107 examples with zero failures and 29 pending. After the Rails 7.0.10 upgrade and additional editor/comment regressions, the suite passes **111 examples, zero failures, 29 pending**. The upgrade continued through Rails 7.2.3 and 8.0.5.1 to Rails 8.1.3.1. With expanded story-page and metadata coverage, Rails 8.1.3.1 / Ruby 3.3.12 passes **116 examples, zero failures, 29 pending**, plus `rails zeitwerk:check` and test asset compilation. JSON is pinned to 2.x because version 3.0.2 breaks session decoding with this dependency set. Pending examples are inherited placeholders, not verified behavior.

`trix-rails` and unused Webpacker scaffolding were removed. Trix 2.1.19 is pinned through npm and served by Sprockets; existing rich HTML remains in its original database columns. The npm setup command above populates the bind-mounted checkout’s `node_modules`.

Test-environment asset compilation also passes:

```sh
docker compose run --rm -e RAILS_ENV=test web bundle exec rails assets:precompile
```

The rebuilt development image also boots Puma and returns HTTP 200 for `/`, `/blog`, `/stories`, `/login`, `/pictures`, `/recordings`, and `/videos`. The production image also builds assets with networking disabled and has passed local non-root HTTP and media-tool smoke checks. Local browser login, formatted story creation and WAV upload/conversion passed using synthetic data. Microphone capture, actual playback, mobile layouts and production S3/SendGrid integration remain unverified. Rails application defaults remain at 6.0, with the 7.1 cache format and declaration-order transaction callbacks explicitly enabled; Rails 8.1 supplies modern timezone conversion behavior. Cookie/signature and media defaults still require compatibility checks. Development and test secrets are generated locally by Rails; production must retain the existing Heroku `SECRET_KEY_BASE`.

See [UPGRADE-PLAN.md](UPGRADE-PLAN.md) for the full sequence. Heroku and production data have not been changed.
