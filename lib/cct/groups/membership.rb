# frozen_string_literal: true

module Cct
  module Groups
    # A user's membership of a group. Both must belong to the same organization.
    class Membership < Decidim::ApplicationRecord
      self.table_name = "cct_group_memberships"

      belongs_to :group, class_name: "Cct::Groups::Group", foreign_key: :cct_group_id, inverse_of: :memberships
      belongs_to :user, class_name: "Decidim::User", foreign_key: :decidim_user_id, inverse_of: false

      validates :decidim_user_id, uniqueness: { scope: :cct_group_id }
      validate :same_organization

      private

      def same_organization
        return if group.nil? || user.nil?

        errors.add(:user, :invalid) unless user.decidim_organization_id == group.decidim_organization_id
      end
    end
  end
end
