# frozen_string_literal: true

# Home for the City of Cape Town (CCT) demo customisations: locale plumbing now;
# authorization workflows and decorators are registered here as they are added.

# Locales. The enabled set comes from DECIDIM_AVAILABLE_LOCALES (en,af,xh; see
# docker-compose.yml and deploy/env.production.example). Afrikaans and isiXhosa fall
# back to English for any key we have not translated, so a missing string never
# renders as "translation missing". This runs after Decidim's own
# `decidim_core.setup_i18n` initializer (which sets `fallbacks = true`) and before
# Rails applies the I18n config in `after_initialize`, so it takes effect.
Rails.application.config.i18n.fallbacks = [:en, { af: [:en], xh: [:en] }]
