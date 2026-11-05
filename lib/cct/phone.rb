# frozen_string_literal: true

module Cct
  # South African mobile numbers. Accepts the usual ways people type them ("082 123 4567",
  # "+27 82 123 4567", "0027821234567", "27821234567") and normalises to E.164 (+27821234567).
  module Phone
    # National significant numbers of SA mobile ranges: 06x, 071-079, 081-084.
    MOBILE = /\A(?:6\d|7[1-9]|8[1-4])\d{7}\z/
    SEPARATORS = /[\s\-().]/

    module_function

    # "+27XXXXXXXXX", or nil when the value is not a South African mobile number.
    def normalize(value)
      digits = value.to_s.strip.gsub(SEPARATORS, "")
      national = case digits
                 when /\A\+27(\d{9})\z/, /\A0027(\d{9})\z/, /\A27(\d{9})\z/, /\A0(\d{9})\z/ then Regexp.last_match(1)
                 end
      national&.match?(MOBILE) ? "+27#{national}" : nil
    end

    def valid?(value) = normalize(value).present?
  end
end
