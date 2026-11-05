# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # One survey (questionnaire + questions) in a surveys component. Questions are rebuilt from
      # the YAML while the survey has no responses; once people have responded they are left alone.
      # Pattern: decidim-surveys/lib/decidim/surveys/seeds.rb (v0.32.2).
      class Survey < Base
        TYPES = %w(single_option multiple_option short_response long_response).freeze

        def initialize(ctx, component:, content:, open:, name: "")
          super(ctx)
          @component = component
          @content = content
          @open = open
          @name = name
        end

        def call
          survey = Decidim::Surveys::Survey.find_or_initialize_by(component: @component)
          created = survey.new_record?
          questionnaire = survey.questionnaire || Decidim::Forms::Questionnaire.new
          demo_note = t(:labels, :survey_demo_note)
          description = data.complete(@content.fetch("description"), "#{@name}.survey.description")
          questionnaire.assign_attributes(
            title: data.complete(@content.fetch("title"), "#{@name}.survey.title"),
            description: description.to_h { |locale, text| [locale, Html.paragraph(text) + "<p><em>#{Html.escape(demo_note[locale])}</em></p>"] },
            tos: html(t(:labels, :survey_tos))
          )
          survey.questionnaire = questionnaire
          survey.allow_responses = @open
          survey.allow_unregistered = false
          survey.published_at ||= Time.current
          survey.save!
          questionnaire.save!

          if questionnaire.responses.exists?
            log "#{@name}: survey has responses, questions left unchanged"
          else
            rebuild_questions!(questionnaire)
          end
          count(:surveys) if created
        end

        private

        def rebuild_questions!(questionnaire)
          questionnaire.questions.destroy_all
          Array(@content["questions"]).each_with_index do |spec, position|
            type = spec.fetch("type")
            raise Error, "#{@name}: unknown survey question type #{type}" unless TYPES.include?(type)

            label = "#{@name}.survey.questions.#{position}"
            question = Decidim::Forms::Question.create!(
              questionnaire:,
              position:,
              question_type: type,
              mandatory: spec["mandatory"] == true,
              body: data.complete(spec.fetch("body"), "#{label}.body"),
              max_choices: type == "multiple_option" ? spec["max_choices"] : nil
            )
            next unless type.end_with?("_option")

            Array(spec["options"]).each_with_index do |option, index|
              question.response_options.create!(body: data.complete(option, "#{label}.options.#{index}"))
            end
          end
        end
      end
    end
  end
end
