# syntax=docker/dockerfile:1
# Decidim 0.32.2 demo image. Build: docker compose build app
ARG RUBY_VERSION=3.4.7
ARG NODE_VERSION=24.18.0

# ---------- build stage ----------
FROM ruby:${RUBY_VERSION}-slim AS build
ARG NODE_VERSION
ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential git curl xz-utils libpq-dev libicu-dev libyaml-dev zlib1g-dev pkg-config libvips42 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1

WORKDIR /app
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 && rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY . .
# Dummy secret only for asset compilation; the real one comes from .env.production at runtime
RUN SECRET_KEY_BASE=precompile-dummy DATABASE_URL=postgres://dummy/dummy \
    bin/rails assets:precompile \
 && rm -rf node_modules tmp/cache

# ---------- runtime stage ----------
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
