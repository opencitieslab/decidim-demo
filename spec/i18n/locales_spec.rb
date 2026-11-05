# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CCT locales (en, af, xh)" do
  describe "configuration" do
    it "enables English, Afrikaans and isiXhosa" do
      expect(Decidim.available_locales).to eq(%w(en af xh))
      expect(I18n.available_locales).to include(:en, :af, :xh)
    end

    it "falls back from af and xh to English" do
      expect(I18n.fallbacks[:af]).to eq([:af, :en])
      expect(I18n.fallbacks[:xh]).to eq([:xh, :en])
    end

    it "names each language in that language" do
      expect(I18n.t("locale.name", locale: :en)).to eq("English")
      expect(I18n.t("locale.name", locale: :af)).to eq("Afrikaans")
      expect(I18n.t("locale.name", locale: :xh)).to eq("isiXhosa")
    end

    it "loads the cct namespace in every locale" do
      %i(en af xh).each do |locale|
        expect(I18n.exists?("cct.demo_label", locale)).to be(true)
      end
    end
  end

  describe "fallback for keys missing in af/xh" do
    before do
      I18n.backend.store_translations(:en, cct_spec: { only_in_english: "Only in English" })
    end

    it "returns the English text, not a missing-translation marker" do
      %i(af xh).each do |locale|
        expect(I18n.t("cct_spec.only_in_english", locale:)).to eq("Only in English")
        # The view helper raises on missing translations in test; a fallback must not raise.
        I18n.with_locale(locale) do
          expect(ApplicationController.helpers.t("cct_spec.only_in_english")).to eq("Only in English")
        end
      end
    end

    it "resolves Decidim's own strings in af/xh (translated or English fallback)" do
      %i(af xh).each do |locale|
        expect(I18n.exists?("layouts.decidim.language_chooser.choose_language", locale)).to be(true)
        expect(I18n.t("layouts.decidim.language_chooser.choose_language", locale:)).not_to match(/translation missing/i)
      end
    end
  end

  describe "isiXhosa Rails base" do
    let(:date) { Date.new(2026, 11, 5) } # a Thursday

    it "localises dates with isiXhosa month and day names" do
      expect(I18n.l(date, format: :long, locale: :xh)).to eq("05 Novemba 2026")
      expect(I18n.l(date, format: :decidim_with_day_and_month_name, locale: :xh)).to eq("Lwesine 05 Nov 2026")
      expect(I18n.l(date, format: :decidim_with_month_name, locale: :xh)).to eq("05 Novemba 2026")
    end

    it "localises times without raising" do
      time = Time.utc(2026, 3, 2, 14, 30)
      expect(I18n.l(time, format: :decidim_day_of_year, locale: :xh)).to eq("02 Matshi 2026")
      expect(I18n.l(time, format: :long, locale: :xh)).to eq("02 Matshi 2026 14:30")
      expect { I18n.l(time, locale: :xh) }.not_to raise_error
    end

    it "runs the Rails date helpers in xh without raising" do
      I18n.with_locale(:xh) do
        helpers = ApplicationController.helpers
        expect { helpers.time_ago_in_words(3.days.ago) }.not_to raise_error
        expect { helpers.distance_of_time_in_words(Time.current, 2.hours.from_now) }.not_to raise_error
      end
    end

    it "formats numbers South African style" do
      expect(ActiveSupport::NumberHelper.number_to_delimited(1_234_567.5, locale: :xh)).to eq("1 234 567.5")
      expect(ActiveSupport::NumberHelper.number_to_currency(1_000_000, locale: :xh)).to eq("R1 000 000.00")
    end

    it "pluralises with one/other" do
      I18n.backend.store_translations(:xh, cct_spec: { wards: { one: "iwadi e-%{count}", other: "iiwadi ezi-%{count}" } })
      expect(I18n.t("cct_spec.wards", count: 1, locale: :xh)).to eq("iwadi e-1")
      expect(I18n.t("cct_spec.wards", count: 118, locale: :xh)).to eq("iiwadi ezi-118")
    end

    it "joins lists" do
      expect(I18n.with_locale(:xh) { %w(a b c).to_sentence }).to eq("a, b, kunye c")
    end
  end

  describe "public pages", type: :request do
    let(:organization) { create(:organization, available_locales: %w(en af xh), default_locale: "en") }

    before do
      host! organization.host
      https! # Decidim forces SSL outside development
    end

    # Decidim 0.32 serves pages under a locale path prefix (/af/, /xh/) and redirects to it.
    def get_following_redirects(path, params = {})
      get(path, params:)
      3.times { response.redirect? ? follow_redirect! : break }
    end

    %w(af xh).each do |locale|
      it "renders the home page under /#{locale}/ with a language chooser naming all three languages" do
        get "/#{locale}/"

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/<html lang="#{locale}"/)
        expect(response.body).to include(">Afrikaans<", ">isiXhosa<", ">English<")
        expect(response.body).not_to match(/translation[ _]missing/i)
      end

      it "redirects ?locale=#{locale} to the #{locale} home page" do
        get_following_redirects("/", locale:)

        expect(response).to have_http_status(:ok)
        expect(request.path).to match(%r{\A/#{locale}/?\z})
        expect(response.body).to match(/<html lang="#{locale}"/)
      end
    end

    it "remembers the language chosen with the language chooser" do
      post "/locale", params: { locale: "xh" }
      get_following_redirects("/")

      expect(response.body).to match(/<html lang="xh"/)
    end

    it "ignores a locale the organization has not enabled" do
      get_following_redirects("/", locale: "ca")

      expect(response.body).to match(/<html lang="en"/)
    end
  end

  describe "system organization form" do
    let(:params) do
      {
        name: "City of Cape Town Test",
        short_name: "CCTTest",
        host: "cct.example.org",
        reference_prefix: "CCT",
        organization_admin_name: "Test Admin",
        organization_admin_email: "admin@example.org",
        available_locales: %w(en af xh),
        default_locale: "en",
        users_registration_mode: "enabled",
        force_users_to_authenticate_before_access_organization: "false",
        file_upload_settings: upload_params(Decidim::OrganizationSettings.default(:upload))
      }
    end

    # Same shape the system form posts (arrays as comma lists), as in decidim-system's specs.
    def upload_params(hash)
      hash.to_h do |key, value|
        value = upload_params(value) if value.is_a?(Hash)
        value = value.join(",") if value.is_a?(Array)
        [key, value]
      end
    end

    it "creates an organization with available locales en, af and xh" do
      form = Decidim::System::RegisterOrganizationForm.new(params)
      expect(form).to be_valid

      expect { Decidim::System::CreateOrganization.call(form) }.to broadcast(:ok)

      organization = Decidim::Organization.find_by!(host: "cct.example.org")
      expect(organization.available_locales).to eq(%w(en af xh))
      expect(organization.default_locale).to eq("en")
    end
  end
end
