# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # "Alert a group" (tender D4): pick one of the organization's groups and one of its published
      # participatory spaces, optionally add a short plain-text message. The form carries a random
      # token issued when it is displayed; AlertGroup sends at most once per token.
      class AlertForm < Decidim::Form
        TOKEN_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
        SPACE_FORMAT = /\A(?<manifest>[a-z_]+):(?<id>\d+)\z/

        mimic :cct_group_alert

        attribute :group_id, Integer
        attribute :space, String
        attribute :message, String
        attribute :token, String

        validates :group, presence: true
        validates :participatory_space, presence: true
        validates :message, length: { maximum: Alert::MESSAGE_MAX_LENGTH }
        validates :token, format: { with: TOKEN_FORMAT }

        def message = super.to_s.strip

        def group
          return if group_id.blank?

          @group ||= Cct::Groups.for(current_organization).find_by(id: group_id)
        end

        # The selected space, only among the organization's published spaces.
        def participatory_space
          match = SPACE_FORMAT.match(space.to_s)
          return unless match

          @participatory_space ||= self.class.published_spaces(current_organization, match[:manifest])&.find_by(id: match[:id])
        end

        def self.space_value(space) = "#{space.class.participatory_space_manifest.name}:#{space.id}"

        # Published spaces of the organization, by manifest (processes, assemblies...).
        def self.published_spaces(organization, manifest_name)
          manifest = Decidim.participatory_space_manifests.find { |candidate| candidate.name.to_s == manifest_name.to_s }
          return unless manifest

          spaces = manifest.participatory_spaces.call(organization)
          spaces.respond_to?(:published) ? spaces.published : spaces.none
        end

        # [[manifest, [spaces...]]] for the space select.
        def self.space_options(organization)
          Decidim.participatory_space_manifests.filter_map do |manifest|
            spaces = published_spaces(organization, manifest.name)
            next if spaces.blank?

            [manifest, spaces.order(:id).to_a]
          end
        end
      end
    end
  end
end
