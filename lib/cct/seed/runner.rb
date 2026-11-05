# frozen_string_literal: true

module Cct
  module Seed
    # Runs the builders in order inside one transaction (all or nothing).
    class Runner
      BUILDERS = [
        Builders::Organization,
        Builders::Pages,
        Builders::Taxonomies,
        Builders::Users,
        Builders::Processes,
        Builders::WardAllocations,
        Builders::Restrictions
      ].freeze

      def initialize(sources_path:, content_path:, host:, logger:)
        @sources_path = sources_path
        @content_path = content_path
        @host = host
        @logger = logger
      end

      def call
        data = Data.new(sources_path: @sources_path, content_path: @content_path)
        organization = Seed.find_organization(@host)
        ctx = nil

        Time.use_zone(TIME_ZONE) do
          I18n.with_locale(:en) do
            ActiveRecord::Base.transaction do
              ctx = Context.new(organization:, data:, logger: @logger)
              BUILDERS.each { |builder| builder.new(ctx).call }
            end
          end
        end

        data.warnings.uniq.each { |warning| @logger.warn("[cct:seed] #{warning}") }
        created = ctx.stats.map { |key, value| "#{key}=#{value}" }.join(", ")
        @logger.info("[cct:seed] done for #{organization.host}#{created.present? ? "; created #{created}" : "; nothing new to create"}")
        ctx.stats
      end
    end
  end
end
