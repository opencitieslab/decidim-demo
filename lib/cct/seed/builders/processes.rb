# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # The "Have your say 2025-26" process group and one participatory process per real item:
      # official title, our summary, a visible source link, phases from the real dates, theme /
      # directorate / area taxonomies, and components by item kind.
      # Pattern: decidim-participatory_processes/lib/decidim/participatory_processes/seeds.rb (v0.32.2).
      class Processes < Base
        IDP_INPUTS = [Date.new(2026, 11, 1), Date.new(2027, 3, 31)].freeze
        IDP_DRAFT = [Date.new(2027, 4, 1), Date.new(2027, 4, 30)].freeze
        IDP_MEETING_SUBCOUNCILS = [1, 3, 5, 8, 9, 11, 13, 16, 18, 20].freeze
        BUDGET_SESSION_DATES = {
          "budget" => [Date.new(2027, 2, 10), Date.new(2027, 2, 24)],
          "idp" => [Date.new(2027, 3, 10)]
        }.freeze

        PROPOSAL_STEP_SETTINGS = {
          "public_comment" => { creation_enabled: true, votes_enabled: true },
          "review" => { creation_enabled: false, votes_enabled: true, votes_blocked: true },
          "ongoing" => { creation_enabled: true, votes_enabled: true },
          "idp_inputs" => { creation_enabled: true, votes_enabled: true },
          "idp_draft" => { creation_enabled: false, votes_enabled: true, votes_blocked: true }
        }.freeze

        def call
          group = upsert_group!
          data.items.each_with_index { |item, index| build_item(item, group, index) }
          log "item processes: #{data.items.size}"
        end

        # Shared with the ward allocations builder.
        def sync_steps!(process, specs)
          process.steps.update_all(active: false) # rubocop:disable Rails/SkipsModelValidations
          steps = specs.each_with_index.map do |(key, from, to), position|
            step = process.steps.find_by(position:) || process.steps.build(position:)
            step.assign_attributes(title: t(:steps, key, :title), description: html(t(:steps, key, :description)),
                                   start_date: from, end_date: to, active: false)
            step.save!
            [key, step]
          end
          process.steps.where.not(id: steps.map { |_, step| step.id }).destroy_all

          current_step(steps.map(&:last)).update!(active: true)
          steps.to_h
        end

        # The step covering today; before the first step, the first; after the last, the latest started.
        def current_step(steps)
          today = ctx.today
          steps.find { |step| step.start_date <= today && (step.end_date.nil? || today <= step.end_date) } ||
            (today < steps.first.start_date ? steps.first : steps.reverse.find { |step| step.start_date <= today })
        end

        def upsert_process!(slug:, attributes:)
          process = Decidim::ParticipatoryProcess.find_or_initialize_by(organization:, slug:)
          created = process.new_record?
          process.assign_attributes(attributes)
          process.published_at ||= Time.current
          process.save!
          Decidim::ContentBlocksCreator.new(process).create_default!
          count(:processes) if created
          process
        end

        def component_filters
          ctx.store.dig(:taxonomies, :filters).values_at(:area, :theme).compact.map(&:id)
        end

        private

        def upsert_group!
          group = find_by_english(Decidim::ParticipatoryProcessGroup.where(organization:), "title", t(:labels, :process_group_title)["en"])
          group ||= Decidim::ParticipatoryProcessGroup.new(organization:)
          group.title = t(:labels, :process_group_title)
          group.description = html(t(:labels, :process_group_description))
          group.developer_group = t(:labels, :org_name)
          group.promoted = true
          group.save!
          Decidim::ContentBlocksCreator.new(group).create_default!
          group
        end

        def build_item(item, group, index)
          directorate = ctx.taxonomy(:directorate, item.directorate_key)
          directorate_name = t(:directorates, item.directorate_key)
          theme = ctx.taxonomy(:theme, item.theme_key)
          specs = steps_for(item)

          process = upsert_process!(
            slug: item.slug,
            attributes: {
              title: data.item_text(item, "title"),
              subtitle: directorate_name,
              short_description: html(period_text(item)),
              description: description(item, directorate_name),
              announcement: html(t(:labels, :process_announcement)),
              developer_group: directorate_name,
              start_date: specs.first[1],
              end_date: specs.filter_map { |spec| spec[2] }.max || item.close_date,
              participatory_process_group: group,
              promoted: item.open? || item.kind == "idp_new",
              weight: index
            }
          )
          set_taxonomies(process, [theme, directorate, *area_taxonomies(item)])
          steps = sync_steps!(process, specs)

          build_components(item, process, steps, theme)
        end

        def build_components(item, process, steps, theme)
          window = submission_window(item)
          published = ctx.time_on([window.first, ctx.today].min, 9)
          weight = 0

          if item.bylaw?
            text = upsert_component(
              space: process, manifest_name: :proposals, name: t(:components, :bylaw_text), weight: weight += 10,
              settings: proposal_settings(participatory_text: true),
              step_settings: steps.to_h { |_key, step| [step.id.to_s, { creation_enabled: false, votes_enabled: false }] }
            )
            ParticipatoryText.new(ctx, component: text, content: item.bylaw_text, published:, taxonomies: [theme],
                                       name: item.slug).call
          end

          if item.kind == "survey" && item.survey
            survey_component!(item, process, weight += 10)
            item_survey_done = true
          end

          proposals = upsert_component(
            space: process, manifest_name: :proposals, name: t(:components, :proposals), weight: weight += 10,
            settings: proposal_settings,
            step_settings: steps.to_h { |key, step| [step.id.to_s, PROPOSAL_STEP_SETTINGS.fetch(key)] }
          )
          Proposals.new(ctx, component: proposals, entries: item.proposals, window:, taxonomies: [theme], name: item.slug).call

          survey_component!(item, process, weight += 10) if item.survey && !item_survey_done
          meetings!(item, process, theme, weight + 10) if %w(budget idp idp_new).include?(item.kind)
        end

        def survey_component!(item, process, weight)
          component = upsert_component(space: process, manifest_name: :surveys, name: t(:components, :survey), weight:,
                                       settings: { announcement: html(t(:labels, :survey_demo_note)) })
          Survey.new(ctx, component:, content: item.survey, open: survey_open?(item),
                          name: item.slug).call
        end

        def survey_open?(item)
          return true if item.kind == "idp_new" || item.close_date.nil?

          item.close_date >= ctx.today
        end

        def meetings!(item, process, theme, weight)
          idp = item.kind == "idp_new"
          component = upsert_component(
            space: process, manifest_name: :meetings, name: t(:components, idp ? :idp_meetings : :meetings), weight:,
            settings: { taxonomy_filters: component_filters, comments_enabled: true, comments_max_length: 1000 }
          )
          builder = Meetings.new(ctx)
          if idp
            dates = Meetings.spread_dates(IDP_MEETING_SUBCOUNCILS.size, from: Date.new(2026, 11, 17), to: Date.new(2027, 3, 25))
            IDP_MEETING_SUBCOUNCILS.zip(dates).each do |number, date|
              builder.subcouncil_meeting!(component:, number:, date:, kind: :idp, taxonomies: [theme], registrations: true)
            end
          else
            dates = BUDGET_SESSION_DATES.fetch(item.kind)
            date = dates[data.items.select { |other| other.kind == item.kind }.index(item) % dates.size]
            builder.civic_centre_meeting!(component:, date:, taxonomies: [theme])
          end
        end

        def proposal_settings(participatory_text: false)
          {
            taxonomy_filters: component_filters,
            participatory_texts_enabled: participatory_text,
            amendments_enabled: false,
            comments_enabled: true,
            comments_max_length: 1000,
            proposal_length: 1000,
            vote_limit: 0,
            minimum_votes_per_user: 0,
            proposal_limit: 0,
            threshold_per_proposal: 0,
            official_proposals_enabled: true,
            announcement: html(t(:labels, participatory_text ? :bylaw_text_intro : :proposals_announcement))
          }
        end

        def steps_for(item)
          open = item.open_date
          close = item.close_date
          return [["ongoing", open, nil]] if item.kind == "ideas" || close.nil?
          return [["public_comment", open, close], ["idp_inputs", *IDP_INPUTS], ["idp_draft", *IDP_DRAFT]] if item.kind == "idp_new"

          [["public_comment", open, close], ["review", close + 1, nil]]
        end

        # When the fictional submissions were "made".
        def submission_window(item)
          return IDP_INPUTS if item.kind == "idp_new"

          [item.open_date, item.close_date || ctx.today]
        end

        def period_text(item)
          start = localized_date(item.open_date)
          return fmt(t(:labels, :open_since), start:) unless item.close_date

          fmt(t(:labels, :comment_period), start:, end: localized_date(item.close_date))
        end

        def description(item, directorate_name)
          summary = data.item_text(item, "summary")
          related = Array(item.source["other_urls"]).select { |url| Html.safe_url(url) }
          uncertain = item.department.include?("uncertain")
          labels = [:source, :related_coverage, :directorate, :directorate_uncertain, :item_demo_note].index_with { |key| t(:labels, key) }

          LOCALES.to_h do |locale|
            parts = [Html.paragraph(summary[locale])]
            parts << "<p><strong>#{Html.escape(labels[:source][locale])}:</strong> #{Html.link(item.url)}</p>"
            parts << "<p>#{Html.escape(labels[:related_coverage][locale])}: #{related.map { |url| Html.link(url) }.join(", ")}</p>" if related.any?
            directorate = "#{labels[:directorate][locale]}: #{directorate_name[locale]}"
            directorate += " #{labels[:directorate_uncertain][locale]}" if uncertain
            parts << Html.paragraph(directorate)
            parts << "<p><em>#{Html.escape(labels[:item_demo_note][locale])}</em></p>"
            [locale, parts.join]
          end
        end

        # Area taxonomies from a YAML override ("ward:12", "subcouncil:3") or parsed from the
        # item's area text ("Ward 12, Subcouncil 5 (Belhar)", "Subcouncils 1 and 3 (...)").
        def area_taxonomies(item)
          specs = item.content["areas"] || begin
            if (ward = item.area[/\bWard (\d+)/, 1])
              ["ward:#{ward}"]
            elsif (numbers = item.area[/\bSubcouncils? ((?:\d+(?:,\s*|\s+and\s+)?)+)/, 1])
              numbers.scan(/\d+/).map { |number| "subcouncil:#{number}" }
            else
              []
            end
          end
          specs.filter_map do |spec|
            kind, number = spec.split(":")
            taxonomy = ctx.taxonomy(kind.to_sym, number.to_i)
            warn("#{item.slug}: unknown area #{spec}") unless taxonomy
            taxonomy
          end
        end
      end
    end
  end
end
