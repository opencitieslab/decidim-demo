# frozen_string_literal: true

require "digest"
require "json"
require "yaml"

module Cct
  module Seed
    # Loads and cross-checks the two seed data files. Read-only: it never touches the database.
    class Data
      Item = Struct.new(:slug, :source, :content) do
        def url = source.fetch("url")

        def kind = content.fetch("kind", "comment")

        def open_date = Date.parse(source.dig("dates", "open"))

        def close_date
          value = source.dig("dates", "close")
          value && Date.parse(value)
        end

        def theme_key = source["theme"]

        def directorate_key = content["directorate"]

        def department = source["department"].to_s

        def area = source["area"].to_s

        def proposals = Array(content["proposals"])

        def survey = content["survey"]

        def bylaw_text = content["bylaw_text"]

        def bylaw? = kind == "bylaw" && bylaw_text.present?

        def open? = source["status_as_of_2026_11_05"].to_s.match?(/\AOPEN/i)
      end

      attr_reader :sources, :content, :warnings

      def initialize(sources_path:, content_path:)
        @sources = JSON.parse(File.read(sources_path, encoding: "UTF-8"))
        @content = YAML.safe_load_file(content_path, aliases: false)
        @warnings = []
        validate!
      end

      def subcouncils = sources.fetch("subcouncils")

      def wards = sources.fetch("wards")

      def themes = sources.fetch("themes")

      def budget = sources.fetch("budget")

      def users = content.fetch("users")

      def groups = Array(content["groups"])

      def subcouncil(number) = subcouncils.find { |s| s["number"] == number.to_i }

      def ward(number) = wards.find { |w| w["number"] == number.to_i }

      def items
        @items ||= begin
          by_url = content.fetch("items").to_h { |slug, entry| [entry.fetch("url"), [slug, entry]] }
          sources.fetch("items").map do |source|
            slug, entry = by_url[source.fetch("url")]
            unless slug
              slug = fallback_slug(source.fetch("url"))
              warn!("No demo content for item #{source["url"]}; using slug #{slug} and English text only")
            end
            Item.new(slug:, source:, content: entry || {})
          end
        end
      end

      # A translation hash from demo_content.yml, e.g. t("labels", "org_name").
      def t(*path)
        value = content.dig(*path.map(&:to_s))
        raise Error, "Missing translation #{path.join(".")} in demo content" unless value.is_a?(Hash)

        complete(value, path.join("."))
      end

      # Fills missing locales with English (and records a warning) so every seeded field has en/af/xh.
      def complete(translations, name)
        translations = translations.to_h.transform_keys(&:to_s)
        english = translations["en"].to_s
        raise Error, "Missing English text for #{name}" if english.blank?

        LOCALES.to_h do |locale|
          text = translations[locale].to_s
          if text.blank? || text == "TODO"
            warn!("#{name}: no #{locale} text, using English")
            text = english
          end
          [locale, text]
        end
      end

      # Interpolates %{name} placeholders per locale. Values are plain strings or {locale => string}.
      def format(translations, **values)
        translations.to_h do |locale, text|
          [locale, text.gsub(/%\{(\w+)\}/) do
            value = values.fetch(Regexp.last_match(1).to_sym)
            (value.is_a?(Hash) ? value[locale] : value).to_s
          end]
        end
      end

      # Real item title/summary: English from the JSON, af/xh from the YAML. If the English text has
      # changed since it was translated (digest mismatch), af/xh fall back to the new English.
      def item_text(item, field)
        english = item.source.fetch(field).to_s
        stored = item.content[field].to_h
        digest = item.content["#{field}_digest"]
        if digest.present? && digest != self.class.digest(english)
          warn!("#{item.slug}: #{field} changed in the JSON since it was translated; af/xh use the English text until re-translated")
          stored = {}
        end
        complete(stored.merge("en" => english), "#{item.slug}.#{field}")
      end

      def self.digest(text) = Digest::SHA256.hexdigest(text.to_s)[0, 12]

      private

      def warn!(message)
        @warnings << message
      end

      def fallback_slug(url)
        slug = url.to_s.split("/").last.to_s.downcase.gsub(/[^a-z0-9-]+/, "-").squeeze("-").delete_prefix("-")[0, 60].delete_suffix("-")
        slug.match?(/\A[a-z]/) ? slug : "item-#{slug}"
      end

      def validate!
        validate_geography!
        validate_people!
      end

      def validate_geography!
        raise Error, "Expected 20 subcouncils, got #{subcouncils.size}" unless subcouncils.size == 20
        raise Error, "Wards must be numbered uniquely" unless wards.map { |w| w["number"] }.uniq.size == wards.size

        wards.each do |ward|
          raise Error, "Ward #{ward["number"]} has unknown subcouncil #{ward["subcouncil"]}" unless subcouncil(ward["subcouncil"])
        end
      end

      def validate_people!
        users.each do |key, user|
          raise Error, "User #{key} has unknown ward #{user["ward"]}" unless ward(user["ward"])
        end
        known_users = users.keys
        content.fetch("items").each do |slug, entry|
          raise Error, "Invalid process slug #{slug}" unless slug.match?(/\A[a-z][a-z0-9-]+\z/)

          Array(entry["proposals"]).each do |proposal|
            authors = [proposal["author"]] + Array(proposal["comments"]).flat_map { |c| [c["author"]] + Array(c["replies"]).map { |r| r["author"] } }
            unknown = authors - known_users
            raise Error, "#{slug}: unknown author(s) #{unknown.join(", ")}" if unknown.any?
          end
        end
      end
    end
  end
end
