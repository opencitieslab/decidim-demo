# frozen_string_literal: true

module Cct
  module Authorizations
    # Action authorizer of the `cct_ward_resident` workflow. Admins restrict a component or
    # resource action (vote, create, comment...) to residents of some wards with the option
    # `allowed_wards` (a comma list, e.g. "23, 57"). Same pattern as the generator's
    # DummyActionAuthorizer with `allowed_postal_codes` (Decidim 0.32.2).
    #
    # - no authorization (no ward in the account): :missing, with a link to the account page;
    # - ward not in the list: :unauthorized, explaining which wards may take part;
    # - otherwise the default checks apply (granted, not expired).
    class WardActionAuthorizer < Decidim::Verifications::DefaultActionAuthorizer
      SCOPE = "cct.ward_resident.authorizer"

      def authorize
        # Remove the option before the default checks, so it is not treated as a metadata field.
        @allowed_wards = parse_wards(options.delete("allowed_wards"))

        status_code, data = *super

        if status_code == :missing
          data = data.merge(action: :set_ward, extra_explanation: [explanation(:missing)])
        elsif allowed_wards.any? && status_code == :ok && allowed_wards.exclude?(user_ward)
          status_code = :unauthorized
          data = { action: :update_ward, extra_explanation: [explanation(:unauthorized)] }
        end

        [status_code, data]
      end

      def redirect_params = {}

      attr_reader :allowed_wards

      private

      def user_ward = Wards.parse(authorization&.metadata.to_h&.fetch("ward", nil))

      def parse_wards(value)
        value = value.value if value.respond_to?(:value)
        value.to_s.split(/[\s,;]+/).filter_map { |part| Wards.parse(part) }.uniq.sort
      end

      def explanation(kind)
        key = allowed_wards.any? ? kind : :"#{kind}_any_ward"
        { key:, params: { scope: SCOPE, count: allowed_wards.size, wards: allowed_wards.join(", "), user_ward: user_ward.to_s } }
      end
    end
  end
end
