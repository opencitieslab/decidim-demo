# frozen_string_literal: true

module Cct
  module Groups
    # Notification (in-app and email) sent to the members of a group when an admin alerts them about
    # a participatory space (Cct::Groups::Admin::AlertGroup). Strings: decidim.events.cct.group_alert
    # in config/locales/cct.*.yml.
    #
    # Decidim marks the event strings html_safe, so every interpolated value is escaped here: the
    # group name and the admin's message are plain text.
    class GroupAlertEvent < Decidim::Events::SimpleEvent
      i18n_attributes :group_name

      def group_name
        ERB::Util.html_escape(Cct::Groups.translate(extra[:group_name])).to_str
      end

      # The admin's message, shown as a quote in the email and under the notification.
      def resource_text
        message = extra[:message].to_s
        return if message.blank?

        ERB::Util.html_escape(message).to_str
      end
    end
  end
end
