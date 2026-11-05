# frozen_string_literal: true

module Cct
  module Decorators
    # Decidim::DownloadYourDataSerializers::DownloadYourDataUserSerializer (0.32.2): the owner's
    # "download your data" export includes the surname, ward and mobile number we store.
    module DownloadYourDataUserSerializerDecorator
      def serialize
        data = resource.extended_data.to_h
        super.merge(surname: data["surname"], ward: data["ward"], phone_e164: data["phone_e164"])
      end
    end
  end
end
