# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # A by-law shown as a Decidim participatory text: our plain-language summary split into
      # sections and articles (official, authored by the organization), with fictional resident
      # comments on the articles. Mirrors Decidim::Proposals::MarkdownToProposals (v0.32.2):
      # sections have title == body, articles are titled with their running number.
      class ParticipatoryText < Base
        # Same values as Decidim::Proposals::ParticipatoryTextSection::LEVELS.
        LEVELS = { section: "section", article: "article" }.freeze

        # rubocop:disable Metrics/ParameterLists
        def initialize(ctx, component:, content:, published:, taxonomies: [], name: "")
          super(ctx)
          @component = component
          @content = content
          @published = published
          @taxonomies = taxonomies
          @name = name
        end
        # rubocop:enable Metrics/ParameterLists

        def call
          document = Decidim::Proposals::ParticipatoryText.find_or_initialize_by(component: @component)
          document.title = t(:labels, :bylaw_text_title)
          document.description = html(t(:labels, :bylaw_text_intro))
          document.save!

          position = 0
          article_number = 0
          Array(@content["sections"]).each_with_index do |section, index|
            title = data.complete(section.fetch("title"), "#{@name}.bylaw_text.sections.#{index}.title")
            position += 1
            save_section(position, LEVELS[:section], title, title)

            Array(section["articles"]).each_with_index do |article, number|
              label = "#{@name}.bylaw_text.sections.#{index}.articles.#{number}"
              article_number += 1
              position += 1
              number_title = LOCALES.index_with { |_locale| article_number.to_s }
              proposal = save_section(position, LEVELS[:article], number_title, data.complete(article.fetch("body"), "#{label}.body"))
              Comments.new(ctx, commentable: proposal, entries: article["comments"], after: @published, name: label).call
            end
          end

          # Drop official sections left over from a previous, longer version of the summary.
          stale = Decidim::Proposals::Proposal.where(component: @component).where("position > ?", position)
                                              .where.not(participatory_text_level: nil)
          stale.each(&:destroy!)
        end

        private

        def save_section(position, level, title, body)
          proposal = Decidim::Proposals::Proposal.where(component: @component).find_by(position:)
          created = proposal.nil?
          proposal ||= Decidim::Proposals::Proposal.new(component: @component, position:)
          proposal.assign_attributes(title:, body:, participatory_text_level: level, published_at: @published)
          proposal.add_coauthor(organization) if created
          proposal.save!
          proposal.update_column(:position, position) if proposal.position != position # rubocop:disable Rails/SkipsModelValidations
          set_taxonomies(proposal, @taxonomies)
          count(:participatory_text_sections) if created
          proposal
        end
      end
    end
  end
end
