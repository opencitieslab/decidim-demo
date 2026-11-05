# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Shared helpers for the seed builders. Mirrors the role of Decidim::Seeds (v0.32.2) but reads
      # from the data files instead of Faker and upserts instead of always creating.
      class Base
        attr_reader :ctx

        def initialize(ctx)
          @ctx = ctx
        end

        private

        delegate :organization, :data, :log, :warn, :count, to: :ctx

        def t(*path) = data.t(*path)

        def fmt(translations, **values) = data.format(translations, **values)

        def html(translations) = Html.paragraphs(translations)

        # {locale => localized long date}
        def localized_date(date)
          LOCALES.index_with { |locale| I18n.l(date, format: :long, locale:) }
        end

        # {locale => "R1,000,000"} with each locale's thousands delimiter.
        def localized_rand(amount)
          LOCALES.index_with do |locale|
            "R#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_i, locale:)}"
          end
        end

        # Finds a record of `scope` whose translatable `column` has this English value.
        def find_by_english(scope, column, english)
          scope.find_by("#{scope.connection.quote_column_name(column)} ->> 'en' = ?", english)
        end

        # Upserts a component of a space, keyed by manifest and English name.
        # rubocop:disable Metrics/ParameterLists
        def upsert_component(space:, manifest_name:, name:, weight:, settings: {}, step_settings: {})
          component = space.components.where(manifest_name: manifest_name.to_s)
                           .find_by("name ->> 'en' = ?", name.fetch("en"))
          created = component.nil?
          component ||= Decidim::Component.new(participatory_space: space, manifest_name: manifest_name.to_s)
          component.name = name
          component.weight = weight
          component.settings = settings
          component.step_settings = step_settings if step_settings.any?
          component.published_at ||= Time.current
          component.save!
          count(:components) if created
          component
        end
        # rubocop:enable Metrics/ParameterLists

        def set_taxonomies(record, taxonomies)
          wanted = taxonomies.compact.uniq
          return if record.taxonomies.to_a.sort_by(&:id) == wanted.sort_by(&:id)

          record.taxonomies = wanted
        end
      end
    end
  end
end
