# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Sends a Decidim notification (in-app, plus email per each member's settings) about a
      # participatory space to every member of a group, and to nobody else (tender D4, plan KTD7).
      #
      # Idempotent per form token: the Alert row (unique token per organization) is written first,
      # in the same transaction as the event, so a resubmitted or double-clicked form broadcasts
      # :already_sent instead of notifying the members twice.
      class AlertGroup < Decidim::Command
        EVENT = "decidim.events.cct.group_alert"

        def initialize(form)
          @form = form
        end

        def call
          return broadcast(:invalid) if form.invalid?
          return broadcast(:already_sent, existing_alert) if existing_alert

          alert = nil
          transaction do
            alert = Alert.create!(
              organization: form.current_organization, group:, author: form.current_user,
              participatory_space: space, message: form.message.presence, token: form.token,
              recipients_count: recipients.size
            )
            Log.action!(:alert, group, form.current_user,
                        alert: { id: alert.id, recipients: recipients.size, space_title: space.title })
          end
          publish(alert)
          broadcast(:ok, alert)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          # A concurrent submission of the same form won the race.
          existing = existing_alert(reload: true)
          existing ? broadcast(:already_sent, existing) : broadcast(:invalid)
        end

        private

        attr_reader :form

        def group = form.group

        def space = form.participatory_space

        # Current members of the group who still have an account in this organization.
        def recipients
          @recipients ||= group.users.where(organization: form.current_organization, deleted_at: nil).to_a
        end

        def existing_alert(reload: false)
          @existing_alert = nil if reload
          @existing_alert ||= Alert.find_by(organization: form.current_organization, token: form.token)
        end

        def publish(alert)
          return if recipients.empty?

          Decidim::EventsManager.publish(
            event: EVENT,
            event_class: Cct::Groups::GroupAlertEvent,
            resource: space,
            affected_users: recipients,
            extra: { group_id: group.id, group_name: group.name, message: alert.message.to_s, alert_id: alert.id }
          )
        end
      end
    end
  end
end
