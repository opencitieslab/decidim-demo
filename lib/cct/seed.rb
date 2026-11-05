# frozen_string_literal: true

module Cct
  # One-command, idempotent seed of the City of Cape Town (CCT) demo (plan U6).
  #
  # Two data files drive it:
  # - db/seeds/cct/cct-seed-sources.json: real, sourced CCT data (subcouncils, wards, IDP themes,
  #   2025-26 participation items, 2026/27 budget figures);
  # - db/seeds/cct/demo_content.yml: the fictional layer (users, proposals, comments, answers,
  #   groups) plus every en/af/xh string the seed writes.
  #
  # Records are upserted by stable keys (process slug, taxonomy name, component name, English
  # title, user email), so a rerun updates in place. Fictional participants carry
  # `extended_data["cct_seed"]`; everything they author is found through them, which is what
  # `reset_demo_content` deletes. The seed never creates or changes admin accounts and never runs
  # Decidim's own `db:seed`.
  module Seed
    class Error < StandardError; end

    MARKER = "cct_seed"
    LOCALES = %w(en af xh).freeze
    TIME_ZONE = "Africa/Johannesburg"

    module_function

    def default_sources_path = Rails.root.join("db/seeds/cct/cct-seed-sources.json").to_s

    def default_content_path = Rails.root.join("db/seeds/cct/demo_content.yml").to_s

    # Seeds (or updates) the CCT demo in one organization.
    #
    # sources - path to the real-data JSON (default: db/seeds/cct/cct-seed-sources.json)
    # content - path to the fictional-content YAML (default: db/seeds/cct/demo_content.yml)
    # host    - organization host; optional when there is exactly one organization
    # logger  - any object responding to #info and #warn
    #
    # Returns a Hash of record counts.
    def run(sources: nil, content: nil, host: nil, logger: default_logger)
      Runner.new(
        sources_path: sources.presence || default_sources_path,
        content_path: content.presence || default_content_path,
        host: host.presence,
        logger:
      ).call
    end

    # Deletes the fictional layer only: users marked with `extended_data["cct_seed"]` and what they
    # authored (proposals, comments, supports, budget orders...), plus the fictional "Demo idea"
    # budget projects. Real-data records (taxonomies, processes, meetings, real projects) stay.
    def reset_demo_content(content: nil, host: nil, logger: default_logger)
      Reset.new(
        content_path: content.presence || default_content_path,
        host: host.presence,
        logger:
      ).call
    end

    def find_organization(host)
      return Decidim::Organization.find_by(host:) || raise(Error, "No organization with host #{host.inspect}") if host

      organizations = Decidim::Organization.limit(2).to_a
      raise Error, "No organization found. Create one in /system first." if organizations.empty?
      raise Error, "Several organizations exist: set CCT_SEED_HOST to choose one." if organizations.size > 1

      organizations.first
    end

    def fictional_users(organization)
      Decidim::User.where(organization:).where("extended_data ? :marker", marker: MARKER)
    end

    def default_logger
      ActiveSupport::Logger.new($stdout).tap do |logger|
        logger.formatter = proc { |severity, _time, _prog, msg| "#{severity == "INFO" ? "" : "#{severity}: "}#{msg}\n" }
      end
    end
  end
end
