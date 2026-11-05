# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Test harness" do
  it "runs against the isolated test database" do
    expect(Rails.env).to eq("test")
    expect(ActiveRecord::Base.connection_db_config.database).to eq("decidim_demo_test")
  end

  it "creates an organization and a user with Decidim's factories" do
    organization = create(:organization, available_locales: %w(en af xh), default_locale: "en")
    user = create(:user, :confirmed, organization:)

    expect(organization).to be_persisted
    expect(user).to be_persisted
    expect(user.organization).to eq(organization)
    expect(Decidim::User.where(organization:).count).to eq(1)
  end
end
