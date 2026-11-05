# frozen_string_literal: true

module Cct
  module Seed
    # State shared by the builders during one seed run: the organization, the data files, the
    # logger and the records built so far (taxonomies, users...).
    class Context
      attr_reader :organization, :data, :logger, :store, :today, :stats

      def initialize(organization:, data:, logger:)
        @organization = organization
        @data = data
        @logger = logger
        @store = {}
        @today = Time.zone.today
        @stats = Hash.new(0)
      end

      def log(message) = logger.info("[cct:seed] #{message}")

      def warn(message) = logger.warn("[cct:seed] #{message}")

      def count(key, by = 1)
        stats[key] += by
      end

      def zone = ActiveSupport::TimeZone[TIME_ZONE]

      # A time in the organization's time zone on the given date.
      def time_on(date, hour = 10, minute = 0) = zone.local(date.year, date.month, date.day, hour, minute)

      def users = store.fetch(:users, {})

      def taxonomy(kind, key) = store.dig(:taxonomies, kind, key)
    end
  end
end
