# frozen_string_literal: true

# Loads this app (not a generated dummy app) under decidim-dev's test support:
# FactoryBot with Decidim's factories, rspec-rails, Decidim's rspec_support helpers
# (Warden/Devise, component and permission helpers, WebMock, Shakapacker compile...).
# Mirrors how Decidim modules boot their specs (decidim-dev/lib/decidim/dev/test/base_spec_helper.rb),
# with Decidim::Dev.dummy_app_path pointing at this repository.
ENV["RAILS_ENV"] ||= "test"
# Must be set before Decidim is required: base_spec_helper would otherwise default to en,ca,es.
ENV["DECIDIM_AVAILABLE_LOCALES"] ||= "en,af,xh"
ENV["DECIDIM_DEFAULT_LOCALE"] ||= "en"

require_relative "spec_helper"

require "decidim/dev"
Decidim::Dev.dummy_app_path = File.expand_path("..", __dir__)

require "decidim/dev/test/base_spec_helper"

abort("Refusing to run specs outside the test environment") unless Rails.env.test?
