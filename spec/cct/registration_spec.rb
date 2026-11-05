# frozen_string_literal: true

require "rails_helper"

# Plan U4: surname, ward and mobile number at sign-up and in the account page
# (lib/cct/decorators, app/views/cct/_resident_fields.html.erb), stored in users.extended_data.
RSpec.describe "CCT registration fields" do
  let(:organization) do
    create(:organization, available_locales: %w(en af xh), default_locale: "en",
                          available_authorizations: [Cct::WardResidency::WORKFLOW])
  end

  def ward_authorizations(user) = Decidim::Authorization.where(user:, name: Cct::WardResidency::WORKFLOW)

  describe Cct::Phone do
    {
      "082 123 4567" => "+27821234567",
      "0821234567" => "+27821234567",
      "+27 82 123 4567" => "+27821234567",
      "+27-82-123-4567" => "+27821234567",
      "0027821234567" => "+27821234567",
      "27821234567" => "+27821234567",
      "(071) 555 0000" => "+27715550000",
      "060 000 0000" => "+27600000000"
    }.each do |input, expected|
      it "normalises #{input.inspect} to #{expected}" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    ["12345", "021 400 1111", "0861234567", "+44 7700 900123", "082 123 456", "082 123 45678", "abc", "", nil,
     "<script>alert(1)</script>"].each do |input|
      it "rejects #{input.inspect}" do
        expect(described_class.normalize(input)).to be_nil
      end
    end
  end

  describe Cct::Wards do
    it "lists the 118 wards from the seed sources JSON, labelled with their subcouncil and area" do
      expect(described_class.numbers).to eq((1..118).to_a)
      ward = described_class.find(23)
      expect(ward.subcouncil).to eq(1)
      expect(described_class.label(ward)).to eq("Ward 23 — Subcouncil 1 (Atlantis, Mamre, Melkbosstrand…)")
      expect(I18n.with_locale(:af) { described_class.label(ward) }).to start_with("Wyk 23 — Subraad 1")
      expect(I18n.with_locale(:xh) { described_class.label(ward) }).to start_with("Iwadi 23 — iBhungana 1")
    end

    it "only accepts plain ward numbers between 1 and 118" do
      expect(described_class.valid?("57")).to be(true)
      expect(described_class.valid?(" 118 ")).to be(true)
      ["0", "119", "abc", "", nil, "23abc", "-1", "1.5", "23; DROP TABLE users"].each do |value|
        expect(described_class.valid?(value)).to be(false), "expected #{value.inspect} to be rejected"
      end
    end
  end

  describe "sign-up", type: :request do
    let(:params) do
      {
        user: {
          name: "Thandi Demo",
          email: "thandi@example.org",
          password: "Kx8#vR2!mQp7Lw4z",
          tos_agreement: "1",
          surname: "Mbeki",
          ward: "57",
          phone: "082 123 4567"
        }
      }
    end

    before do
      host! organization.host
      https!
    end

    def sign_up(**overrides)
      post "/en/users", params: { user: params[:user].merge(overrides) }
    end

    def new_user = Decidim::User.find_by(organization:, email: "thandi@example.org")

    it "shows the surname, ward and mobile fields in English, Afrikaans and isiXhosa" do
      { "en" => %w(Surname Ward Mobile), "af" => %w(Van Wyk Selfoonnommer), "xh" => %w(Ifani Iwadi Inombolo) }.each do |locale, labels|
        get "/#{locale}/users/sign_up"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="user[surname]"', 'name="user[ward]"', 'name="user[phone]"')
        labels.each { |label| expect(response.body).to include(label) }
        expect(response.body).not_to match(/translation[ _]missing/i)
      end
      expect(response.body.scan(/<option value="\d+"/).size).to eq(118)
      expect(response.body).to include("Iwadi 57 — iBhungana")
    end

    it "stores the normalised fields and grants the ward authorization" do
      expect { sign_up }.to change(Decidim::User, :count).by(1)

      user = new_user
      expect(user.extended_data).to include("surname" => "Mbeki", "ward" => 57, "phone_e164" => "+27821234567")
      expect(user.name).to eq("Thandi Demo")
      authorization = ward_authorizations(user).sole
      expect(authorization).to be_granted
      expect(authorization.metadata).to eq("ward" => 57)
    end

    it "accepts an empty surname and mobile number" do
      expect { sign_up(surname: "", phone: "") }.to change(Decidim::User, :count).by(1)

      expect(new_user.extended_data).to include("ward" => 57)
      expect(new_user.extended_data.keys).not_to include("surname", "phone_e164")
    end

    it "rejects an invalid mobile number with a field error and creates no user" do
      expect { sign_up(phone: "12345") }.not_to change(Decidim::User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is not a South African mobile number")
      expect(Decidim::Authorization.where(name: Cct::WardResidency::WORKFLOW)).to be_empty
    end

    ["0", "119", "abc"].each do |ward|
      it "rejects ward #{ward.inspect}" do
        expect { sign_up(ward:) }.not_to change(Decidim::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("is not a City of Cape Town ward")
      end
    end

    it "requires a ward" do
      expect { sign_up(ward: "") }.not_to change(Decidim::User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects markup in the surname" do
      expect { sign_up(surname: "<script>alert(1)</script>") }.not_to change(Decidim::User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("<script>alert(1)</script>")
    end

    describe "CSRF protection" do
      around do |example|
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it "rejects a sign-up POST without an authenticity token" do
        expect { sign_up }.not_to change(Decidim::User, :count)
        expect(Decidim::Authorization.where(name: Cct::WardResidency::WORKFLOW)).to be_empty
      end
    end
  end

  describe "sign-up to restricted vote, end to end", type: :request do
    let(:process) { create(:participatory_process, :with_steps, :published, organization:) }
    let(:component) { create(:budgets_component, :published, participatory_space: process) }
    let(:budget) do
      create(:budget, component:, total_budget: 1_000_000).tap do |budget|
        budget.create_resource_permission!(permissions: {
                                             "vote" => { "authorization_handlers" => {
                                               Cct::WardResidency::WORKFLOW => { "options" => { "allowed_wards" => "23" } }
                                             } }
                                           })
      end
    end
    let!(:project) { create(:project, budget:, budget_amount: 100_000) }
    let(:projects_path) { "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/projects" }

    before do
      host! organization.host
      https!
    end

    def register_and_vote(email, ward)
      post "/en/users", params: { user: { name: "Demo Resident", email:, password: "Kx8#vR2!mQp7Lw4z", tos_agreement: "1", ward: } }
      user = Decidim::User.find_by!(organization:, email:)
      user.update!(confirmed_at: Time.current)
      login_as user, scope: :user
      get projects_path
      body = response.body
      post "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/order/line_item",
           params: { project_id: project.id }, headers: { "Referer" => "https://#{organization.host}#{projects_path}" }
      [user, body]
    end

    it "lets a new ward 23 resident vote and stops a new ward 12 resident with an explanation" do
      resident, page = register_and_vote("ward23@example.org", "23")
      expect(page).not_to include('data-dialog-open="authorizationModal"')
      expect(Decidim::Budgets::Order.find_by(user: resident, budget:).projects).to eq([project])

      logout :user
      outsider, page = register_and_vote("ward12@example.org", "12")
      expect(page).to include('data-dialog-open="authorizationModal"')
      expect(Decidim::Budgets::Order.find_by(user: outsider, budget:)).to be_nil

      get "/authorization_modals/vote/f/#{component.id}/budget/#{budget.id}", params: { locale: "en" },
                                                                             headers: { "Referer" => "https://#{organization.host}#{projects_path}" }
      expect(response.body).to include("only open to residents of ward 23", "you live in ward 12")
    end
  end

  describe "account page", type: :request do
    let(:user) do
      create(:user, :confirmed, organization:, password: "Kx8#vR2!mQp7Lw4z",
                                extended_data: { "surname" => "Mbeki", "ward" => 57, "phone_e164" => "+27821234567" })
    end

    let(:account_params) do
      { user: { name: user.name, nickname: user.nickname, email: user.email, locale: "en",
                surname: "Mbeki", ward: "12", phone: "083 555 1234" } }
    end

    before do
      Cct::WardResidency.sync!(user)
      host! organization.host
      https!
      login_as user, scope: :user
    end

    it "shows the stored values" do
      get "/en/account"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Mbeki"', 'value="+27821234567"')
      expect(response.body).to match(/<option selected="selected" value="57">Ward 57 — /)
    end

    it "updates the fields and the ward authorization in place, without duplicating it" do
      original = ward_authorizations(user).sole

      put "/en/account", params: account_params

      expect(response).to redirect_to("/en/account")
      expect(user.reload.extended_data).to include("ward" => 12, "phone_e164" => "+27835551234", "surname" => "Mbeki")
      authorization = ward_authorizations(user).sole
      expect(authorization.id).to eq(original.id)
      expect(authorization.metadata).to eq("ward" => 12)
    end

    it "keeps the data and authorization when the update is invalid" do
      put "/en/account", params: account_params.deep_merge(user: { phone: "12345" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.extended_data).to include("ward" => 57, "phone_e164" => "+27821234567")
      expect(ward_authorizations(user).sole.metadata).to eq("ward" => 57)
    end

    it "removes the ward authorization when the ward is cleared" do
      put "/en/account", params: account_params.deep_merge(user: { ward: "", phone: "", surname: "" })

      expect(user.reload.extended_data.keys).not_to include("ward", "surname", "phone_e164")
      expect(ward_authorizations(user)).to be_empty
    end

    it "escapes a stored surname containing markup" do
      user.update!(extended_data: user.extended_data.merge("surname" => "<script>alert(1)</script>"))

      get "/en/account"

      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end
  end

  describe "privacy", type: :request do
    let(:user) do
      create(:user, :confirmed, organization:, name: "Thandi Demo",
                                extended_data: { "surname" => "Zuluprivate", "ward" => 57, "phone_e164" => "+27821234567" })
    end

    before do
      host! organization.host
      https!
    end

    it "never shows the surname or mobile number on the public profile" do
      get "/en/profiles/#{user.nickname}/activity"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Thandi Demo")
      expect(response.body).not_to include("Zuluprivate", "+27821234567", "082 123 4567")
    end

    it "does not expose extended data through the GraphQL user type" do
      fields = Decidim::Core::UserType.fields.keys.map(&:underscore)
      expect(fields).not_to include("extended_data", "surname", "phone", "phone_e164", "ward")

      post "/api", params: { query: "{ users { id name nickname } }" }
      expect(response.body).not_to include("Zuluprivate", "+27821234567")
    end
  end
end
