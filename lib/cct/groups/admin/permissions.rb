# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Admin permissions of the participant groups. Only organization admins (`user.admin?`, admin
      # terms accepted) of the current organization may manage groups, their members and alerts;
      # space admins, user managers and participants may not. Any group, membership or alert given
      # in the context must belong to the current organization (controllers also scope every
      # lookup to it).
      #
      # Subjects and actions:
      #   :cct_group        :index, :create, :update, :destroy
      #   :cct_group_member :index, :create, :destroy, :import
      #   :cct_group_alert  :index, :create
      class Permissions < Decidim::DefaultPermissions
        SUBJECTS = {
          cct_group: [:index, :create, :update, :destroy],
          cct_group_member: [:index, :create, :destroy, :import],
          cct_group_alert: [:index, :create]
        }.freeze

        def permissions
          return permission_action unless permission_action.scope == :admin
          return permission_action unless SUBJECTS.has_key?(permission_action.subject)

          toggle_allow(
            SUBJECTS.fetch(permission_action.subject).include?(permission_action.action) &&
              organization_admin? &&
              in_organization?(context[:group]) &&
              in_organization?(context[:membership]&.group) &&
              in_organization?(context[:alert])
          )

          permission_action
        end

        private

        def organization
          context[:current_organization]
        end

        def organization_admin?
          user.present? && organization.present? && user.admin? && user.admin_terms_accepted? &&
            !user.deleted? && !user.blocked? && user.decidim_organization_id == organization.id
        end

        def in_organization?(record)
          record.nil? || record.decidim_organization_id == organization.id
        end
      end
    end
  end
end
