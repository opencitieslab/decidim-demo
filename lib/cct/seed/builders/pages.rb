# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Ensures a terms-of-service page exists (created only if missing; an existing one is never
      # edited) and upserts the "About this demo" page that the sitewide banner links to.
      class Pages < Base
        TOS_SLUG = "terms-of-service"

        def call
          ensure_terms_of_service!
          upsert_about_page!
        end

        private

        def ensure_terms_of_service!
          return if Decidim::StaticPage.exists?(organization:, slug: TOS_SLUG)

          paragraphs = data.content.dig("pages", "terms", "paragraphs").map.with_index { |p, i| data.complete(p, "pages.terms.#{i}") }
          Decidim::StaticPage.create!(
            organization:,
            slug: TOS_SLUG,
            title: t(:pages, :terms, :title),
            content: join_html(paragraphs.map { |p| html(p) }),
            allow_public_access: true
          )
          log "created the #{TOS_SLUG} page"
        end

        def upsert_about_page!
          about = data.content.dig("pages", "about")
          page = Decidim::StaticPage.find_or_initialize_by(organization:, slug: about.fetch("slug"))
          paragraphs = about.fetch("paragraphs").map.with_index { |p, i| data.complete(p, "pages.about.#{i}") }
          heading = t(:pages, :about, :sources_heading)
          sources = source_urls.map { |url| "<li>#{Html.link(url)}</li>" }.join

          page.title = t(:pages, :about, :title)
          page.content = LOCALES.to_h do |locale|
            body = paragraphs.map { |p| Html.paragraph(p[locale]) }.join
            [locale, "#{body}<h3>#{Html.escape(heading[locale])}</h3><ul>#{sources}</ul>"]
          end
          page.allow_public_access = true
          page.save!
        end

        def source_urls
          sources = data.sources
          [
            sources.dig("subcouncils", 0, "sources", "wards"),
            sources.dig("subcouncils", 0, "sources", "office"),
            sources.dig("themes", 0, "source"),
            sources.dig("budget", "total_rand", "sources", 0),
            sources.dig("budget", "ward_allocations", "source"),
            sources.dig("datasets", "wards_item_page"),
            "https://capetown.govocal.com"
          ].compact.uniq.select { |url| Html.safe_url(url) }
        end

        def join_html(translations_list)
          LOCALES.index_with { |locale| translations_list.map { |tr| tr[locale] }.join }
        end
      end
    end
  end
end
