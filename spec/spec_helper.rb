# frozen_string_literal: true

# Plain RSpec settings that do not need Rails. Decidim's own RSpec configuration
# (factories, helpers, transactional fixtures, random order...) is loaded by
# spec/rails_helper.rb through decidim-dev.
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  # No disable_monkey_patching!: Decidim's shared examples are defined at top level.
end
