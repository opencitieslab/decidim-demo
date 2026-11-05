# frozen_string_literal: true

module Cct
  module Groups
    # An alert sent to a group's members about a participatory space (tender D4). The token comes
    # from the alert form and is unique per organization, so a resubmitted form never sends twice.
    class Alert < Decidim::ApplicationRecord
      self.table_name = "cct_group_alerts"

      MESSAGE_MAX_LENGTH = 500

      belongs_to :organization, class_name: "Decidim::Organization", foreign_key: :decidim_organization_id, inverse_of: false
      belongs_to :group, class_name: "Cct::Groups::Group", foreign_key: :cct_group_id, inverse_of: :alerts, optional: true
      belongs_to :author, class_name: "Decidim::User", foreign_key: :decidim_author_id, inverse_of: false, optional: true
      belongs_to :participatory_space, polymorphic: true

      validates :token, presence: true, uniqueness: { scope: :decidim_organization_id }
      validates :message, length: { maximum: MESSAGE_MAX_LENGTH }
    end
  end
end
