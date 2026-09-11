# Production Docker image

The image runs Rails 8.1.3.1 on Ruby 4.0.6 with Bundler 4.0.16. It is a local deployment candidate, not a deployed release. Browser/media workflows, final Rails defaults, backup restoration, security review, staging and Heroku deployment remain outstanding.

## Build

```sh
docker build -t rdjessee-production:local .
```

The build installs gems and npm assets in separate stages. Asset precompilation runs without network access, a database or production credentials. The final image includes ffmpeg, ImageMagick and libvips, runs as UID 1000, and excludes Node and build tools. `SECRET_KEY_BASE_DUMMY` is used only for asset compilation; never set it in a running deployment.

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

The ARM Linux image builds assets with networking disabled, boots as UID 1000 on a custom PORT, and serves `/up`, `/`, `/blog`, `/login`, `/pictures`, `/recordings`, and `/videos` with isolated PostgreSQL and fake AWS credentials. Compiled application CSS/JavaScript return HTTP 200, and the health endpoint returns 200 after a container restart. Synthetic audio and image conversions pass. The application suite passes 131 examples with zero failures and 29 inherited placeholders. The image was rebuilt after upload validation and retry handling were added. Local development browser checks passed login, formatted story creation and WAV upload/conversion. These checks do not verify S3, outbound mail, real media, microphone capture, actual playback, mobile layouts, x86 execution, or production rollout.

Gem and npm advisory checks reported no known vulnerabilities; Brakeman 8.0.6 reported zero warnings after the fixes. OS image scanning and manual security review remain outstanding.
