# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Lists, creates, edits and deletes the organization's groups.
      class GroupsController < ApplicationController
        helper_method :member_counts

        def index
          enforce_permission_to :index, :cct_group
          @groups = groups.order(:slug)
        end

        def new
          enforce_permission_to :create, :cct_group
          @form = form(GroupForm).instance
        end

        def create
          enforce_permission_to :create, :cct_group
          @form = form(GroupForm).from_params(params)

          CreateGroup.call(@form) do
            on(:ok) do |group|
              flash[:notice] = t("cct.groups.admin.groups.create.success")
              redirect_to group_members_path(group)
            end
            on(:invalid) do
              flash.now[:alert] = t("cct.groups.admin.groups.create.error")
              render :new, status: :unprocessable_content
            end
          end
        end

        def edit
          enforce_permission_to(:update, :cct_group, group:)
          @form = form(GroupForm).from_model(group)
        end

        def update
          enforce_permission_to(:update, :cct_group, group:)
          @form = form(GroupForm).from_params(params, id: group.id, slug: group.slug)

          UpdateGroup.call(@form, group) do
            on(:ok) do
              flash[:notice] = t("cct.groups.admin.groups.update.success")
              redirect_to groups_path
            end
            on(:invalid) do
              flash.now[:alert] = t("cct.groups.admin.groups.update.error")
              render :edit, status: :unprocessable_content
            end
          end
        end

        def destroy
          enforce_permission_to(:destroy, :cct_group, group:)

          DestroyGroup.call(group, current_user) do
            on(:ok) do
              flash[:notice] = t("cct.groups.admin.groups.destroy.success")
              redirect_to groups_path
            end
          end
        end

        private

        def member_counts
          @member_counts ||= Membership.where(cct_group_id: @groups.map(&:id)).group(:cct_group_id).count
        end
      end
    end
  end
end
