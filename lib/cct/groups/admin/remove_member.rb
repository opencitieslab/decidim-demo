# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Removes a participant from a group and updates or removes their `cct_group_membership`
      # authorization (logged in the admin log).
      class RemoveMember < Decidim::Command
        def initialize(membership, current_user)
          @membership = membership
          @current_user = current_user
        end

        def call
          transaction do
            Cct::Groups.remove_member!(membership.group, membership.user)
            Log.member_action!(:remove_member, membership.group, current_user, membership.user)
          end
          broadcast(:ok, membership.user)
        end

        private

        attr_reader :membership, :current_user
      end
    end
  end
end
