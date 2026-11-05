# frozen_string_literal: true

# Loaded by factory_bot_rails. Pulls in Decidim's factories (core, participatory
# processes, assemblies, comments and the dev dummy component come with core) plus
# the modules the CCT demo builds on.
require "decidim/core/test/factories"
require "decidim/proposals/test/factories"
require "decidim/budgets/test/factories"
require "decidim/meetings/test/factories"
require "decidim/surveys/test/factories"

# Participant groups (plan U5).
FactoryBot.define do
  factory :cct_group, class: "Cct::Groups::Group" do
    organization
    sequence(:slug) { |n| "group-#{n}" }
    name { { "en" => "Group #{slug}", "af" => "Groep #{slug}", "xh" => "Iqela #{slug}" } }
    description { { "en" => "A demo group" } }
  end

  factory :cct_group_membership, class: "Cct::Groups::Membership" do
    group factory: :cct_group
    user { association :user, :confirmed, organization: group.organization }
  end
end
