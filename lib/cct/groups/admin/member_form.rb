# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Adds a participant to a group by email. Only users of the current organization can be found
      # (deleted and managed accounts excluded); an email of another organization is reported the
      # same way as an unknown one, so the form does not reveal accounts elsewhere.
      class MemberForm < Decidim::Form
        mimic :cct_group_member

        attribute :email, String

        validates :email, presence: true
        validate :user_exists

        def email = super.to_s.strip.downcase

        def user
          return if email.blank?

          @user ||= Cct::Groups.find_member_candidate(current_organization, email)
        end

        private

        def user_exists
          return if email.blank?

          errors.add(:email, :not_found_in_organization) unless user
        end
      end
    end
  end
end
