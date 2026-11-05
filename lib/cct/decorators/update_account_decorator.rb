# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::UpdateAccount (0.32.2): saves the resident fields with the rest of the account and,
    # once the account is saved, brings the `cct_ward_resident` authorization in line with the ward
    # (updated in place, never duplicated; removed when the ward is cleared).
    module UpdateAccountDecorator
      def call
        on(:ok) { Cct::WardResidency.sync!(current_user) }
        super
      end

      private

      def update_personal_data
        super
        ResidentFields.assign(current_user, form)
      end
    end
  end
end
