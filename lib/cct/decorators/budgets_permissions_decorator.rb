# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::Budgets::Permissions (0.32.2): adding a project to a vote and checking out an order
    # (`:vote, :project`) only check the project's (or component's) permissions. With
    # budget-level permissions (BudgetDecorator) the budget's own "vote" authorization must hold
    # too, otherwise a participant could bypass a ward restriction by posting to the line items or
    # checkout endpoints directly.
    module BudgetsPermissionsDecorator
      private

      def can_vote_project?(a_project)
        target = budget || a_project&.budget
        if target && !authorized?(:vote, resource: target)
          disallow!
          return false
        end

        super
      end
    end
  end
end
