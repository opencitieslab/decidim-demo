# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::Budgets::Budget (0.32.2) does not allow resource-level permissions, so a vote can
    # only be restricted for a whole budgets component. Ward allocations keep one budget per ward
    # in one component, so each budget needs its own "vote" permission (e.g. `allowed_wards: 23`).
    # The vote button already authorizes against the budget (project_vote_button cell, `resource:
    # model.budget`); BudgetsPermissionsDecorator enforces the same check server-side.
    module BudgetDecorator
      def allow_resource_permissions? = true
    end
  end
end
