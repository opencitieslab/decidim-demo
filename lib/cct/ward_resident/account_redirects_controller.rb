# frozen_string_literal: true

module Cct
  module WardResident
    # Sends the participant to their account page to set or change their ward. Mounted inside
    # Decidim's `authenticate(:user)` block, and checked against the same permission as the
    # account page itself.
    class AccountRedirectsController < Decidim::ApplicationController
      def show
        enforce_permission_to(:update, :user, current_user:)

        flash[:notice] = t("cct.ward_resident.set_ward_notice")
        redirect_to decidim.account_path(anchor: "user_ward")
      end
    end
  end
end
