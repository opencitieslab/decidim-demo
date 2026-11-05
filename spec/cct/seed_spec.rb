# frozen_string_literal: true

require "rails_helper"
require "json"
require "yaml"

# Plan U6: the idempotent CCT real-data seed (lib/cct/seed, lib/tasks/cct.rake).
RSpec.describe Cct::Seed do
  let(:organization) { create(:organization, host: "cct.lvh.me", available_locales: %w(en), default_locale: "en") }
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }
  let(:sources) { JSON.parse(File.read(described_class.default_sources_path)) }
  let(:content) { YAML.safe_load_file(described_class.default_content_path) }
  let(:item_slugs) { content["items"].keys }

  def seed!(**) = described_class.run(host: organization.host, logger:, **)

  def processes = Decidim::ParticipatoryProcess.where(organization:)

  def item_processes = processes.where(slug: item_slugs)

  def area_root = Decidim::Taxonomy.roots.where(organization:).find_by("name ->> 'en' = 'Area'")

  def components = Decidim::Component.where(participatory_space: processes)

  def proposals = Decidim::Proposals::Proposal.where(component: components)

  def fictional_users = described_class.fictional_users(organization)

  def snapshot
    {
      taxonomies: Decidim::Taxonomy.where(organization:).count,
      filters: Decidim::TaxonomyFilter.for(organization).count,
      processes: processes.count,
      groups: Decidim::ParticipatoryProcessGroup.where(organization:).count,
      steps: Decidim::ParticipatoryProcessStep.where(participatory_process: processes).count,
      components: components.count,
      proposals: proposals.count,
      states: Decidim::Proposals::ProposalState.where(component: components).count,
      supports: Decidim::Proposals::ProposalVote.where(proposal: proposals).count,
      comments: Decidim::Comments::Comment.where(decidim_participatory_space_id: processes.ids).count,
      meetings: Decidim::Meetings::Meeting.where(component: components).count,
      budgets: Decidim::Budgets::Budget.where(component: components).count,
      projects: Decidim::Budgets::Project.where(budget: Decidim::Budgets::Budget.where(component: components)).count,
      questions: Decidim::Forms::Question.count,
      users: Decidim::User.where(organization:).count,
      pages: Decidim::StaticPage.where(organization:).count
    }
  end

  # Copies a data file into a temp dir after letting the block change its parsed content.
  def temp_copy(path, format)
    dir = Dir.mktmpdir("cct-seed")
    copy = File.join(dir, File.basename(path))
    parsed = format == :json ? JSON.parse(File.read(path)) : YAML.safe_load_file(path)
    yield parsed
    File.write(copy, format == :json ? JSON.generate(parsed) : parsed.to_yaml)
    copy
  end

  def translatable_values(record, *fields)
    fields.map { |field| record.public_send(field) }.compact.reject { |value| value.is_a?(Hash) && value.empty? }
  end

  def expect_trilingual(value, context)
    %w(en af xh).each do |locale|
      expect(value[locale].to_s.strip).to be_present, "#{context}: missing #{locale}"
    end
  end

  describe "on an empty database" do
    before { seed! }

    it "builds the areas, themes and directorates as taxonomies" do
      subcouncils = area_root.children
      wards = Decidim::Taxonomy.where(parent: subcouncils)

      expect(subcouncils.count).to eq(20)
      expect(wards.count).to eq(118)
      expect(wards.map { |w| w.name["en"][/\AWard (\d+)/, 1].to_i }.sort).to eq((1..118).to_a)
      expect(wards.find { |w| w.name["en"].start_with?("Ward 117 ") }.name["en"]).to include("inferred")
      expect(wards.find { |w| w.name["en"].start_with?("Ward 118 ") }.name["en"]).to include("unverified")
      expect(wards.find { |w| w.name["en"] == "Ward 23" }.parent.name["en"]).to eq("Subcouncil 1")

      theme_root = Decidim::Taxonomy.roots.where(organization:).find_by("name ->> 'en' = 'Theme'")
      expect(theme_root.children.count).to eq(9)
      expect(Decidim::TaxonomyFilter.for(organization).count).to eq(3)
    end

    it "creates one published process per real item, plus the ward allocations process" do
      expect(item_processes.count).to eq(25)
      expect(processes.count).to eq(26)
      expect(processes.published.count).to eq(26)
      expect(item_processes.map { |p| p.participatory_process_group&.title&.dig("en") }.uniq).to eq(["Have your say 2025–26"])
      expect(components.where(published_at: nil)).to be_empty

      sources.fetch("items").each do |item|
        process = item_processes.find { |p| p.title["en"] == item["title"] }
        expect(process).to be_present, "no process for #{item["title"]}"
        expect(process.description["en"]).to include(%(href="#{ERB::Util.html_escape(item["url"])}"))
        expect(process.start_date).to eq(Date.parse(item.dig("dates", "open")))
        expect(process.steps.where(active: true).count).to eq(1)
        expect(process.taxonomies.map { |t| t.root_taxonomy.name["en"] }).to include("Theme", "Directorate")
      end
      expect(components.where(manifest_name: "proposals").all? { |c| c.settings.taxonomy_filters.size == 2 }).to be(true)
    end

    it "creates ward budgets with the real sample projects, meetings at the subcouncil offices and the demo users" do
      budgets = Decidim::Budgets::Budget.where(component: components)
      expect(budgets.count).to eq(5)
      expect(budgets.map(&:total_budget).uniq).to eq([1_000_000])
      project_titles = Decidim::Budgets::Project.where(budget: budgets).map { |p| p.title["en"] }
      expect(project_titles).to include("Traffic calming - Ward 23", "Cox Park - upgrade", "Hout Bay Common - upgrade")
      expect(Decidim::Budgets::Project.where(budget: budgets).find { |p| p.title["en"] == "Cox Park - upgrade" }.description["en"])
        .to include("Indicative amount: R250,000")

      meetings = Decidim::Meetings::Meeting.where(component: components)
      offices = sources.fetch("subcouncils").map { |s| s["office_address"].sub(/\s*\(as published[^)]*\)\z/, "") }
      expect(meetings.count).to be >= 30
      expect(meetings.where(type_of_meeting: "in_person").count).to eq(meetings.count)
      expect(meetings.map(&:address) - offices - [Cct::Seed::Builders::Meetings::CIVIC_CENTRE]).to be_empty
      expect(meetings.map { |m| m.start_time.to_date }).to all(be_between(Date.new(2026, 11, 1), Date.new(2027, 3, 31)))

      expect(fictional_users.count).to eq(30)
      expect(proposals.count).to be > 100
    end

    it "marks every fictional record and keeps all seeded emails on example.org" do
      expect(Decidim::User.where(organization:).where.not("email LIKE ?", "%@example.org")).to be_empty
      expect(fictional_users.map(&:name)).to all(end_with("· demo"))
      expect(fictional_users.map { |u| u.extended_data.dig("cct_seed", "fictional") }).to all(be(true))

      participant_proposals = proposals.where(participatory_text_level: nil)
      participant_proposals.each do |proposal|
        expect(proposal.authors).to all(satisfy { |author| author.is_a?(Decidim::User) && author.extended_data.has_key?("cct_seed") })
      end
      comments = Decidim::Comments::Comment.where(decidim_participatory_space_id: processes.ids)
      expect(comments.map(&:author)).to all(satisfy { |author| author.extended_data.has_key?("cct_seed") })
      answered = participant_proposals.where.not(answer: nil)
      expect(answered).not_to be_empty
      expect(answered.map { |p| p.answer["en"] }).to all(include("Fictional response written for this demo"))
    end

    it "gives every seeded translatable field English, Afrikaans and isiXhosa text" do
      checks = []
      checks << ["organization", translatable_values(organization.reload, :name, :description, :omnipresent_banner_title)]
      Decidim::Taxonomy.where(organization:).find_each { |t| checks << ["taxonomy #{t.id}", [t.name]] }
      processes.each { |p| checks << ["process #{p.slug}", translatable_values(p, :title, :subtitle, :short_description, :description, :announcement)] }
      Decidim::ParticipatoryProcessStep.where(participatory_process: processes).find_each { |s| checks << ["step #{s.id}", [s.title, s.description]] }
      components.each { |c| checks << ["component #{c.id}", [c.name]] }
      proposals.find_each { |p| checks << ["proposal #{p.id}", translatable_values(p, :title, :body, :answer)] }
      Decidim::Proposals::ProposalState.where(component: components).find_each { |s| checks << ["state #{s.id}", [s.title, s.announcement_title]] }
      Decidim::Comments::Comment.where(decidim_participatory_space_id: processes.ids).find_each { |c| checks << ["comment #{c.id}", [c.body]] }
      Decidim::Meetings::Meeting.where(component: components).find_each { |m| checks << ["meeting #{m.id}", translatable_values(m, :title, :description, :location, :location_hints)] }
      budgets = Decidim::Budgets::Budget.where(component: components)
      budgets.each { |b| checks << ["budget #{b.id}", [b.title, b.description]] }
      Decidim::Budgets::Project.where(budget: budgets).find_each { |p| checks << ["project #{p.id}", [p.title, p.description]] }
      Decidim::Forms::Question.find_each { |q| checks << ["question #{q.id}", [q.body]] }
      Decidim::Forms::ResponseOption.find_each { |o| checks << ["option #{o.id}", [o.body]] }
      # An existing terms-of-service page (here: the factory's) is never edited, so only the seed's own page is checked.
      about = Decidim::StaticPage.find_by(organization:, slug: "about-this-demo")
      checks << ["page about-this-demo", [about.title, about.content]]

      checks.each { |context, values| values.each { |value| expect_trilingual(value, context) } }
      expect(organization.available_locales).to eq(%w(en af xh))
      expect(organization.time_zone).to eq("Africa/Johannesburg")
      expect(organization.enable_omnipresent_banner).to be(true)
      expect(organization.omnipresent_banner_title["en"]).to start_with("Demonstration only — not an official City of Cape Town platform")
      expect(Decidim::StaticPage.where(organization:).pluck(:slug)).to include("terms-of-service", "about-this-demo")
    end

    it "is idempotent" do
      before_rerun = snapshot
      seed!
      expect(snapshot).to eq(before_rerun)
    end
  end

  it "updates an item in place when its summary changes in the JSON" do
    seed!
    item = sources["items"].find { |i| i["url"].end_with?("/resident-ideas") }
    sources_copy = temp_copy(described_class.default_sources_path, :json) do |data|
      data["items"].find { |i| i["url"] == item["url"] }["summary"] = "Updated summary for the spec."
    end
    before_rerun = snapshot

    seed!(sources: sources_copy)

    process = processes.find_by(slug: "resident-ideas")
    expect(process.description["en"]).to include("Updated summary for the spec.")
    expect(process.description["af"]).to include("Updated summary for the spec.") # stale translation replaced by English
    expect(snapshot).to eq(before_rerun)
    expect(log.string).to include("summary changed in the JSON")
  end

  it "leaves an existing real admin and their password untouched" do
    admin = create(:user, :admin, :confirmed, organization:, email: "admin@cct.example", name: "Real Admin", password: "decidim123456789!")
    digest = admin.encrypted_password

    seed!

    admin.reload
    expect(admin.encrypted_password).to eq(digest)
    expect(admin.name).to eq("Real Admin")
    expect(admin).to be_admin
    expect(admin.extended_data).not_to have_key("cct_seed")
    expect(Decidim::User.where(organization:, admin: true)).to eq([admin])
  end

  it "does not touch another organization" do
    other = create(:organization, host: "other.lvh.me", available_locales: %w(en), default_locale: "en")
    seed!

    expect(Decidim::Taxonomy.where(organization: other)).to be_empty
    expect(Decidim::ParticipatoryProcess.where(organization: other)).to be_empty
    expect(Decidim::User.where(organization: other)).to be_empty
    expect { described_class.run(logger:) }.to raise_error(Cct::Seed::Error, /CCT_SEED_HOST/)
  end

  it "creates a missing terms-of-service page in all three languages" do
    Decidim::StaticPage.where(organization:, slug: "terms-of-service").delete_all
    seed!

    page = Decidim::StaticPage.find_by(organization:, slug: "terms-of-service")
    expect_trilingual(page.title, "terms-of-service title")
    expect_trilingual(page.content, "terms-of-service content")
  end

  it "enables the ward workflow and limits the first showcase ward's budget vote to its residents (plan U4)" do
    seed!

    expect(organization.reload.available_authorizations).to include("cct_ward_resident")
    expect(log.string).to include("ward restriction: voting in the ward 23 budget limited to ward 23 residents")
    expect(log.string).to include("groups: skipped", "group restriction: skipped") # plan U5 not installed yet

    budget = Decidim::Budgets::Budget.where(component: components).find_by("title ->> 'en' LIKE 'Ward 23 %'")
    status_for = lambda do |ward|
      user = create(:user, :confirmed, organization:, extended_data: { "ward" => ward })
      Cct::WardResidency.sync!(user)
      Decidim::ActionAuthorizer.new(user, "vote", budget.component, budget).authorize
    end
    expect(status_for.call(23)).to be_ok
    expect(status_for.call(12).global_code).to eq(:unauthorized)

    other_ward = Decidim::Budgets::Budget.where(component: budget.component).where.not(id: budget.id).first
    user = create(:user, :confirmed, organization:, extended_data: { "ward" => 12 })
    Cct::WardResidency.sync!(user)
    expect(Decidim::ActionAuthorizer.new(user, "vote", budget.component, other_ward).authorize).to be_ok

    seed!
    expect(organization.reload.available_authorizations.count("cct_ward_resident")).to eq(1)
  end

  it "runs without the U4/U5 workflows and logs the skipped restriction steps" do
    installed = Decidim::Verifications.workflows.dup
    Decidim::Verifications.reset_workflows(*installed.reject { |workflow| workflow.name == "cct_ward_resident" })
    seed!

    expect(organization.reload.available_authorizations).not_to include("cct_ward_resident")
    expect(log.string).to include("groups: skipped")
    expect(log.string).to include("ward restriction: skipped")
    expect(log.string).to include("group restriction: skipped")
  ensure
    Decidim::Verifications.reset_workflows(*installed)
  end

  describe "reset_demo_content" do
    it "removes only the fictional layer" do
      seed!
      real_user = create(:user, :confirmed, organization:)
      component = processes.find_by(slug: "resident-ideas").components.find_by(manifest_name: "proposals")
      manual = create(:proposal, component:, users: [real_user], title: { "en" => "A real resident's idea" })
      real_comment = create(:comment, commentable: manual, author: real_user)
      counts = snapshot

      described_class.reset_demo_content(host: organization.host, logger:)

      expect(fictional_users).to be_empty
      expect(Decidim::Proposals::Proposal.exists?(manual.id)).to be(true)
      expect(Decidim::Comments::Comment.exists?(real_comment.id)).to be(true)
      expect(real_user.reload).to be_persisted
      expect(proposals.where(participatory_text_level: nil)).to eq([manual])
      expect(proposals.where.not(participatory_text_level: nil).count).to be > 0 # official by-law summaries stay
      expect(processes.count).to eq(counts[:processes])
      expect(Decidim::Taxonomy.where(organization:).count).to eq(counts[:taxonomies])
      expect(Decidim::Meetings::Meeting.where(component: components).count).to eq(counts[:meetings])
      expect(Decidim::Budgets::Project.where("title ->> 'en' LIKE 'Demo idea:%'")).to be_empty
      expect(Decidim::Budgets::Project.where("title ->> 'en' = 'Cox Park - upgrade'")).to exist

      seed!
      expect(fictional_users.count).to eq(30)
    end
  end

  describe "rendering", type: :request do
    let(:hostile_content) do
      temp_copy(described_class.default_content_path, :yaml) do |data|
        proposal = data["items"]["resident-ideas"]["proposals"].first
        proposal["title"] = { "en" => "Lights <script>alert(1)</script> & bins", "af" => "Ligte <b>&</b>", "xh" => "Izibane <i>&</i>" }
        proposal["comments"] = [{ "author" => "u09", "body" => { "en" => "Agree <img src=x onerror=alert(1)> & more", "af" => "Ja <b>", "xh" => "Ewe <b>" } }]
      end
    end

    before { host! organization.host }

    it "shows the source link on every item process page" do
      seed!
      sources.fetch("items").each do |item|
        process = item_processes.find { |p| p.title["en"] == item["title"] }
        get "/en/processes/#{process.slug}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(ERB::Util.html_escape(item["url"]))
      end
    end

    it "escapes seeded text containing < and &" do
      seed!(content: hostile_content)
      proposal = proposals.find_by("title ->> 'en' LIKE 'Lights%'")

      get Decidim::ResourceLocatorPresenter.new(proposal).path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lights &lt;script&gt;alert(1)&lt;/script&gt; &amp; bins")
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).not_to include("<img src=x onerror=alert(1)>")
    end
  end
end
