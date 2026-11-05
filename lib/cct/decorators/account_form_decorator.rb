# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::AccountForm (0.32.2) + the resident fields, filled from the user's extended_data.
    # The ward may be left empty here so existing accounts (admins, users created before this
    # field existed) can still be updated; ward-restricted actions then ask them to set it.
    module AccountFormDecorator
      def self.prepended(base)
        base.prepend(ResidentFields)
        base.prepend(Overrides)
      end

      module Overrides
        def ward_required? = false

        def map_model(model)
          super
          data = model.extended_data.to_h
          self.surname = data["surname"]
          self.ward = data["ward"]&.to_s
          self.phone = data["phone_e164"]
        end
      end
    end
  end
end
