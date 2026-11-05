# frozen_string_literal: true

require "rails_helper"

# Plan U5/U6: `cct:seed` creates the demo groups of demo_content.yml with their fictional members,
# enables the group workflow and limits the short-term letting by-law proposals to the ward
# committee; `reset_demo_content` removes the groups again.
RSpec.describe "CCT seed: demo groups" do
  let(:organization) { create(:organization, host: "cct-groups.lvh.me", available_locales: %w(en), default_locale: "en", available_authorizations: ["id_documents"]) }
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }
  let(:content) { YAML.safe_load_file(Cct::Seed.default_content_path) }
  let(:committee_slug) { content["groups"].first["key"] }

  def seed! = Cct::Seed.run(host: organization.host, logger:)

  def groups = Cct::Groups.for(organization)

  def snapshot
    {
      groups: groups.order(:slug).pluck(:slug, :name),
      memberships: Cct::Groups::Membership.where(group: groups).count,
      authorizations: Decidim::Authorization.where(name: Cct::Groups::WORKFLOW).count
    }
  end

  it "creates the demo groups with their fictional members, idempotently, and restricts the by-law proposals" do
    seed!

    expect(organization.reload.available_authorizations).to include("cct_group_membership", "cct_ward_resident", "id_documents")
    expect(groups.pluck(:slug)).to match_array(content["groups"].map { |group| group["key"] })
    expect(groups).to all(be_seeded)
    groups.each do |group|
      %w(en af xh).each { |locale| expect(group.name[locale]).to be_present, "#{group.slug} #{locale}" }
      entry = content["groups"].find { |candidate| candidate["key"] == group.slug }
      expect(group.users.count).to eq(entry["members"].size)
      expect(group.users).to all(satisfy { |user| user.email.end_with?("@example.org") && user.extended_data.key?(Cct::Seed::MARKER) })
    end
    expect(log.string).to include("groups: 3 demo groups", "group restriction: short-term-letting-bylaw proposals limited to the #{committee_slug} group")

    counts = snapshot
    seed!
    expect(snapshot).to eq(counts)

    # End to end: only committee members may create (or support) proposals in the by-law consultation.
    process = Decidim::ParticipatoryProcess.find_by!(organization:, slug: "short-term-letting-bylaw")
    component = process.components.where(manifest_name: "proposals").find_by!("name ->> 'en' = ?", content.dig("components", "proposals", "en"))
    committee = groups.find_by!(slug: committee_slug)
    member = committee.users.first
    ngo_member = groups.find_by!(slug: "cape-flats-ngo-forum").users.first
    outsider = create(:user, :confirmed, organization:)

    status = ->(user, action = "create") { Decidim::ActionAuthorizer.new(user, action, component, nil).authorize }
    expect(status.call(member)).to be_ok
    expect(status.call(member, "vote")).to be_ok
    expect(status.call(ngo_member).global_code).to eq(:unauthorized)
    expect(status.call(outsider).global_code).to eq(:unauthorized)

    # An admin adds the outsider to the committee: they may now propose.
    Cct::Groups.add_member!(committee, outsider)
    expect(status.call(outsider)).to be_ok

    # Reset removes the demo groups; the outsider (a real user) loses the access they gave.
    Cct::Seed.reset_demo_content(host: organization.host, logger:)
    expect(groups).to be_empty
    expect(Cct::Groups.authorization_for(outsider)).to be_nil
    expect(status.call(outsider).global_code).to eq(:unauthorized)

    seed!
    expect(groups.count).to eq(3)
  end

  it "leaves a group with a demo slug that an admin created alone" do
    real = create(:cct_group, organization:, slug: committee_slug, name: { "en" => "Real committee" })

    seed!

    expect(real.reload.name).to eq("en" => "Real committee")
    expect(real).not_to be_seeded
    expect(real.users).to be_empty
    expect(log.string).to include("#{committee_slug} exists and was not created by the seed")
  end
end
