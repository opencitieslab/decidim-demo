# frozen_string_literal: true

require "securerandom"

module Cct
  module Seed
    module Builders
      # ~30 fictional participants on @example.org addresses, visibly named "· demo".
      # Their password is random and never stored, so nobody can sign in as them. An existing
      # account with the same email that is NOT seed-marked (e.g. a real user) is never touched.
      class Users < Base
        DOMAIN = "example.org"

        def call
          ctx.store[:users] = {}
          data.users.each do |key, attributes|
            user = save_user(key, attributes)
            ctx.store[:users][key] = user if user
          end
          log "fictional users: #{ctx.users.size}"
        end

        def self.email_for(attributes) = "#{attributes.fetch("nickname").tr("_", ".")}@#{DOMAIN}"

        private

        def save_user(key, attributes)
          email = self.class.email_for(attributes)
          user = Decidim::User.find_by(organization:, email:)
          if user && !user.extended_data.to_h.has_key?(MARKER)
            warn "#{email} exists and is not a seeded account; leaving it alone and skipping its content"
            return
          end

          created = user.nil?
          user ||= Decidim::User.new(organization:, email:, password: SecureRandom.base58(40),
                                     nickname: unique_nickname(attributes.fetch("nickname")))
          user.name = attributes.fetch("name")
          user.locale = attributes.fetch("locale", "en")
          user.extended_data = user.extended_data.to_h.merge(
            MARKER => { "key" => key, "ward" => attributes["ward"].to_i, "fictional" => true }
          )
          if created
            user.tos_agreement = true
            user.accepted_tos_version = organization.tos_version || Time.current
            user.password_updated_at = Time.current
            user.skip_confirmation!
          end
          user.save!
          count(:users) if created
          user
        end

        def unique_nickname(base)
          nickname = base[0, 20]
          suffix = 1
          while Decidim::User.where(organization:).exists?(nickname:)
            nickname = "#{base[0, 17]}_#{suffix}"
            suffix += 1
          end
          nickname
        end
      end
    end
  end
end
