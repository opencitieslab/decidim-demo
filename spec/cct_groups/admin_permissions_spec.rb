# frozen_string_literal: true

require "rails_helper"

# Plan U5 / .ai/security.md §1-2: every admin endpoint of the participant groups (Admin >
# Participants > Groups) is open to organization admins only, and only for their own
# organization's records.
RSpec.describe "Participant groups admin permissions", type: :request do
  let(:workflow) { Cct::Groups::WORKFLOW }
  let(:organization) { create(:organization, available_locales: %w(en af xh), default_locale: "en", available_authorizations: [workflow]) }
  let(:other_organization) { create(:organization, available_locales: %w(en), default_locale: "en", available_authorizations: [workflow]) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:participant) { create(:user, :confirmed, organization:) }
  let(:other_admin) { create(:user, :admin, :confirmed, organization: other_organization) }
  let!(:process) { create(:participatory_process, :published, organization:) }
  let!(:group) { create(:cct_group, organization:, slug: "ward-23-ward-committee") }
  let!(:member) { create(:user, :confirmed, organization:) }
  let!(:membership) do
    create(:cct_group_membership, group:, user: member).tap { Cct::Groups.sync!(member) }
  end
  let!(:candidate) { create(:user, :confirmed, organization:, email: "candidate@example.org") }
  let(:base) { "/en/admin/participant_groups" }
  let(:csv) { Rack::Test::UploadedFile.new(StringIO.new("email\ncandidate@example.org\n"), "text/csv", original_filename: "members.csv") }

  def token = SecureRandom.uuid

  # [verb, path, params, change] for every admin action. `change` is a lambda returning a value that
  # must stay the same when the request is denied.
  def actions(target = group, target_membership = membership)
    {
      "groups#index" => [:get, "#{base}/groups"],
      "groups#new" => [:get, "#{base}/groups/new"],
      "groups#create" => [:post, "#{base}/groups", { cct_group: { slug: "new-group", name_en: "New group" } }],
      "groups#edit" => [:get, "#{base}/groups/#{target.id}/edit"],
      "groups#update" => [:patch, "#{base}/groups/#{target.id}", { cct_group: { name_en: "Renamed" } }],
      "groups#destroy" => [:delete, "#{base}/groups/#{target.id}"],
      "members#index" => [:get, "#{base}/groups/#{target.id}/members"],
      "members#create" => [:post, "#{base}/groups/#{target.id}/members", { cct_group_member: { email: "candidate@example.org" } }],
      "members#destroy" => [:delete, "#{base}/groups/#{target.id}/members/#{target_membership.id}"],
      "members_imports#create" => [:post, "#{base}/groups/#{target.id}/members_import", { file: csv }],
      "alerts#index" => [:get, "#{base}/alerts"],
      "alerts#new" => [:get, "#{base}/alerts/new"],
      "alerts#create" => [:post, "#{base}/alerts",
                          { cct_group_alert: { group_id: target.id, space: "participatory_processes:#{process.id}", token: } }]
    }
  end

  def state
    [
      Cct::Groups::Group.order(:id).pluck(:id, :slug, :name),
      Cct::Groups::Membership.order(:id).pluck(:id, :cct_group_id, :decidim_user_id),
      Cct::Groups::Alert.count,
      Decidim::Authorization.where(name: Cct::Groups::WORKFLOW).count
    ]
  end

  def perform(verb, path, params = {})
    public_send(verb, path, params:)
  end

  before do
    host! organization.host
    https!
  end

  describe "an organization admin" do
    before { login_as admin, scope: :user }

    it "can use every action" do
      actions.except("groups#destroy").each do |name, (verb, path, params)|
        perform(verb, path, params || {})
        expect(response.status).to be_in([200, 302]), "#{name}: got #{response.status}"
        expect(response.location.to_s).not_to include("/users/sign_in"), name
        expect(flash[:alert]).to be_nil, "#{name}: #{flash[:alert]}"
      end

      verb, path = actions.fetch("groups#destroy")
      perform(verb, path)
      expect(response).to redirect_to("#{base}/groups")
      expect(Cct::Groups::Group.exists?(group.id)).to be(false)
    end

    it "creates, renames, adds and removes members, imports, alerts and deletes" do
      post "#{base}/groups", params: { cct_group: { slug: "ngo-forum", name_en: "NGO forum", name_af: "NRO-forum" } }
      created = Cct::Groups::Group.find_by!(organization:, slug: "ngo-forum")
      expect(response).to redirect_to("#{base}/groups/#{created.id}/members")

      patch "#{base}/groups/#{created.id}", params: { cct_group: { name_en: "NGO forum (demo)", slug: "hijacked" } }
      expect(created.reload.name["en"]).to eq("NGO forum (demo)")
      expect(created.slug).to eq("ngo-forum")

      post "#{base}/groups/#{created.id}/members", params: { cct_group_member: { email: "CANDIDATE@example.org " } }
      expect(created.users).to eq([candidate])
      expect(Cct::Groups.authorization_for(candidate).metadata["groups"]).to eq(["ngo-forum"])

      delete "#{base}/groups/#{created.id}/members/#{created.memberships.sole.id}"
      expect(created.users.reload).to be_empty
      expect(Cct::Groups.authorization_for(candidate)).to be_nil

      post "#{base}/groups/#{created.id}/members_import", params: { file: csv }
      expect(response).to have_http_status(:ok)
      expect(created.users.reload).to eq([candidate])

      delete "#{base}/groups/#{created.id}"
      expect(Cct::Groups::Group.exists?(created.id)).to be(false)
      expect(Cct::Groups.authorization_for(candidate)).to be_nil

      logs = Decidim::ActionLog.where(resource_type: "Cct::Groups::Group", resource_id: created.id).order(:id).pluck(:action)
      expect(logs).to eq(%w(create update add_member remove_member import_members delete))
    end
  end

  describe "denied" do
    shared_examples "denies every action" do |expectation|
      it "leaves everything unchanged (#{expectation})" do
        actions.each do |name, (verb, path, params)|
          before_state = state
          login_as(current_login, scope: :user) if current_login # an error response drops the test session
          perform(verb, path, params || {})

          case expectation
          when :sign_in
            expect(response).to have_http_status(:found), name
            expect(response.location).to include("/users/sign_in"), name
          when :not_found
            expect(response).to have_http_status(:not_found), "#{name}: got #{response.status}"
          when :not_found_or_sign_in
            denied = response.status == 404 || response.location.to_s.include?("/users/sign_in")
            expect(denied).to be(true), "#{name}: got #{response.status} #{response.location}"
          when :forbidden
            expect(response).to have_http_status(:found), name
            expect(response.location.to_s).not_to include("participant_groups"), name
          end
          expect(state).to eq(before_state), name
        end
      end
    end

    let(:current_login) { nil }

    context "for an anonymous visitor" do
      it_behaves_like "denies every action", :sign_in
    end

    context "for a participant" do
      let(:current_login) { participant }

      it_behaves_like "denies every action", :not_found
    end

    context "for a group member" do
      let(:current_login) { member }

      it_behaves_like "denies every action", :not_found
    end

    context "for a participatory space admin (not an organization admin)" do
      let(:current_login) { create(:process_admin, participatory_process: process) }

      it_behaves_like "denies every action", :forbidden
    end

    context "for an admin of another organization on this organization's host" do
      let(:current_login) { other_admin }

      it_behaves_like "denies every action", :not_found_or_sign_in
    end

    context "for an admin of another organization, with this organization's ids" do
      before do
        host! other_organization.host
        login_as other_admin, scope: :user
      end

      it "gets a 404 for every id of this organization and changes nothing" do
        actions.each do |name, (verb, path, params)|
          next unless path.include?("/groups/#{group.id}") || name == "alerts#create"

          before_state = state
          login_as other_admin, scope: :user # a 404 response drops the test session
          perform(verb, path, params || {})
          if name == "alerts#create"
            expect(response).to have_http_status(:unprocessable_content), name
          else
            expect(response).to have_http_status(:not_found), "#{name}: got #{response.status}"
          end
          expect(state).to eq(before_state), name
        end
      end

      it "does not see this organization's groups in its list" do
        get "#{base}/groups"
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(group.slug)
      end
    end
  end

  describe "permissions class" do
    def allowed?(user, action, subject, context = {})
      permission_action = Decidim::PermissionAction.new(scope: :admin, action:, subject:)
      Cct::Groups::Admin::Permissions.new(user, permission_action, { current_organization: organization }.merge(context)).permissions.allowed?
    rescue Decidim::PermissionAction::PermissionNotSetError
      false
    end

    it "allows organization admins only, and only for their organization's records" do
      expect(allowed?(admin, :create, :cct_group)).to be(true)
      expect(allowed?(admin, :destroy, :cct_group, group:)).to be(true)
      expect(allowed?(admin, :destroy, :cct_group_member, group:, membership:)).to be(true)
      expect(allowed?(participant, :index, :cct_group)).to be(false)
      expect(allowed?(nil, :index, :cct_group)).to be(false)
      expect(allowed?(other_admin, :index, :cct_group)).to be(false)
      expect(allowed?(create(:user, :user_manager, :confirmed, organization:), :index, :cct_group)).to be(false)
      expect(allowed?(create(:user, :admin, :confirmed, organization:, admin_terms_accepted_at: nil), :index, :cct_group)).to be(false)

      foreign_group = create(:cct_group, organization: other_organization)
      expect(allowed?(admin, :update, :cct_group, group: foreign_group)).to be(false)
      expect(allowed?(admin, :unknown, :cct_group)).to be(false)
    end
  end

  describe "CSRF protection" do
    around do |example|
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    before { login_as admin, scope: :user }

    it "rejects a form post without a valid authenticity token" do
      expect do
        post "#{base}/groups", params: { cct_group: { slug: "csrf-group", name_en: "CSRF" } }
      end.not_to(change { Cct::Groups::Group.count })
      expect(response).to have_http_status(:unprocessable_content)

      login_as admin, scope: :user # the rejected request dropped the test session
      expect do
        post "#{base}/groups/#{group.id}/members", params: { cct_group_member: { email: "candidate@example.org" } }
      end.not_to(change { Cct::Groups::Membership.count })
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "admin menu" do
    it "shows Groups under Participants to organization admins" do
      login_as admin, scope: :user
      get "/en/admin/officializations"

      expect(response.body).to include("participant_groups/groups")
    end
  end
end
