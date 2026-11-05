# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Deletes a group with its memberships and resyncs the former members' authorizations, so a
      # deleted group stops granting access at once (logged in the admin log).
      class DestroyGroup < Decidim::Command
        def initialize(group, current_user)
          @group = group
          @current_user = current_user
        end

        def call
          transaction do
            Cct::Groups.destroy_group!(group) do
              Decidim.traceability.perform_action!(:delete, group, current_user, visibility: "admin-only") { group.destroy! }
            end
          end
          broadcast(:ok)
        end

        private

        attr_reader :group, :current_user
      end
    end
  end
end
