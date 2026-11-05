# frozen_string_literal: true

module Cct
  module GroupMember
    # Tells a participant that group membership is managed by administrators, and sends them back
    # to their authorizations page. Mounted inside Decidim's `authenticate(:user)` block and
    # checked against the same permission as the account page itself.
    class ExplanationsController < Decidim::ApplicationController
      def show
        enforce_permission_to(:update, :user, current_user:)

        flash[:notice] = t("cct.groups.member.ask_admin")
        redirect_to decidim_verifications.authorizations_path
      end
    end
  end
end
