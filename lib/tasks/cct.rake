# frozen_string_literal: true

# City of Cape Town demo tasks (plan U6). See lib/cct/seed.rb.
#
#   bin/rails cct:seed                         # idempotent: create or update the CCT demo
#   bin/rails cct:seed:reset_demo_content      # delete the fictional layer only
#
# Environment:
#   CCT_SEED_HOST     organization host (required when there is more than one organization)
#   CCT_SEED_SOURCES  real-data JSON   (default db/seeds/cct/cct-seed-sources.json)
#   CCT_SEED_CONTENT  demo content YAML (default db/seeds/cct/demo_content.yml)
namespace :cct do
  desc "Seed (or update) the City of Cape Town demo: real CCT data plus labelled fictional content"
  task seed: :environment do
    Cct::Seed.run(sources: ENV.fetch("CCT_SEED_SOURCES", nil), content: ENV.fetch("CCT_SEED_CONTENT", nil),
                  host: ENV.fetch("CCT_SEED_HOST", nil))
  rescue Cct::Seed::Error => e
    abort("cct:seed: #{e.message}")
  end

  namespace :seed do
    desc "Delete the seeded fictional users and everything they authored (real-data records stay)"
    task reset_demo_content: :environment do
      Cct::Seed.reset_demo_content(content: ENV.fetch("CCT_SEED_CONTENT", nil), host: ENV.fetch("CCT_SEED_HOST", nil))
    rescue Cct::Seed::Error => e
      abort("cct:seed:reset_demo_content: #{e.message}")
    end
  end
end
