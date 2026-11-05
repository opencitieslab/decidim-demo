# frozen_string_literal: true

# Attach the branded demo images (logo, favicon, homepage hero, process banners).
#   bin/rails cct:seed:images        (idempotent; CCT_SEED_HOST selects the organization)
namespace :cct do
  namespace :seed do
    desc "Attach branded demo images to the organization, homepage hero and seeded processes"
    task images: :environment do
      organizations = Decidim::Organization.all
      host = ENV.fetch("CCT_SEED_HOST", nil)
      organization = host ? organizations.find_by(host:) : (organizations.one? ? organizations.first : nil)
      abort("cct:seed:images: set CCT_SEED_HOST (none or several organizations found)") unless organization

      data = Cct::Seed::Data.new(
        sources_path: ENV.fetch("CCT_SEED_SOURCES", Rails.root.join("db/seeds/cct/cct-seed-sources.json").to_s),
        content_path: ENV.fetch("CCT_SEED_CONTENT", Rails.root.join("db/seeds/cct/demo_content.yml").to_s)
      )
      Cct::Seed::Images.new(organization:, data:, logger: Logger.new($stdout)).call
    end
  end
end
