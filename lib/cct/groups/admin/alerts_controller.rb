# frozen_string_literal: true

require "securerandom"

module Cct
  module Groups
    module Admin
      # "Alert a group" (tender D4): sends a notification about a participatory space to the members
      # of one group, with a confirmation step and a one-time form token.
      class AlertsController < ApplicationController
        include Decidim::Paginable

        helper_method :alerts, :space_options

        def index
          enforce_permission_to :index, :cct_group_alert
        end

        def new
          enforce_permission_to :create, :cct_group_alert
          @form = form(AlertForm).instance
          @form.token = SecureRandom.uuid
          @form.group_id = groups.find_by(id: params[:group_id])&.id
        end

        def create
          enforce_permission_to :create, :cct_group_alert
          @form = form(AlertForm).from_params(params)

          AlertGroup.call(@form) do
            on(:ok) do |alert|
              flash[:notice] = t("cct.groups.admin.alerts.create.success", count: alert.recipients_count)
              redirect_to alerts_path
            end
            on(:already_sent) do
              flash[:notice] = t("cct.groups.admin.alerts.create.already_sent")
              redirect_to alerts_path
            end
            on(:invalid) do
              flash.now[:alert] = t("cct.groups.admin.alerts.create.error")
              render :new, status: :unprocessable_content
            end
          end
        end

        private

        def alerts
          @alerts ||= paginate(
            Alert.where(organization: current_organization).includes(:group, :author, :participatory_space).order(created_at: :desc)
          )
        end

        def space_options
          @space_options ||= AlertForm.space_options(current_organization)
        end
      end
    end
  end
end
