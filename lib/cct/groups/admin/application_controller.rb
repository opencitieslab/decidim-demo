# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Base controller of the groups admin (Admin > Participants > Groups). Decidim's admin base
      # controller brings authentication, CSRF protection (protect_from_forgery with: :exception),
      # the admin terms check and the admin layout; this one adds the permission chain and scopes
      # every lookup to the current organization.
      class ApplicationController < Decidim::Admin::ApplicationController
        layout "decidim/admin/users"

        add_breadcrumb_item_from_menu :admin_user_menu

        helper_method :groups, :group_name

        protected

        def permission_class_chain
          [Cct::Groups::Admin::Permissions, ::Decidim::Admin::Permissions]
        end

        private

        def groups = Cct::Groups.for(current_organization)

        # Raises ActiveRecord::RecordNotFound (404) for an id of another organization.
        def group
          @group ||= groups.find(params[:group_id] || params[:id])
        end

        def group_name(group) = Cct::Groups.name_for(group)
      end
    end
  end
end
