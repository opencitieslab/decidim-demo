# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Demo groups (plan U5) and the ward/group restriction examples (plan U4/U5). Both depend on
      # features that may not be installed yet; when they are missing the step is skipped with a
      # log line so the rest of the seed still runs.
      class Restrictions < Base
        WARD_WORKFLOW = "cct_ward_resident"
        GROUP_WORKFLOW = "cct_group_membership"
        RESTRICTED_BYLAW = "short-term-letting-bylaw"

        def call
          groups!
          ward_restriction!
          group_restriction!
        end

        private

        def workflow?(name) = Decidim::Verifications.workflows.any? { |workflow| workflow.name == name }

        def groups!
          if defined?(::CctGroups::Group)
            log "groups: the CctGroups engine is present, but group seeding is wired up with U5; " \
                "#{data.groups.size} demo groups are described in demo_content.yml"
          else
            log "groups: skipped (user groups engine, plan U5, not installed); #{data.groups.size} demo groups are described in demo_content.yml"
          end
        end

        # The first showcase ward's budget can only be voted on by residents of that ward.
        def ward_restriction!
          return log("ward restriction: skipped (#{WARD_WORKFLOW} authorization, plan U4, not installed)") unless workflow?(WARD_WORKFLOW)

          ward = Array(data.content.dig("budgets", "showcase_wards")).first.to_i
          process = Decidim::ParticipatoryProcess.find_by(organization:, slug: WardAllocations::SLUG)
          component = process&.components&.find_by(manifest_name: "budgets")
          budget = component && find_by_english(Decidim::Budgets::Budget.where(component:), "title",
                                                fmt(t(:budgets, :budget_title), number: ward, subcouncil: data.ward(ward)["subcouncil"])["en"])
          return warn("ward restriction: ward #{ward} budget not found") unless budget

          permission = budget.resource_permission || budget.build_resource_permission
          permission.permissions = { "vote" => authorization(WARD_WORKFLOW, "allowed_wards" => ward.to_s) }
          permission.save!
          log "ward restriction: voting in the ward #{ward} budget limited to ward #{ward} residents"
        end

        # Proposals in one by-law consultation are limited to the demo ward committee.
        def group_restriction!
          return log("group restriction: skipped (#{GROUP_WORKFLOW} authorization, plan U5, not installed)") unless workflow?(GROUP_WORKFLOW)

          process = Decidim::ParticipatoryProcess.find_by(organization:, slug: RESTRICTED_BYLAW)
          component = process && find_by_english(process.components.where(manifest_name: "proposals"), "name", t(:components, :proposals)["en"])
          return warn("group restriction: #{RESTRICTED_BYLAW} proposals component not found") unless component

          group = data.groups.first.fetch("key")
          component.update!(permissions: (component.permissions || {}).merge(
            "create" => authorization(GROUP_WORKFLOW, "allowed_groups" => group),
            "vote" => authorization(GROUP_WORKFLOW, "allowed_groups" => group)
          ))
          log "group restriction: #{RESTRICTED_BYLAW} proposals limited to the #{group} group"
        end

        def authorization(workflow, options)
          { "authorization_handlers" => { workflow => { "options" => options } } }
        end
      end
    end
  end
end
