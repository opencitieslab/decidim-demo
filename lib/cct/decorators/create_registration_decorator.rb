# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::CreateRegistration (0.32.2): stores the resident fields with the new user and grants
    # the `cct_ward_resident` authorization for the chosen ward, in the same transaction.
    module CreateRegistrationDecorator
      private

      def create_user
        ActiveRecord::Base.transaction do
          super
          ResidentFields.assign(@user, form)
          @user.save!
          Cct::WardResidency.sync!(@user)
        end
      end
    end
  end
end
