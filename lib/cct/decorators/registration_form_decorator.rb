# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::RegistrationForm (0.32.2) + surname (optional), ward (required) and mobile number
    # (optional). See ResidentFields.
    module RegistrationFormDecorator
      def self.prepended(base)
        base.prepend(ResidentFields)
      end
    end
  end
end
