# frozen_string_literal: true

module Cct
  module Groups
    module AdminLog
      # Links a logged group to its members page in the admin (when it still exists).
      class GroupResourcePresenter < Decidim::Log::ResourcePresenter
        private

        def resource_path
          return if resource.blank?

          @resource_path ||= h.cct_groups_admin.group_members_path(resource)
        end
      end
    end
  end
end
