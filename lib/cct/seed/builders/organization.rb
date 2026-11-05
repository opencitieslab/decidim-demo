# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Updates the existing organization: demo name, en/af/xh, time zone, the sitewide
      # "Demonstration only" banner, the CCT authorization workflows and the homepage blocks.
      # Colours, logo, hosts, SMTP and users are left as they are.
      class Organization < Base
        SOURCE_DOMAINS = %w(www.capetown.gov.za capetown.gov.za capetown.govocal.com openbylaws.org.za).freeze

        def call
          missing = LOCALES - Decidim.available_locales.map(&:to_s)
          raise Error, "Locales #{missing.join(", ")} are not enabled. Set DECIDIM_AVAILABLE_LOCALES=en,af,xh (plan U2)." if missing.any?

          organization.name = t(:labels, :org_name)
          organization.description = html(t(:labels, :org_description))
          organization.available_locales = LOCALES
          organization.default_locale = "en"
          organization.time_zone = TIME_ZONE
          organization.enable_omnipresent_banner = true
          organization.omnipresent_banner_title = t(:labels, :disclaimer_title)
          organization.omnipresent_banner_short_description = t(:labels, :disclaimer_body)
          organization.omnipresent_banner_url = "/pages/#{data.content.dig("pages", "about", "slug")}"
          organization.external_domain_allowlist = Array(organization.external_domain_allowlist) | SOURCE_DOMAINS
          organization.reference_prefix = "CCT" if organization.reference_prefix.blank?
          organization.available_authorizations = available_authorizations
          organization.save!
          log "organization #{organization.host}: #{organization.name["en"]} (#{LOCALES.join(", ")}, #{TIME_ZONE})"

          homepage!
        end

        private

        # Enables the CCT authorization workflows that are installed (ward residents, plan U4; user
        # groups, plan U5), keeping whatever else an admin has enabled.
        def available_authorizations
          installed = Decidim::Verifications.workflows.map(&:name)
          Array(organization.available_authorizations) | (Restrictions::WORKFLOWS & installed)
        end

        def homepage!
          Decidim::ContentBlocksCreator.new(organization).create_default!
          ensure_block(:highlighted_processes, 31)

          hero = Decidim::ContentBlock.find_by(organization:, scope_name: :homepage, manifest_name: :hero)
          return unless hero

          welcome = t(:labels, :hero_welcome).transform_keys { |locale| "welcome_text_#{locale}" }
          current = hero[:settings].to_h.stringify_keys
          return if welcome.keys.all? { |key| current[key].present? }

          hero.settings = current.merge(welcome) { |_key, old, new| old.presence || new }
          hero.save!
        end

        def ensure_block(manifest_name, weight)
          return if Decidim::ContentBlock.exists?(organization:, scope_name: :homepage, manifest_name:)
          return unless Decidim.content_blocks.for(:homepage).any? { |manifest| manifest.name == manifest_name }

          Decidim::ContentBlock.create!(organization:, scope_name: :homepage, manifest_name:, weight:, published_at: Time.current)
        end
      end
    end
  end
end
