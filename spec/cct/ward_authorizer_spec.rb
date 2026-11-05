# frozen_string_literal: true

require "rails_helper"

# Plan U4 / KTD5: the `cct_ward_resident` workflow and its `allowed_wards` action authorizer
# (config/initializers/cct.rb, lib/cct/authorizations, lib/cct/ward_resident).
RSpec.describe Cct::Authorizations::WardActionAuthorizer do
  let(:workflow) { Cct::WardResidency::WORKFLOW }
  let(:organization) do
    create(:organization, available_locales: %w(en af xh), default_locale: "en", available_authorizations: [workflow])
  end
  let(:process) { create(:participatory_process, :with_steps, :published, organization:) }
  let(:component) { create(:budgets_component, :published, participatory_space: process) }
  let(:budget) { create(:budget, component:, total_budget: 1_000_000) }
  let!(:project) { create(:project, budget:, budget_amount: 100_000) }
  let(:allowed_wards) { "23" }

  def resident(ward, org = organization)
    create(:user, :confirmed, organization: org, extended_data: ward ? { "ward" => ward } : {}).tap do |user|
      Cct::WardResidency.sync!(user)
    end
  end

  def restrict!(holder, wards = allowed_wards)
    permissions = { "vote" => { "authorization_handlers" => { workflow => { "options" => { "allowed_wards" => wards } } } } }
    if holder.is_a?(Decidim::Component)
      holder.update!(permissions:)
    else
      (holder.resource_permission || holder.build_resource_permission).update!(permissions:)
    end
  end

  def status_for(user, resource: budget)
    Decidim::ActionAuthorizer.new(user, "vote", component, resource).authorize
  end

  def messages(status_collection)
    status_collection.statuses.flat_map do |status|
      Array(status.data[:extra_explanation]).map { |extra| I18n.t(extra[:key], **extra[:params]) }
    end
  end

  before { restrict!(budget) }

  it "is registered as a non-self-service workflow with an allowed_wards option" do
    manifest = Decidim::Verifications.find_workflow_manifest(workflow)
    expect(manifest.type).to eq("multistep")
    expect(manifest.form).to be_nil
    expect(manifest.renewable).to be(false)
    expect(manifest.options.attributes.keys.map(&:to_s)).to eq(["allowed_wards"])
    expect(Decidim.authorization_handlers.map(&:name)).not_to include(workflow) # no direct handler form
  end

  it "lets a ward 23 resident vote in a budget restricted to ward 23" do
    expect(status_for(resident(23))).to be_ok
  end

  it "accepts a comma list of wards" do
    restrict!(budget, " 8, 23 ;44 ")
    expect(status_for(resident(44))).to be_ok
    expect(status_for(resident(12))).not_to be_ok
  end

  it "refuses a ward 12 resident with an explanation naming the allowed ward and theirs" do
    status = status_for(resident(12))

    expect(status).not_to be_ok
    expect(status.global_code).to eq(:unauthorized)
    expect(status.statuses.first.data[:action]).to eq(:update_ward)
    expect(messages(status).join).to eq(
      "This action is only open to residents of ward 23. Your account says you live in ward 12. " \
      "If you have moved, update your ward in your account."
    )
  end

  it "asks a participant without a ward to set it in their account" do
    status = status_for(resident(nil))

    expect(status.codes).to eq([:missing])
    expect(status.statuses.first.data[:action]).to eq(:set_ward)
    expect(messages(status).join).to include("only open to residents of ward 23", "Add your ward to your account")
  end

  it "treats an anonymous visitor as missing the authorization (the UI asks them to sign in first)" do
    expect(status_for(nil).codes).to eq([:missing])
  end

  it "allows any resident when no wards are listed" do
    restrict!(budget, "")
    expect(status_for(resident(12))).to be_ok
    expect(status_for(resident(nil)).codes).to eq([:missing])
  end

  it "applies to component-level permissions too" do
    restrict!(component)
    expect(status_for(resident(23), resource: nil)).to be_ok
    expect(status_for(resident(12), resource: nil).global_code).to eq(:unauthorized)
  end

  it "is ignored when the organization has not enabled the workflow" do
    component.organization.update!(available_authorizations: [])
    expect(status_for(resident(12))).to be_ok
  end

  describe "organization isolation" do
    let(:other_organization) do
      create(:organization, available_locales: %w(en), default_locale: "en", available_authorizations: [workflow])
    end
    let(:other_process) { create(:participatory_process, :with_steps, :published, organization: other_organization) }
    let(:other_component) { create(:budgets_component, :published, participatory_space: other_process) }
    let(:other_budget) { create(:budget, component: other_component) }

    it "never matches an authorization from another organization" do
      ward_23_in_a = resident(23)
      user_in_b = create(:user, :confirmed, organization: other_organization, email: ward_23_in_a.email)
      restrict!(other_budget)

      status = Decidim::ActionAuthorizer.new(user_in_b, "vote", other_component, other_budget).authorize
      expect(status.codes).to eq([:missing])
      expect(Decidim::Verifications::Authorizations.new(organization: other_organization, name: workflow).query).to be_empty
      expect(Decidim::Verifications::Authorizations.new(organization:, name: workflow).query.map(&:user)).to eq([ward_23_in_a])
    end
  end

  describe "pages", type: :request do
    let(:referer) { { "Referer" => "https://#{organization.host}/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/projects" } }

    before do
      host! organization.host
      https!
    end

    it "shows the restriction in the authorization modal for a resident of another ward" do
      login_as resident(12), scope: :user

      get "/authorization_modals/vote/f/#{component.id}/budget/#{budget.id}", params: { locale: "en" }, headers: referer

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("This action is only open to residents of ward 23", "you live in ward 12", "Update your ward")
    end

    it "shows the restriction in Afrikaans and isiXhosa too" do
      user = resident(12)
      user.update!(locale: "af")
      login_as user, scope: :user

      get "/authorization_modals/vote/f/#{component.id}/budget/#{budget.id}", params: { locale: "af" }, headers: referer
      expect(response.body).to include("net oop vir inwoners van wyk 23", "Werk jou wyk by")

      get "/authorization_modals/vote/f/#{component.id}/budget/#{budget.id}", params: { locale: "xh" }, headers: referer
      expect(response.body).to include("kubahlali bewadi 23", "Hlaziya iwadi yakho")
    end

    it "asks an anonymous visitor to sign in before voting" do
      get "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-dialog-open="loginModal"')
      expect(response.body).not_to include('data-dialog-open="authorizationModal"')
    end

    describe "budget-level restriction enforced on the vote endpoints" do
      let(:line_item_path) { "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/order/line_item" }
      let(:checkout_path) { "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{budget.id}/order/checkout" }

      def orders = Decidim::Budgets::Order.where(budget:)

      it "lets a ward 23 resident add a project to their vote" do
        login_as resident(23), scope: :user

        post line_item_path, params: { project_id: project.id }, headers: referer

        expect(orders.sole.projects).to eq([project])
      end

      it "refuses a ward 12 resident who posts to the endpoint directly" do
        login_as resident(12), scope: :user

        post line_item_path, params: { project_id: project.id }, headers: referer

        expect(orders).to be_empty
        expect(flash[:alert]).to be_present
      end

      it "refuses checkout of an order for a restricted budget" do
        user = resident(12)
        create(:order, budget:, user:).tap { |order| order.projects << project }
        login_as user, scope: :user

        post checkout_path, headers: referer

        expect(orders.sole.checked_out_at).to be_nil
      end

      it "keeps unrestricted budgets in the same component open" do
        other_budget = create(:budget, component:, total_budget: 1_000_000)
        other_project = create(:project, budget: other_budget, budget_amount: 100_000)
        login_as resident(12), scope: :user

        post "/en/processes/#{process.slug}/f/#{component.id}/budgets/#{other_budget.id}/order/line_item",
             params: { project_id: other_project.id }, headers: referer

        expect(Decidim::Budgets::Order.where(budget: other_budget).sole.projects).to eq([other_project])
      end
    end

    it "sends a signed-in participant from the workflow entry point to the ward field of their account" do
      login_as resident(nil), scope: :user

      get "/en/cct_ward_resident"

      expect(response).to redirect_to("/en/account#user_ward")
      expect(flash[:notice]).to include("Set or update your ward")
    end

    it "requires sign-in for the workflow entry point" do
      get "/en/cct_ward_resident"

      expect(response).to have_http_status(:found)
      expect(response.location).to include("/users/sign_in")
    end
  end
end
