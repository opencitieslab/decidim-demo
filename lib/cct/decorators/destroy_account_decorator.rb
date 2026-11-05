# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::DestroyAccount (0.32.2) does not clear users.extended_data. POPIA: when an account
    # is deleted, remove the surname, ward and mobile number and the ward authorization too
    # (inside DestroyAccount's own transaction).
    module DestroyAccountDecorator
      private

      def destroy_user_account!
        current_user.extended_data = current_user.extended_data.to_h.except(*Cct::WardResidency::PERSONAL_KEYS)
        Cct::WardResidency.revoke!(current_user)
        super
      end
    end
  end
end
