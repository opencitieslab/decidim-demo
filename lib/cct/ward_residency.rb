# frozen_string_literal: true

module Cct
  # The participant's self-declared ward (users.extended_data["ward"]) and the
  # `cct_ward_resident` authorization derived from it (plan U4, KTD5).
  #
  # The authorization is never created from user input directly: it mirrors the ward in the
  # user's own account, so a participant can only be a "resident" of the ward they declared.
  # One authorization per user (Decidim::Authorization is unique per user and name); its
  # metadata is { "ward" => N }.
  module WardResidency
    WORKFLOW = "cct_ward_resident"

    # Keys this app keeps in users.extended_data (all personal data: wiped on account deletion,
    # included in download-your-data).
    PERSONAL_KEYS = %w(surname phone_e164 ward).freeze

    module_function

    def ward_for(user) = Wards.parse(user&.extended_data.to_h["ward"])

    def authorization_for(user)
      Decidim::Authorization.find_by(user:, name: WORKFLOW)
    end

    # Creates, updates or removes the user's ward authorization so it matches the ward stored in
    # their account. Idempotent.
    def sync!(user)
      ward = ward_for(user)
      return revoke!(user) unless ward && Wards.valid?(ward) && !user.deleted?

      authorization = Decidim::Authorization.find_or_initialize_by(user:, name: WORKFLOW)
      return authorization if authorization.granted? && authorization.metadata.to_h["ward"] == ward

      authorization.metadata = { "ward" => ward }
      authorization.unique_id = nil
      authorization.grant!
      authorization
    end

    def revoke!(user)
      Decidim::Authorization.where(user:, name: WORKFLOW).destroy_all
      nil
    end
  end
end
