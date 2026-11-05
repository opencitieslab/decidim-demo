# frozen_string_literal: true

module Cct
  module Authorizations
    # Action authorizer of the `cct_group_membership` workflow (plan U5, KTD4). Admins restrict a
    # component or resource action (create, vote, comment, answer...) to members of some groups
    # with the option `allowed_groups`: a comma list of group slugs, e.g.
    # "ward-23-ward-committee, cape-flats-ngo-forum". Same pattern as the generator's
    # DummyActionAuthorizer with `allowed_postal_codes` (Decidim 0.32.2).
    #
    # The authorization is admin-granted only (Cct::Groups.sync!), so a participant can never fix
    # a refusal themselves:
    # - member of an allowed group (or of any group when the list is empty): the default checks;
    # - otherwise (no group, or only other groups): :unauthorized, explaining which groups may take
    #   part and to ask an administrator, with no "authorize" button.
    # Anonymous visitors are asked to sign in first by Decidim's UI.
    class GroupActionAuthorizer < Decidim::Verifications::DefaultActionAuthorizer
      SCOPE = "cct.groups.authorizer"

      def authorize
        # Remove the option before the default checks, so it is not treated as a metadata field.
        @allowed_slugs = parse_slugs(options.delete("allowed_groups"))

        status_code, data = *super
        return [status_code, data] unless status_code.in?([:ok, :missing])

        if status_code == :missing || (allowed_slugs.any? && allowed_slugs.intersection(user_slugs).empty?)
          [:unauthorized, { extra_explanation: [explanation] }]
        else
          [status_code, data]
        end
      end

      def redirect_params = {}

      attr_reader :allowed_slugs

      private

      def user_slugs = Array(authorization&.metadata.to_h&.fetch("groups", nil)).map(&:to_s)

      def parse_slugs(value)
        value = value.value if value.respond_to?(:value)
        value.to_s.downcase.split(/[\s,;]+/).compact_blank.uniq.sort
      end

      # Names of the allowed groups in the component's organization, in the current locale
      # (unknown slugs are shown as they are), HTML-escaped: Decidim's authorization modal
      # (Decidim::AuthorizationModalCell, 0.32.2) renders extra explanations without escaping.
      def group_names
        organization = component&.organization
        groups = organization ? Cct::Groups.for(organization).where(slug: allowed_slugs).index_by(&:slug) : {}
        allowed_slugs.map do |slug|
          group = groups[slug]
          ERB::Util.html_escape(group ? Cct::Groups.name_for(group) : slug).to_str
        end
      end

      def explanation
        if allowed_slugs.any?
          { key: "restricted", params: { scope: SCOPE, count: allowed_slugs.size, groups: group_names.join(", ") } }
        else
          { key: "restricted_any_group", params: { scope: SCOPE } }
        end
      end
    end
  end
end
