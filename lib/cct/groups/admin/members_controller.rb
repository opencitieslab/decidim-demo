# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Lists a group's members, adds one by email and removes one.
      class MembersController < ApplicationController
        include Decidim::Paginable

        helper_method :group, :members

        def index
          enforce_permission_to(:index, :cct_group_member, group:)
          @form = form(MemberForm).instance
        end

        def create
          enforce_permission_to(:create, :cct_group_member, group:)
          @form = form(MemberForm).from_params(params)

          AddMember.call(@form, group) do
            on(:ok) do
              flash[:notice] = t("cct.groups.admin.members.create.success")
              redirect_to group_members_path(group)
            end
            on(:already_member) do
              flash[:notice] = t("cct.groups.admin.members.create.already_member")
              redirect_to group_members_path(group)
            end
            on(:invalid) do
              flash.now[:alert] = t("cct.groups.admin.members.create.error")
              render :index, status: :unprocessable_content
            end
          end
        end

        def destroy
          membership = group.memberships.find(params[:id])
          enforce_permission_to(:destroy, :cct_group_member, group:, membership:)

          RemoveMember.call(membership, current_user) do
            on(:ok) do
              flash[:notice] = t("cct.groups.admin.members.destroy.success")
              redirect_to group_members_path(group)
            end
          end
        end

        private

        def members
          @members ||= paginate(group.memberships.includes(:user).joins(:user).order("decidim_users.name", :id))
        end
      end
    end
  end
end
