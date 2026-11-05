# frozen_string_literal: true

require "erb"
require "uri"

module Cct
  module Seed
    # Builds the small amount of HTML the seed writes into Decidim's rich-text fields.
    # Every piece of data is HTML-escaped; links are emitted only for https URLs on an
    # allow-list of public sources (.ai/security.md §4). Decidim still sanitizes rich text on render.
    module Html
      ALLOWED_LINK_HOSTS = %w(
        www.capetown.gov.za capetown.gov.za resource.capetown.gov.za web1.capetown.gov.za
        capetown.govocal.com openbylaws.org.za
        odp-cctegis.opendata.arcgis.com esapqa.capetown.gov.za
        www.ewn.co.za ewn.co.za capeargus.co.za novanews.co.za
      ).freeze

      module_function

      def escape(text) = ERB::Util.html_escape(text.to_s)

      def paragraph(text) = "<p>#{escape(text)}</p>"

      # Returns the URL when it is an https URL on an allowed host, otherwise nil.
      def safe_url(url)
        uri = URI.parse(url.to_s.strip)
        return unless uri.is_a?(URI::HTTPS) && uri.userinfo.nil?
        return unless ALLOWED_LINK_HOSTS.include?(uri.host.to_s.downcase)

        uri.to_s
      rescue URI::InvalidURIError
        nil
      end

      def link(url, text = url)
        url = safe_url(url)
        return escape(text) unless url

        %(<a href="#{escape(url)}" target="_blank" rel="noopener noreferrer">#{escape(text)}</a>)
      end

      # Maps a {locale => text} hash to {locale => "<p>text</p>"}.
      def paragraphs(translations)
        translations.transform_values { |text| paragraph(text) }
      end
    end
  end
end
