ARG RUBY_VERSION=3.4.8
FROM node:22-bookworm-slim AS js_runtime
FROM ruby:${RUBY_VERSION}-slim-bookworm AS base

ENV APP_HOME=/app \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    sqlite3 \
    libyaml-dev \
    pkg-config \
    postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}

# Used only to generate and lock the application from inside Docker.
FROM base AS bootstrap
RUN gem install rails -v 8.1.4 --no-document

FROM base AS development
COPY --from=js_runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=js_runtime /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment true \
  && bundle install --jobs 4 --retry 3

RUN groupadd --gid 1000 app \
  && useradd --uid 1000 --gid app --create-home app \
  && mkdir -p storage tmp log \
  && chown -R app:app storage tmp log

USER app
EXPOSE 3000
CMD ["sh", "-c", "bin/rails db:prepare && exec bin/rails server -b 0.0.0.0"]
