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

Bootsnap is updated and enabled. The image uses Bundler 4.0.16, Node 24 and Debian Trixie, with ffmpeg, ImageMagick and libvips installed explicitly. Ruby 4.0.6 and the updated dependency set pass 161 examples with zero failures and 29 inherited placeholders, plus autoloading and asset-compilation checks. Tests exercise authorization boundaries, required associations, Rails-default cookie, redirect and CSRF compatibility, signup-abuse prevention, account activation and single-use password recovery with non-delivering mail, real WAV and browser-style WebM/Opus conversion, libvips image resizing, and rejection of a real EXR payload disguised as an allowed JPEG upload. The production image is documented in [PRODUCTION-DOCKER.md](PRODUCTION-DOCKER.md).

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

Audit association integrity without printing row content:

```sh
docker compose run --rm web bin/association-audit
```

This read-only command exits nonzero for required null owners/parents, orphaned references, or unexpected polymorphic types. It reports missing `Recording#recorder` values separately as an allowed legacy condition. It passes against the isolated synthetic development database. An authorized September 11 production query found no other invalid associations; all 39 historical recordings have valid parents but lack uploader/recorder attribution. The tracked May 2018 `dump.sql` predates those recordings and was not used as current deployment evidence.

## Signup verification

Turnstile is optional in development and test, but production signup fails closed without a configured secret. To exercise the widget locally, export Cloudflare's published always-pass test keys before starting Compose:

```sh
export TURNSTILE_SITE_KEY=1x00000000000000000000AA
export TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA
docker compose up web
```

Do not set `TURNSTILE_HOSTNAME` with Cloudflare's dummy test credentials. Production requires a real hostname-restricted widget and `TURNSTILE_HOSTNAME=www.ralphdonaldjessee.com`. Verification uses short connection/read timeouts and rejects missing, failed, malformed, and wrong-host responses.

## Security scans

The application scanners are locked development dependencies and run through one CI-friendly command:

```sh
docker compose build web
docker compose run --rm --no-deps web bin/security-scan
```

This runs Brakeman, updates and runs Bundler Audit, and runs npm audit at high severity. Advisory updates require network access; the application itself still uses isolated local services. The security gems are in the development group and are excluded from the production image.

Scan the exact production image separately after a fresh package build:

```sh
docker build --pull --no-cache -t rdjessee-production:local .
bin/container-security-scan rdjessee-production:local
```

Docker Scout must be installed and able to update its vulnerability data. The container command intentionally exits nonzero for high or critical findings; investigate and document findings rather than weakening the gate.

Build the deployment architecture explicitly when it differs from the development host:

```sh
docker build --platform linux/amd64 -t rdjessee-production:amd64 .
```

The amd64 image has been built and executed under Docker Desktop emulation. Rails eager loading, libvips resizing, ffmpeg, OpenSSL, the non-root user, and isolated HTTP boot all pass. Emulation verifies image portability and native x86-64 artifacts, but it is not a performance test on native x86 hardware.

The rebuilt development image also boots Puma and returns HTTP 200 for `/`, `/blog`, `/stories`, `/login`, `/pictures`, `/recordings`, and `/videos`. The production image also builds assets with networking disabled and has passed local non-root HTTP and media-tool smoke checks. Local browser login, formatted story creation and WAV upload/conversion passed using synthetic data. At 1280x720 and 390x844, the public home, blog, stories, pictures, recordings and login pages had no document-level horizontal overflow or broken images; the mobile menu works, audio controls fit, and a stored converted recording began playback. Mobile recordings spacing was corrected so its heading clears the fixed navigation. Browser microphone start/stop creates an inline preview with an editable default caption without using a blocking prompt. A request regression sends valid WebM/Opus—the recorder's preferred browser format—through the real upload endpoint and confirms persisted AAC/MP4 output with ffprobe. The in-app browser's synthetic microphone blob was not decodable by either its preview or ffmpeg; submitting it exercised the expected preserved-original/retry failure path. A real-device Chrome check subsequently passed microphone permission, capture, inline playback, submission, conversion, and ffprobe decoding against the isolated database. The resulting signed-in user's M4A/MP4 recording was 108,132 bytes and 5.339 seconds long. Production S3/SendGrid integration remains unverified. Rails application defaults now load 8.1; libvips image variants, sessions, remembered login, legacy signed cookies and same-host return URLs have focused compatibility coverage. New cookie keys use SHA-256, with SHA-1 rotations tested against both encrypted sessions and signed remember-me cookies. Development and test secrets are generated locally by Rails; production must retain the existing Heroku `SECRET_KEY_BASE` so the rotations can read existing cookies.

Rails 8.1 per-form CSRF tokens, Origin validation, required `belongs_to` validation, and SHA-256 cookie-key derivation are enabled. `Recording#recorder` is explicitly optional for the 39 ownerless historical production recordings; all new recording paths continue assigning the signed-in user. Legacy SHA-1 cookie reads use tested rotations rather than holding back the active default. See [UPGRADE-PLAN.md](UPGRADE-PLAN.md) for the full sequence. Production was queried read-only for aggregate association integrity; no production data was changed.
