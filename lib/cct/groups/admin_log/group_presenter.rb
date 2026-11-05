# frozen_string_literal: true

module Cct
  module Groups
    module AdminLog
      # Presents the admin log entries of a Cct::Groups::Group (Admin > Admin activity log):
      # create, update, delete, add_member, remove_member, import_members and alert.
      # Strings: cct.groups.admin_log.* in config/locales/cct.*.yml.
      #
      # Every interpolated value is escaped (BasePresenter#present_explanation escapes strings that
      # are not html_safe; the group name comes from Decidim's escaping ResourcePresenter).
      class GroupPresenter < Decidim::Log::BasePresenter
        ACTIONS = %w(create update delete add_member remove_member import_members alert).freeze

        private

        def action_string
          ACTIONS.include?(action.to_s) ? "cct.groups.admin_log.#{action}" : super
        end

        def i18n_params
          super.merge(
            member_name: action_log.extra.dig("member", "name").to_s,
            added_count: action_log.extra.dig("import", "added").to_i.to_s,
            rejected_count: action_log.extra.dig("import", "rejected").to_i.to_s,
            recipients_count: action_log.extra.dig("alert", "recipients").to_i.to_s,
            space_title: Cct::Groups.translate(action_log.extra.dig("alert", "space_title"))
          )
        end

        def resource_presenter
          @resource_presenter ||= GroupResourcePresenter.new(action_log.resource, h, action_log.extra["resource"])
        end

        def diff_fields_mapping
          { name: :i18n, description: :i18n }
        end

        def i18n_labels_scope
          "activemodel.attributes.cct_group"
        end
      end
    end
  end
end
