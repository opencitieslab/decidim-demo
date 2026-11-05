# frozen_string_literal: true

module Cct
  module GroupMember
    # Entry point of the `cct_group_membership` verification workflow. Decidim mounts it (signed-in
    # users only) at /:locale/cct_group_membership. Membership is granted by administrators only
    # (Admin > Participants > Groups), so there is no form: the page explains whom to ask. This is
    # what keeps the workflow non-self-service.
    class Engine < ::Rails::Engine
      isolate_namespace Cct::GroupMember

      paths["lib/tasks"] = nil

      routes do
        root to: "explanations#show"
      end
    end
  end
end
