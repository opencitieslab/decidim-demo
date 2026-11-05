# frozen_string_literal: true

require "csv"

module Cct
  module Groups
    module Admin
      # Adds the participants listed in a CSV file (one email per row, first column; an optional
      # "email" header row is skipped) to a group.
      #
      # Safety:
      # - only users of the current organization are added; unknown emails and emails of other
      #   organizations are both reported as "not found in this organization";
      # - the file is capped (MAX_BYTES, MAX_ROWS) and parsed as data only;
      # - rejected values are kept as plain text (truncated), never interpreted: a formula such as
      #   =HYPERLINK(...) is just an invalid email, and the report escapes it when rendered.
      class ImportMembersCsv < Decidim::Command
        MAX_ROWS = 500
        MAX_BYTES = 256.kilobytes
        SHOWN_VALUE_LENGTH = 120

        Result = Struct.new(:added, :already_members, :rejected, :truncated, keyword_init: true) do
          def added_count = added.size
        end
        Rejection = Struct.new(:line, :value, :reason, keyword_init: true)

        def initialize(file, group, current_user)
          @file = file
          @group = group
          @current_user = current_user
        end

        def call
          return broadcast(:invalid, :missing_file) unless file.respond_to?(:read)
          return broadcast(:invalid, :too_large) if file.size.to_i > MAX_BYTES

          rows = parse
          return broadcast(:invalid, :malformed) unless rows

          result = import(rows)
          broadcast(:ok, result)
        end

        private

        attr_reader :file, :group, :current_user

        def parse
          content = file.read(MAX_BYTES + 1).to_s.dup.force_encoding(Encoding::UTF_8)
          return nil unless content.valid_encoding?

          content = content.delete_prefix("﻿")
          CSV.parse(content, skip_blanks: true).map { |row| row.first.to_s.strip }
        rescue CSV::MalformedCSVError
          nil
        end

        def import(values)
          values.shift if values.first.to_s.casecmp?("email")
          truncated = values.size > MAX_ROWS
          result = Result.new(added: [], already_members: [], rejected: [], truncated:)

          transaction do
            values.first(MAX_ROWS).each_with_index do |value, index|
              import_row(value, index + 1, result)
            end
            if result.added.any?
              Log.action!(:import_members, group, current_user,
                          import: { added: result.added.size, already_members: result.already_members.size,
                                    rejected: result.rejected.size })
            end
          end
          result
        end

        def import_row(value, line, result)
          return if value.blank?

          user = Cct::Groups.find_member_candidate(group.organization, value)
          if user.nil?
            reason = value.match?(Devise.email_regexp) ? :not_found : :invalid_email
            result.rejected << Rejection.new(line:, value: value.truncate(SHOWN_VALUE_LENGTH), reason:)
          elsif result.added.include?(user) || result.already_members.include?(user)
            nil
          elsif Cct::Groups.add_member!(group, user)
            result.added << user
          else
            result.already_members << user
          end
        end
      end
    end
  end
end
