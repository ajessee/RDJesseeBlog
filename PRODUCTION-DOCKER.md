# Production Docker image

The image runs Rails 8.1.3.1 on Ruby 4.0.6 with Bundler 4.0.16 and Rails 8.1 application defaults. It is a local deployment candidate, not a deployed release. Real-device microphone validation, backup restoration, staging and Heroku deployment remain outstanding. Cookie keys temporarily retain their legacy SHA-1 derivation for existing-cookie compatibility; migrate them with a tested rotation rather than changing them during deployment.

## Build

```sh
docker build -t rdjessee-production:local .
```

For a security-validation build, refresh the base image and Debian packages rather than reusing cached package-install layers:

```sh
docker build --pull --no-cache -t rdjessee-production:local .
```

Build an explicit amd64 deployment candidate from an ARM development host with:

```sh
docker build --platform linux/amd64 -t rdjessee-production:amd64 .
```

The build installs gems and npm assets in separate stages. Asset precompilation runs without network access, a database or production credentials. The final image includes ffmpeg and libvips, runs as UID 1000, and excludes ImageMagick, Node and build tools. Rails 8.1 image variants use libvips; ImageMagick remains only in the development/test image for fixture generation and independent output inspection. `SECRET_KEY_BASE_DUMMY` is used only for asset compilation; never set it in a running deployment.

## Runtime configuration

Inject secrets through the host's secret configuration or an untracked environment file. Required settings:

- `DATABASE_URL`: the intended PostgreSQL database.
- `SECRET_KEY_BASE`: retain the existing Heroku value when upgrading so signing keys remain stable.
- Either `RAILS_MASTER_KEY` for existing encrypted AWS credentials, or both `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- `S3_BUCKET` and `AWS_REGION`: default to the existing production bucket and region. Use a separate bucket for staging.
- `SEARCHBOX_URL`: the existing Elasticsearch connection URL.
- `SENDGRID_USERNAME` and `SENDGRID_PASSWORD`: existing mail credentials.
- `PORT`: defaults to 3000. `RAILS_MAX_THREADS` defaults to 5; keep total connections below the database limit.

The server serves precompiled assets and writes logs to stdout. HTTPS is enforced; the reverse proxy must terminate TLS and supply the trusted forwarded protocol. The `/up` endpoint verifies Rails can serve a request; it is not a database, search or S3 availability check.

```sh
docker run --rm --env-file .env.production -p 127.0.0.1:3000:3000 rdjessee-production:local
```

Only use this command with a correctly configured TLS proxy. Do not point an unvalidated local instance at production services.

## Release operation

The web entrypoint does not run migrations or seeds. After staging validation and verified backups, run migrations as an explicit release command using the same image and runtime configuration:

```sh
docker run --rm --env-file .env.production rdjessee-production:local bundle exec rails db:migrate
```

Do not use `db:prepare` for production: the repository still contains legacy demo seeds. Database and S3 storage remain external; the container filesystem is disposable. Heroku container deployment uses its `container` stack and does not reduce dyno pricing. Continuing with Heroku buildpacks remains an available deployment choice.

## Local validation

The ARM Linux image builds assets with networking disabled, boots as UID 1000 on a custom PORT, and serves `/up`, `/`, `/blog`, `/login`, `/pictures`, `/recordings`, and `/videos` with isolated PostgreSQL and fake AWS credentials. Compiled application CSS/JavaScript return HTTP 200, and the health endpoint returns 200 after a container restart. Synthetic image conversion plus WAV and WebM/Opus audio conversion pass. The application suite passes 147 examples with zero failures and 29 inherited placeholders. It includes end-to-end account activation and single-use password recovery using synthetic users and Action Mailer's non-delivering test adapter. The image was rebuilt successfully after Rails 8.1 defaults and libvips variants were enabled; asset compilation still runs without network access or runtime credentials. Local development browser checks passed login, formatted story creation, WAV upload/conversion, stored-recording playback, responsive public-page layouts and the microphone capture UI. A request regression sends browser-style WebM/Opus through the real upload endpoint and verifies persisted AAC/MP4 output. These checks do not verify S3, outbound SendGrid mail, successful permission/capture from real microphone hardware, or production rollout.

The explicit amd64 image (`sha256:c1750f09de11`) also builds successfully with network-disabled asset compilation. Under Docker Desktop emulation it reports x86-64 Ruby 4.0.6, eagerly loads Rails 8.1.3.1, resizes a synthetic image through libvips, runs ffmpeg 7.1.5 and OpenSSL 3.5.7, and runs as UID 1000. It served `/up`, `/`, `/blog`, `/login`, `/pictures`, `/recordings`, and `/videos` with HTTP 200 against a disposable local PostgreSQL database; that container and database were removed afterward. This verifies functional architecture parity, not native-x86 performance.

The reproducible application scan is `docker compose run --rm --no-deps web bin/security-scan`. On September 11, 2026, Brakeman 8.0.6 reported zero warnings, Bundler Audit reported no vulnerable gems using advisory database commit `93b32f641f84282183ce58ab1d7204bee50885bd` dated September 8, and npm reported zero vulnerabilities.

Run the image gate with:

```sh
bin/container-security-scan rdjessee-production:local
```

Docker Scout initially reported 1 critical and 28 high findings across seven packages. A fresh build found the available OpenSSL 3.5.7 Debian update; OpenSSL is now an explicit runtime package so that remediation is included instead of being hidden by a cached base layer. The reduced final ARM image (`sha256:ccd1a5f54812`, 742 indexed packages) verifies both `openssl` and `libssl` at 3.5.7 and rescans at 0 critical and 25 high findings. Twenty-four high findings in OpenEXR, cJSON, libvips, libxml2 and zlib have no published Debian fix. The vulnerable libraries are dependencies of required libvips/ffmpeg functionality; redundant ImageMagick was removed without changing the count. A real EXR payload named and declared as JPEG is identified as unsupported and rejected before persistence or variant processing, with regression coverage, but this is not a sandbox for all image decoding. Scout also flags Ruby's inactive default `json` 2.18.0 gem, while the application demonstrably loads the separately installed locked `json` 2.21.2 under `bundle exec`; keep monitoring the base Ruby image rather than treating the inactive copy as the application version. Image findings must be addressed or explicitly accepted before deployment.

After explicit approval for Docker Scout image indexing, the amd64 image (`sha256:c1750f09de11`, 747 indexed packages, 390 MB) also scanned at 0 critical and 25 high findings in the same six packages as ARM. The five-package count difference is architecture-specific packaging; it did not add a vulnerable package or finding. Both architecture reports therefore have the same documented remediation/acceptance work before deployment.
