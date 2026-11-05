# frozen_string_literal: true

module Cct
  module Groups
    # A participant group of one organization (e.g. a ward committee, an NGO forum). `slug` is the
    # stable key admins use in the `allowed_groups` permission option, so it is unique per
    # organization and cannot change after creation. `name` and `description` are translatable
    # (en/af/xh) plain text.
    class Group < Decidim::ApplicationRecord
      include Decidim::Traceable
      include Decidim::Loggable

      self.table_name = "cct_groups"

      SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
      SLUG_MAX_LENGTH = 60

      belongs_to :organization, class_name: "Decidim::Organization", foreign_key: :decidim_organization_id, inverse_of: false
      has_many :memberships, class_name: "Cct::Groups::Membership", foreign_key: :cct_group_id,
                             inverse_of: :group, dependent: :delete_all
      has_many :users, through: :memberships
      has_many :alerts, class_name: "Cct::Groups::Alert", foreign_key: :cct_group_id, inverse_of: :group, dependent: :nullify

      validates :slug, presence: true, length: { maximum: SLUG_MAX_LENGTH }, format: { with: SLUG_FORMAT },
                       uniqueness: { scope: :decidim_organization_id }
      validate :slug_unchanged, on: :update

      scope :seeded, -> { where(seeded: true) }

      def self.log_presenter_class_for(_log) = Cct::Groups::AdminLog::GroupPresenter

      def title = name

      private

      def slug_unchanged
        errors.add(:slug, :immutable) if slug_changed?
      end
    end
  end
end
