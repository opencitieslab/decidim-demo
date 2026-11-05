# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Admin log entries (Decidim.traceability, admin-only) for actions on a group that are not a
      # plain create/update/delete. Rendered by Cct::Groups::AdminLog::GroupPresenter.
      module Log
        module_function

        # A membership change. Keeps the member's public name and nickname only (no email).
        def member_action!(action, group, admin, member, extra = {})
          Decidim.traceability.perform_action!(
            action, group, admin,
            { visibility: "admin-only", member: { name: member.name, nickname: member.nickname } }.merge(extra)
          )
        end

        def action!(action, group, admin, extra = {})
          Decidim.traceability.perform_action!(action, group, admin, { visibility: "admin-only" }.merge(extra))
        end
      end
    end
  end
end
