# frozen_string_literal: true

module Cct
  module Groups
    # Admin interface of the participant groups (Admin > Participants > Groups), mounted at
    # /admin/participant_groups by config/initializers/cct.rb. Same shape as Decidim's own admin
    # engines (e.g. Decidim::Templates::AdminEngine, 0.32.2): the routes only match for admins of the
    # current organization (Decidim::Admin::OrganizationDashboardConstraint: anonymous visitors are
    # sent to sign in, other users get a 404), and every action also checks
    # Cct::Groups::Admin::Permissions.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Cct::Groups::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      MOUNT_PATH = "/admin/participant_groups"

      routes do
        constraints(->(request) { Decidim::Admin::OrganizationDashboardConstraint.new(request).matches? }) do
          resources :groups, except: [:show] do
            resources :members, only: [:index, :create, :destroy]
            resource :members_import, only: [:create]
          end
          resources :alerts, only: [:index, :new, :create]
          root to: "groups#index"
        end
      end
    end
  end
end
