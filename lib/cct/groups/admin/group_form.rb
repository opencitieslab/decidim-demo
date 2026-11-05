# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Creates or edits a group. The slug is only set on creation (it is the key used in the
      # `allowed_groups` permission option, so it never changes).
      class GroupForm < Decidim::Form
        include Decidim::TranslatableAttributes

        DESCRIPTION_MAX_LENGTH = 1000

        mimic :cct_group

        attribute :slug, String
        translatable_attribute :name, String
        translatable_attribute :description, String

        validates :name, translatable_presence: true
        validates :slug, presence: true, length: { maximum: Group::SLUG_MAX_LENGTH },
                         format: { with: Group::SLUG_FORMAT }, unless: :persisted?
        validate :slug_unique, unless: :persisted?
        validate :lengths

        def slug = super.to_s.strip.downcase

        def organization = current_organization

        private

        def slug_unique
          return if slug.blank?

          errors.add(:slug, :taken) if Cct::Groups.for(current_organization).exists?(slug:)
        end

        def lengths
          name.to_h.each_value { |value| errors.add(:name, :too_long, count: 100) if value.to_s.length > 100 }
          description.to_h.each_value do |value|
            errors.add(:description, :too_long, count: DESCRIPTION_MAX_LENGTH) if value.to_s.length > DESCRIPTION_MAX_LENGTH
          end
        end
      end
    end
  end
end
