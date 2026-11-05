# syntax=docker/dockerfile:1
# Decidim 0.32.2 demo image. Build: docker compose build app
# The LAST stage (runtime) is the production image and the default build target.
# The `test` stage is only built by docker-compose.test.yml (target: test).
ARG RUBY_VERSION=3.4.7
ARG NODE_VERSION=24.18.0

# ---------- base: toolchain shared by build and test ----------
FROM ruby:${RUBY_VERSION}-slim AS base
ARG NODE_VERSION
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential git curl xz-utils libpq-dev libicu-dev libyaml-dev zlib1g-dev pkg-config libvips42 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1
WORKDIR /app

# ---------- build stage (production gems and assets) ----------
FROM base AS build
ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 && rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY . .
# Dummy secret only for asset compilation; the real one comes from .env.production at runtime
RUN SECRET_KEY_BASE=precompile-dummy DATABASE_URL=postgres://dummy/dummy \
    bin/rails assets:precompile \
 && rm -rf node_modules tmp/cache

# ---------- test stage (dev/test gems + test packs; never shipped) ----------
FROM base AS test
ENV RAILS_ENV=test \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development \
    BUNDLE_PATH=/usr/local/bundle \
    DECIDIM_AVAILABLE_LOCALES=en,af,xh \
    DISABLE_SPRING=1

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      imagemagick postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 && rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY . .
# Pre-compile the test packs so the first spec run does not have to
RUN bin/rails shakapacker:compile

CMD ["bundle", "exec", "rspec"]

# ---------- runtime stage (production; default target) ----------
FROM ruby:${RUBY_VERSION}-slim
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      libpq5 libvips42 imagemagick libicu76 libyaml-0-2 curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 decidim && useradd --system --uid 1000 --gid decidim --create-home decidim
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=decidim:decidim /app /app
RUN mkdir -p storage tmp log public/uploads && chown -R decidim:decidim storage tmp log public/uploads
USER decidim

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
