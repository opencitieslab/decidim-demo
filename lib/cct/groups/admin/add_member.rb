# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Adds a participant of the current organization to a group and grants or updates their
      # `cct_group_membership` authorization (logged in the admin log).
      class AddMember < Decidim::Command
        def initialize(form, group)
          @form = form
          @group = group
        end

        def call
          return broadcast(:invalid) if form.invalid?

          user = form.user
          return broadcast(:already_member, user) if Membership.exists?(group:, user:)

          transaction do
            Cct::Groups.add_member!(group, user)
            Log.member_action!(:add_member, group, form.current_user, user)
          end
          broadcast(:ok, user)
        end

        private

        attr_reader :form, :group
      end
    end
  end
end
