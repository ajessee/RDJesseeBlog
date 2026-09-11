# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0.6
FROM node:24-trixie AS node
FROM ruby:${RUBY_VERSION}-slim-trixie AS base
WORKDIR /app
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    ca-certificates curl ffmpeg libpq5 libvips42 openssl tzdata \
    && rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV=production BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test RAILS_LOG_TO_STDOUT=1 RAILS_SERVE_STATIC_FILES=1

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
RUN gem install bundler -v 4.0.16 --no-document
COPY Gemfile Gemfile.lock ./
RUN bundle config set frozen true && bundle install && rm -rf /usr/local/bundle/cache
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
# This stage cannot reach a database, S3, or any external service.
RUN --network=none SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
RUN rm -rf node_modules tmp/cache log/*

FROM base
RUN groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /app /app
RUN mkdir -p /app/log /app/tmp/pids /app/storage \
    && chown -R rails:rails /app/log /app/tmp /app/storage \
    && chown rails:rails /app
USER rails
EXPOSE 3000
ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
