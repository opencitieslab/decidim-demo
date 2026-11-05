# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # The fictional proposals of one proposals component, with supports, comments and official
      # answers using the custom states (Received -> Assigned to directorate -> Under evaluation ->
      # Responded). Pattern: decidim-proposals/lib/decidim/proposals/seeds.rb (v0.32.2), but every
      # record is upserted by the English title and authored by a seed-marked fictional user.
      class Proposals < Base
        STATES = %w(received assigned_to_directorate under_evaluation responded).freeze
        AUTHOR_TYPE = "Decidim::UserBaseEntity"

        # The custom proposal states of a component (component configuration, not fictional data).
        def self.ensure_states!(ctx, component)
          colors = Decidim::Proposals.proposal_states_colors
          STATES.to_h do |token|
            config = ctx.data.content.dig("proposal_states", token)
            state = Decidim::Proposals::ProposalState.find_or_initialize_by(component:, token:)
            color = colors.fetch(config.fetch("color").to_sym)
            state.assign_attributes(
              title: ctx.data.t(:proposal_states, token, :title),
              announcement_title: ctx.data.t(:proposal_states, token, :announcement_title),
              bg_color: color[:background],
              text_color: color[:foreground]
            )
            state.save! if state.changed?
            [token, state]
          end
        end

        # Proposals authored by seed-marked users (what reset deletes).
        def self.fictional_scope(organization)
          ids = Seed.fictional_users(organization).pluck(:id)
          Decidim::Proposals::Proposal.joins(:coauthorships)
                                      .where(decidim_coauthorships: { decidim_author_type: AUTHOR_TYPE, decidim_author_id: ids })
                                      .distinct
        end

        # rubocop:disable Metrics/ParameterLists
        def initialize(ctx, component:, entries:, window:, taxonomies: [], name: "")
          super(ctx)
          @component = component
          @entries = Array(entries)
          @window = window
          @taxonomies = taxonomies
          @name = name
        end
        # rubocop:enable Metrics/ParameterLists

        def call
          @states = self.class.ensure_states!(ctx, @component)
          @entries.each_with_index { |entry, index| save_proposal(entry, index) }
        end

        private

        def save_proposal(entry, index)
          label = "#{@name}.proposals.#{index}"
          author = ctx.users[entry["author"]]
          return warn("#{label}: author #{entry["author"]} unavailable, skipped") unless author

          title = data.complete(entry["title"], "#{label}.title")
          proposal = find_by_english(Decidim::Proposals::Proposal.where(component: @component), "title", title["en"])
          return warn("#{label}: a non-seeded proposal already has the title #{title["en"].inspect}, skipped") if proposal && !fictional?(proposal)

          created = proposal.nil?
          published = published_time(index)
          proposal ||= Decidim::Proposals::Proposal.new(component: @component)
          proposal.title = title
          proposal.body = data.complete(entry["body"], "#{label}.body")
          proposal.published_at = published
          apply_state(proposal, entry, published, label)
          proposal.add_coauthor(author) if created
          proposal.save!

          if created
            proposal.update_columns(created_at: published, updated_at: published) # rubocop:disable Rails/SkipsModelValidations
            Decidim::ActionLogger.log("publish", author, proposal, nil, visibility: "public-only")
            count(:proposals)
          end

          ward = entry["ward"] && ctx.taxonomy(:ward, entry["ward"].to_i)
          set_taxonomies(proposal, [ward, *@taxonomies])
          supports!(proposal, entry["supports"].to_i, author)
          Comments.new(ctx, commentable: proposal, entries: entry["comments"], after: published, name: label).call
        end

        def fictional?(proposal)
          ids = ctx.users.values.map(&:id)
          proposal.coauthorships.exists?(decidim_author_type: AUTHOR_TYPE, decidim_author_id: ids)
        end

        def apply_state(proposal, entry, published, label)
          token = entry["state"].presence
          unless token
            proposal.assign_attributes(proposal_state: nil, answer: nil, answered_at: nil, state_published_at: nil)
            return
          end
          raise Error, "#{label}: unknown state #{token}" unless STATES.include?(token)

          answered = [published + 3.days, Time.current].min
          answer = entry["answer"].presence && answer_html(data.complete(entry["answer"], "#{label}.answer"))
          proposal.assign_attributes(proposal_state: @states.fetch(token), answer:, answered_at: answered,
                                     state_published_at: answered)
        end

        def answer_html(answer)
          note = t(:labels, :demo_answer_note)
          answer.to_h { |locale, text| [locale, "#{Html.paragraph(text)}<p><em>#{Html.escape(note[locale])}</em></p>"] }
        end

        # Spreads proposals evenly over the submission window, never in the future.
        def published_time(index)
          from, to = @window
          to = [to, ctx.today].min
          from = [from, to].min
          day = from + (((to - from).to_i * (index + 1)) / (@entries.size + 1))
          [ctx.time_on(day, 8 + ((index * 3) % 11), (index * 17) % 60), Time.current - (@entries.size - index).minutes].min
        end

        # Supports come from a deterministic rotation of the other fictional users.
        def supports!(proposal, wanted, author)
          pool = ctx.users.values.reject { |user| user.id == author.id }
          offset = proposal.id % [pool.size, 1].max
          supporters = pool.rotate(offset).first([wanted, pool.size].min)
          existing = Decidim::Proposals::ProposalVote.where(proposal:, author: ctx.users.values)
          existing.where.not(decidim_author_id: supporters.map(&:id)).destroy_all
          (supporters.map(&:id) - existing.pluck(:decidim_author_id)).each do |id|
            Decidim::Proposals::ProposalVote.create!(proposal:, author: supporters.find { |user| user.id == id })
            count(:supports)
          end
        end
      end
    end
  end
end
