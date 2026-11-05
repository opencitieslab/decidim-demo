# frozen_string_literal: true

module Cct
  module Decorators
    # Surname, ward and mobile number fields shared by the registration and account forms
    # (plan U4, R5, KTD6). They are stored in users.extended_data as `surname`, `ward` and
    # `phone_e164` and are never shown publicly: the public display name stays `name`.
    #
    # Prepended into a Decidim form; `ward_required?` decides whether an empty ward is allowed.
    module ResidentFields
      SURNAME_MAX_LENGTH = 100

      def self.prepended(base)
        base.class_eval do
          attribute :surname, String
          attribute :ward, String
          attribute :phone, String

          validates :surname, length: { maximum: SURNAME_MAX_LENGTH }, format: { with: Decidim::User::REGEXP_NAME }, allow_blank: true
          validates :ward, presence: true, if: :ward_required?
          validate :ward_is_a_cape_town_ward
          validate :phone_is_a_south_african_mobile
        end
      end

      def surname = super.to_s.strip.presence

      def ward_number = Cct::Wards.parse(ward)

      # "+27XXXXXXXXX" or nil
      def phone_e164 = Cct::Phone.normalize(phone)

      # The extended_data values for these fields (nil = remove the key).
      def resident_extended_data
        { "surname" => surname, "ward" => ward_number, "phone_e164" => phone_e164 }
      end

      def ward_required? = true

      # Writes a form's resident fields into a user's extended_data (not saved).
      def self.assign(user, form)
        user.extended_data = user.extended_data.to_h.merge(form.resident_extended_data).compact
      end

      private

      def ward_is_a_cape_town_ward
        return if ward.blank?

        errors.add(:ward, :inclusion) unless Cct::Wards.valid?(ward)
      end

      def phone_is_a_south_african_mobile
        return if phone.blank?

        errors.add(:phone, :invalid_sa_mobile) unless Cct::Phone.valid?(phone)
      end
    end
  end
end
