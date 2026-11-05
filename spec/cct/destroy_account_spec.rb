# frozen_string_literal: true

require "rails_helper"
require "csv"

# Plan U4 / R8 (POPIA): the surname, ward and mobile number are personal data. Account deletion
# removes them and the ward authorization; "download your data" gives them to their owner.
RSpec.describe "CCT personal data" do
  let(:organization) { create(:organization, available_locales: %w(en af xh), default_locale: "en") }
  let(:user) do
    create(:user, :confirmed, organization:,
                              extended_data: { "surname" => "Mbeki", "ward" => 57, "phone_e164" => "+27821234567", "other" => "kept" })
  end

  before { Cct::WardResidency.sync!(user) }

  describe Decidim::DestroyAccount do
    let(:form) { Decidim::DeleteAccountForm.from_params(delete_reason: "Moving away").with_context(current_user: user) }

    it "removes the surname, ward and mobile number and the ward authorization" do
      other_user = create(:user, :confirmed, organization:, extended_data: { "ward" => 57 })
      Cct::WardResidency.sync!(other_user)

      expect { described_class.call(form) }.to broadcast(:ok)

      user.reload
      expect(user).to be_deleted
      expect(user.extended_data).to eq("other" => "kept")
      expect(Decidim::Authorization.where(user:)).to be_empty
      expect(Cct::WardResidency.authorization_for(other_user)).to be_present
    end
  end

  describe "account deletion page", type: :request do
    before do
      host! organization.host
      https!
      login_as user, scope: :user
    end

    it "wipes the fields when the participant deletes their account" do
      delete "/en/account", params: { delete_reason: "" }

      expect(user.reload).to be_deleted
      expect(user.extended_data.keys).not_to include("surname", "ward", "phone_e164")
      expect(Cct::WardResidency.authorization_for(user)).to be_nil
    end
  end

  describe "download your data" do
    def user_rows(for_user)
      serializer = Decidim::User.export_serializer
      csv = Decidim::Exporters::CSV.new(Decidim::User.user_collection(for_user), serializer).export.read
      CSV.parse(csv, headers: true, col_sep: ";")
    end

    it "includes the three fields for the owner" do
      rows = user_rows(user)

      expect(rows.size).to eq(1)
      expect(rows.first.to_h).to include("surname" => "Mbeki", "ward" => "57")
      # Decidim's CSV exporter prefixes values starting with + = - @ (formula injection guard).
      expect(rows.first["phone_e164"]).to eq("'+27821234567")
    end

    it "contains only the requesting user's row" do
      create(:user, :confirmed, organization:, extended_data: { "surname" => "Someoneelse" })

      expect(user_rows(user).map { |row| row["id"] }).to eq([user.id.to_s])
    end

    it "documents the fields in the README of the archive" do
      help = Decidim::DownloadYourDataSerializers.help_definitions_for(user)
      expect(help["users"]).to include(surname: "Your surname", ward: "The ward you declared you live in",
                                       phone_e164: "Your mobile number, in international format")
    end

    it "builds the archive with the fields" do
      export = Decidim::DownloadYourDataExporter.new(user, "download_your_data", "CSV").export
      entries = {}
      Zip::File.open_buffer(export.file.download) { |zip| zip.each { |entry| entries[entry.name] = entry.get_input_stream.read } }

      users_csv = entries.find { |name, _| name.start_with?("decidim-users") }&.last
      expect(users_csv).to include("Mbeki", "+27821234567")
    end
  end
end
