# frozen_string_literal: true

module Cct
  module WardResident
    # Entry point of the `cct_ward_resident` verification workflow. Decidim mounts it (signed-in
    # users only) at /:locale/cct_ward_resident. It has no form of its own: the ward comes from the
    # participant's account, so the "authorize" link of a restricted action leads to the account
    # page, where the ward is set. This is what keeps the workflow non-self-service.
    class Engine < ::Rails::Engine
      isolate_namespace Cct::WardResident

      paths["lib/tasks"] = nil

      routes do
        root to: "account_redirects#show"
      end
    end
  end
end
