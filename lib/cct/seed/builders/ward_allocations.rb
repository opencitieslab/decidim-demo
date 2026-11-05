# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # "Ward Allocations 2026/27": one budget (R1,000,000) per showcase ward with the real sample
      # projects from Annexure 22 (amounts labelled indicative) plus fictional "Demo idea" projects,
      # and the 20 subcouncil ordinary meetings at the real subcouncil offices.
      # Pattern: decidim-budgets/lib/decidim/budgets/seeds.rb (v0.32.2).
      class WardAllocations < Base
        SLUG = "ward-allocations-2026-27"
        STEPS = [
          ["wa_ideas", Date.new(2026, 10, 1), Date.new(2026, 10, 31)],
          ["wa_vote", Date.new(2026, 11, 1), Date.new(2027, 1, 31)],
          ["wa_subcouncil", Date.new(2027, 2, 1), Date.new(2027, 3, 31)]
        ].freeze
        BUDGET_STEP_SETTINGS = {
          "wa_ideas" => { votes: "disabled" },
          "wa_vote" => { votes: "enabled" },
          "wa_subcouncil" => { votes: "finished", show_votes: true }
        }.freeze

        def call
          processes = Processes.new(ctx)
          allocation = data.budget.fetch("ward_allocations")
          values = { per_ward: localized_rand(allocation["per_ward_rand"]), total: localized_rand(allocation["total_rand"]),
                     wards: allocation["wards"] }

          process = processes.upsert_process!(
            slug: SLUG,
            attributes: {
              title: t(:budgets, :process_title),
              subtitle: t(:budgets, :process_subtitle),
              short_description: html(t(:budgets, :process_short_description)),
              description: description(fmt(t(:budgets, :process_description), **values), allocation["source"]),
              announcement: html(t(:labels, :process_announcement)),
              start_date: STEPS.first[1],
              end_date: STEPS.last[2],
              promoted: true,
              weight: 0
            }
          )
          theme = data.themes.find { |th| th["key"] == "capable_government" }
          process.taxonomies = [ctx.taxonomy(:theme, theme && theme["key"]), *showcase_wards.map { |n| ctx.taxonomy(:ward, n) }].compact.uniq
          steps = processes.sync_steps!(process, STEPS)

          component = upsert_component(
            space: process, manifest_name: :budgets, name: t(:components, :budgets), weight: 10,
            settings: {
              taxonomy_filters: processes.component_filters,
              workflow: "one",
              voting_rule: "minimum_projects",
              vote_minimum_budget_projects_number: 1,
              comments_enabled: true,
              comments_max_length: 1000,
              landing_page_content: html(t(:budgets, :landing_page)),
              announcement: html(t(:labels, :proposals_announcement))
            },
            step_settings: steps.to_h { |key, step| [step.id.to_s, BUDGET_STEP_SETTINGS.fetch(key)] }
          )
          showcase_wards.each_with_index { |number, index| budget!(component, number, index, allocation) }

          meetings!(process, processes)
          log "ward allocations: #{showcase_wards.size} ward budgets"
        end

        def showcase_wards = Array(data.content.dig("budgets", "showcase_wards")).map(&:to_i)

        # English titles of the fictional "Demo idea" projects (used by reset).
        def self.fictional_titles(content)
          content.dig("budgets", "fictional_projects").to_h.values.flatten.map { |project| project.dig("title", "en") }
        end

        private

        def description(text, source)
          LOCALES.index_with do |locale|
            "#{Html.paragraph(text[locale])}<p><strong>#{Html.escape(t(:labels, :source)[locale])}:</strong> #{Html.link(source)}</p>"
          end
        end

        def budget!(component, number, index, allocation)
          ward = data.ward(number) || raise(Error, "Showcase ward #{number} is not in the ward list")
          amount = allocation.fetch("per_ward_rand")
          title = fmt(t(:budgets, :budget_title), number:, subcouncil: ward["subcouncil"])
          budget = find_by_english(Decidim::Budgets::Budget.where(component:), "title", title["en"])
          created = budget.nil?
          budget ||= Decidim::Budgets::Budget.new(component:)
          budget.assign_attributes(title:, weight: index, total_budget: amount,
                                   description: html(fmt(t(:budgets, :budget_description), number:, amount: localized_rand(amount))))
          budget.save!
          count(:budgets) if created

          ward_taxonomy = ctx.taxonomy(:ward, number)
          real_projects(number).each { |project| real_project!(budget, project, ward_taxonomy) }
          Array(data.content.dig("budgets", "fictional_projects", number)).each_with_index do |project, position|
            fictional_project!(budget, project, ward_taxonomy, "budgets.fictional_projects.#{number}.#{position}")
          end
        end

        def real_projects(number)
          Array(data.budget["sample_ward_projects_2026_27"]).select { |project| project["ward"].to_i == number }
        end

        def real_project!(budget, project, ward_taxonomy)
          english = project.fetch("project")
          translated = data.content.dig("budgets", "real_project_titles", english).to_h
          title = data.complete(translated.merge("en" => english), "budgets.real_project_titles.#{english}")
          text = fmt(t(:budgets, :real_project_description), amount: localized_rand(project["rand"]))
          source = data.budget["sample_projects_source"]
          description = LOCALES.index_with do |locale|
            "#{Html.paragraph(text[locale])}<p><strong>#{Html.escape(t(:labels, :source)[locale])}:</strong> #{Html.link(source)}</p>"
          end
          upsert_project!(budget, title:, description:, amount: project.fetch("rand"), taxonomy: ward_taxonomy)
        end

        def fictional_project!(budget, project, ward_taxonomy, label)
          note = t(:budgets, :fictional_project_note)
          text = data.complete(project.fetch("description"), "#{label}.description")
          description = text.to_h { |locale, body| [locale, Html.paragraph(body) + "<p><em>#{Html.escape(note[locale])}</em></p>"] }
          upsert_project!(budget, title: data.complete(project.fetch("title"), "#{label}.title"), description:,
                                  amount: project.fetch("amount"), taxonomy: ward_taxonomy)
        end

        def upsert_project!(budget, title:, description:, amount:, taxonomy:)
          project = find_by_english(Decidim::Budgets::Project.where(budget:), "title", title["en"])
          created = project.nil?
          project ||= Decidim::Budgets::Project.new(budget:)
          project.assign_attributes(title:, description:, budget_amount: amount.to_i)
          project.save!
          set_taxonomies(project, [taxonomy])
          count(:projects) if created
          project
        end

        def meetings!(process, processes)
          component = upsert_component(
            space: process, manifest_name: :meetings, name: t(:components, :subcouncil_meetings), weight: 20,
            settings: { taxonomy_filters: processes.component_filters, comments_enabled: true, comments_max_length: 1000 }
          )
          numbers = data.subcouncils.map { |s| s["number"] }.sort
          dates = Meetings.spread_dates(numbers.size, from: Date.new(2026, 11, 16), to: Date.new(2027, 3, 26))
          builder = Meetings.new(ctx)
          numbers.zip(dates).each do |number, date|
            builder.subcouncil_meeting!(component:, number:, date:, kind: :subcouncil)
          end
        end
      end
    end
  end
end
