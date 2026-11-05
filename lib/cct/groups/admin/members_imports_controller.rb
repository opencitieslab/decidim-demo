# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Adds the participants listed in an uploaded CSV file to a group and shows a report of what
      # was added and rejected.
      class MembersImportsController < ApplicationController
        helper_method :group

        def create
          enforce_permission_to(:import, :cct_group_member, group:)

          ImportMembersCsv.call(params[:file], group, current_user) do
            # Command blocks run in the command's context: pass the result as a local.
            on(:ok) do |result|
              render :show, locals: { result: }
            end
            on(:invalid) do |reason|
              flash[:alert] = t("cct.groups.admin.members_imports.errors.#{reason}",
                                rows: ImportMembersCsv::MAX_ROWS, size: ImportMembersCsv::MAX_BYTES / 1.kilobyte)
              redirect_to group_members_path(group)
            end
          end
        end
      end
    end
  end
end
